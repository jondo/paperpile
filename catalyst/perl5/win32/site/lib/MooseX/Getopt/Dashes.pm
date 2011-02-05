package MooseX::Getopt::Dashes;
BEGIN {
  $MooseX::Getopt::Dashes::AUTHORITY = 'cpan:STEVAN';
}
BEGIN {
  $MooseX::Getopt::Dashes::VERSION = '0.33';
}
# ABSTRACT: convert underscores in attribute names to dashes

use Moose::Role;

with 'MooseX::Getopt';

around _get_cmd_flags_for_attr => sub {
    my $next = shift;
    my ( $class, $attr, @rest ) = @_;

    my ( $flag, @aliases ) = $class->$next($attr, @rest);
    $flag =~ tr/_/-/
        unless $attr->does('MooseX::Getopt::Meta::Attribute::Trait')
            && $attr->has_cmd_flag;

    return ( $flag, @aliases );
};

no Moose::Role;

1;


__END__
=pod

=encoding utf-8

=head1 NAME

MooseX::Getopt::Dashes - convert underscores in attribute names to dashes

=head1 SYNOPSIS

  package My::App;
  use Moose;
  with 'MooseX::Getopt::Dashes';

  # Will be called as --some-thingy, not --some_thingy
  has 'some_thingy' => (
      is      => 'ro',
      isa     => 'Str',
      default => 'foo'
  );

  # Will be called as --another_thingy, not --another-thingy
  has 'another_thingy' => (
      traits   => [ 'Getopt' ],
      cmd_flag => 'another_thingy'
      is       => 'ro',
      isa      => 'Str',
      default  => 'foo'
  );

  # use as MooseX::Getopt

=head1 DESCRIPTION

This is a version of C<MooseX::Getopt> which converts underscores in
attribute names to dashes when generating command line flags.

You can selectively disable this on a per-attribute basis by supplying
a L<cmd_flag|MooseX::Getopt::Meta::Attribute/METHODS> argument with
the command flag you'd like for a given attribute. No underscore to
dash replacement will be done on the C<cmd_flag>.

=head1 AUTHORS

=over 4

=item *

Stevan Little <stevan@iinteractive.com>

=item *

Brandon L. Black <blblack@gmail.com>

=item *

Yuval Kogman <nothingmuch@woobling.org>

=item *

Ryan D Johnson <ryan@innerfence.com>

=item *

Drew Taylor <drew@drewtaylor.com>

=item *

Tomas Doran <bobtfish@bobtfish.net>

=item *

Florian Ragwitz <rafl@debian.org>

=item *

Dagfinn Ilmari Mannsåker <ilmari@ilmari.org>

=item *

Ævar Arnfjörð Bjarmason <avar@cpan.org>

=item *

Chris Prather <perigrin@cpan.org>

=item *

Karen Etheridge <ether@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Infinity Interactive, Inc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

