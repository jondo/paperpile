package Log::Any::Adapter::Core;
use strict;
use warnings;

# Forward 'warn' to 'warning', 'is_warn' to 'is_warning', and so on for all aliases
#
my %aliases = Log::Any->log_level_aliases;
while ( my ( $alias, $realname ) = each(%aliases) ) {
    _make_method( $alias, sub { my $self = shift; $self->$realname(@_) } );
    my $is_alias    = "is_$alias";
    my $is_realname = "is_$realname";
    _make_method( $is_alias,
        sub { my $self = shift; $self->$is_realname(@_) } );
}

# Add printf-style versions of all logging methods and aliases - e.g. errorf, debugf
#
foreach my $name ( Log::Any->logging_methods, keys(%aliases) ) {
    my $methodf = $name . "f";
    my $method = $aliases{$name} || $name;
    _make_method(
        $methodf,
        sub {
            my ( $self, $format, @params ) = @_;
            my @new_params =
              map {
                   !defined($_) ? '<undef>'
                  : ref($_)     ? _dump_one_line($_)
                  : $_
              } @params;
            my $new_message = sprintf( $format, @new_params );
            $self->$method($new_message);
        }
    );
}

sub _make_method {
    my ( $method, $code, $pkg ) = @_;

    $pkg ||= caller();
    no strict 'refs';
    *{ $pkg . "::$method" } = $code;
}

sub _dump_one_line {
    my ($value) = @_;

    return Data::Dumper->new( [$value] )->Indent(0)->Sortkeys(1)->Quotekeys(0)
      ->Terse(1)->Dump();
}

1;

__END__

=pod

=head1 NAME

Log::Any::Adapter::Core

=head1 DESCRIPTION

This is the base class for both real Log::Any adapters and
Log::Any::Adapter::Null.

=head1 AUTHOR

Jonathan Swartz

=head1 COPYRIGHT & LICENSE

Copyright (C) 2009 Jonathan Swartz, all rights reserved.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
