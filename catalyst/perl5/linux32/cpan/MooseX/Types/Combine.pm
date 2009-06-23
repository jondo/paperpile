=head1 NAME

MooseX::Types::Combine - Combine type libraries for exporting

=cut

package MooseX::Types::Combine;

use strict;
use warnings;
use Class::MOP ();

=head1 SYNOPSIS

    package CombinedTypeLib;

    use base 'MooseX::Types::Combined';

    __PACKAGE__->provide_types_from(qw/TypeLib1 TypeLib2/);

    package UserClass;

    use CombinedTypeLib qw/Type1 Type2 ... /;

=head1 DESCRIPTION

Allows you to export types from multiple type libraries. 

Libraries on the right side of the type libs passed to L</provide_types_from>
take precedence over those on the left in case of conflicts.

=cut

sub import {
    my ($class, @types) = @_;
    my $caller = caller;

    my @type_libs = $class->provide_types_from;
    Class::MOP::load_class($_) for @type_libs;

    my %types = map {
        my $lib = $_;
        map +($_ => $lib), $lib->type_names
    } @type_libs;

    my %from;
    push @{ $from{ $types{ $_ } } }, $_ for @types;

    $_->import({ -into => $caller }, @{ $from{ $_ } })
        for keys %from;
}

=head1 CLASS METHODS

=head2 provide_types_from

Sets or returns a list of type libraries to re-export from.

=cut

sub provide_types_from {
    my ($class, @libs) = @_;

    my $store =
     do { no strict 'refs'; \@{ "${class}::__MOOSEX_TYPELIBRARY_LIBRARIES" } };

    @$store = @libs if @libs;

    @$store;
}

=head1 SEE ALSO

L<MooseX::Types>

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the same terms as perl itself.

=cut

1;
