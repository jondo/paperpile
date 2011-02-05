package MooseX::Getopt::Strict;
BEGIN {
  $MooseX::Getopt::Strict::AUTHORITY = 'cpan:STEVAN';
}
BEGIN {
  $MooseX::Getopt::Strict::VERSION = '0.33';
}
# ABSTRACT: only make options for attrs with the Getopt metaclass

use Moose::Role;

with 'MooseX::Getopt';

around '_compute_getopt_attrs' => sub {
    my $next = shift;
    my ( $class, @args ) = @_;
    grep {
        $_->does("MooseX::Getopt::Meta::Attribute::Trait")
    } $class->$next(@args);
};

no Moose::Role;

1;


__END__
=pod

=encoding utf-8

=head1 NAME

MooseX::Getopt::Strict - only make options for attrs with the Getopt metaclass

=head1 DESCRIPTION

This is an stricter version of C<MooseX::Getopt> which only processes the
attributes if they explicitly set as C<Getopt> attributes. All other attributes
are ignored by the command line handler.

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

