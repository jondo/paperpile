use strict;
use warnings;
package String::RewritePrefix;
use Carp ();

=head1 NAME

String::RewritePrefix - rewrite strings based on a set of known prefixes

=head1 VERSION

version 0.004

=head1 SYNOPSIS

  use String::RewritePrefix;
  my @to_load = String::RewritePrefix->rewrite(
    { '' => 'MyApp::', '+' => '' },
    qw(Plugin Mixin Addon +Corporate::Thinger),
  );

  # now you have:
  qw(MyApp::Plugin MyApp::Mixin MyApp::Addon Corporate::Thinger)

=cut

our $VERSION = '0.004';

=head1 METHODS

=head2 rewrite

  String::RewritePrefix->rewrite(\%prefix, @strings);

This rewrites all the given strings using the rules in C<%prefix>.  Its keys
are known prefixes for which its values will be substituted.  This is performed
in longest-first order, and only one prefix will be rewritten.

If the prefix value is a coderef, it will be executed with the remaining string
as its only argument.  The return value will be used as the prefix.

=cut

sub rewrite {
  my ($self, $arg, @rest) = @_;
  return $self->new_rewriter($arg)->(@rest);
}

sub new_rewriter {
  my ($self, $rewrites) = @_;

  my @rewrites;
  for my $prefix (sort { length $b <=> length $a } keys %$rewrites) {
    push @rewrites, ($prefix, $rewrites->{$prefix});
  }

  return sub {
    my @result;

    Carp::cluck("string rewriter invoked in void context")
      unless defined wantarray;

    Carp::croak("attempt to rewrite multiple strings outside of list context")
      if @_ > 1 and ! wantarray;

    STRING: for my $str (@_) {
      for (my $i = 0; $i < @rewrites; $i += 2) {
        if (index($str, $rewrites[$i]) == 0) {
          if (ref $rewrites[$i+1]) {
            my $rest = substr $str, length($rewrites[$i]);
            push @result, $rewrites[$i+1]->($rest) . $rest;
          } else {
            push @result, $rewrites[$i+1] . substr $str, length($rewrites[$i]);
          }
          next STRING;
        }
      }

      push @result, $str;
    }
    
    return wantarray ? @result : $result[0];
  };
}

=head1 AUTHOR

Ricardo SIGNES <rjbs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2008 by Ricardo SIGNES.

This is free software; you can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
