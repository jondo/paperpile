=head1 NAME

MooseX::Types::Wrapper - Wrap exports from a library

=cut

package MooseX::Types::Wrapper;
our $VERSION = "0.25";
use Moose;

use Carp::Clan      qw( ^MooseX::Types );
use Class::MOP;

use namespace::clean -except => [qw( meta )];

extends 'MooseX::Types';

=head1 DESCRIPTION

See L<MooseX::Types/SYNOPSIS> for detailed usage.

=head1 METHODS

=head2 import

=cut

sub import {
    my ($class, @args) = @_;
    my %libraries = @args == 1 ? (Moose => $args[0]) : @args;

    for my $l (keys %libraries) {

        croak qq($class expects an array reference as import spec)
            unless ref $libraries{ $l } eq 'ARRAY';

        my $library_class 
          = ($l eq 'Moose' ? 'MooseX::Types::Moose' : $l );
        Class::MOP::load_class($library_class);

        $library_class->import({ 
            -into    => scalar(caller),
            -wrapper => $class,
        }, @{ $libraries{ $l } });
    }
    return 1;
}

1;

=head1 SEE ALSO

L<MooseX::Types>

=head1 AUTHOR

See L<MooseX::Types/AUTHOR>.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the same terms as perl itself.

=cut
