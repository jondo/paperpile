package MooseX::Getopt::Meta::Attribute::NoGetopt;
BEGIN {
  $MooseX::Getopt::Meta::Attribute::NoGetopt::AUTHORITY = 'cpan:STEVAN';
}
BEGIN {
  $MooseX::Getopt::Meta::Attribute::NoGetopt::VERSION = '0.33';
}
# ABSTRACT: Optional meta attribute for ignoring params

use Moose;

extends 'Moose::Meta::Attribute'; # << Moose extending Moose :)
   with 'MooseX::Getopt::Meta::Attribute::Trait::NoGetopt';

no Moose;

# register this as a metaclass alias ...
package # stop confusing PAUSE
    Moose::Meta::Attribute::Custom::NoGetopt;
BEGIN {
  $Moose::Meta::Attribute::Custom::NoGetopt::AUTHORITY = 'cpan:STEVAN';
}
BEGIN {
  $Moose::Meta::Attribute::Custom::NoGetopt::VERSION = '0.33';
}
sub register_implementation { 'MooseX::Getopt::Meta::Attribute::NoGetopt' }

1;


__END__
=pod

=encoding utf-8

=head1 NAME

MooseX::Getopt::Meta::Attribute::NoGetopt - Optional meta attribute for ignoring params

=head1 SYNOPSIS

  package App;
  use Moose;

  with 'MooseX::Getopt';

  has 'data' => (
      metaclass => 'NoGetopt',  # do not attempt to capture this param
      is        => 'ro',
      isa       => 'Str',
      default   => 'file.dat',
  );

=head1 DESCRIPTION

This is a custom attribute metaclass which can be used to specify
that a specific attribute should B<not> be processed by
C<MooseX::Getopt>. All you need to do is specify the C<NoGetopt>
metaclass.

  has 'foo' => (metaclass => 'NoGetopt', ... );

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

