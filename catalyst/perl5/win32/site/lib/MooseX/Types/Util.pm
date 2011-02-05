package MooseX::Types::Util;
our $VERSION = "0.25";

=head1 NAME

MooseX::Types::Util - Common utility functions for the module

=cut

use warnings;
use strict;
use Scalar::Util 'blessed';

use base 'Exporter';

=head1 DESCRIPTION

This package the exportable functions that many parts in 
L<MooseX::Types> might need.

=cut

our @EXPORT_OK = qw( filter_tags has_available_type_export );

=head1 FUNCTIONS

=head2 filter_tags

Takes a list and returns two references. The first is a hash reference
containing the tags as keys and the number of their appearance as values.
The second is an array reference containing all other elements.

=cut

sub filter_tags {
    my (@list) = @_;
    my (%tags, @other);
    for (@list) {
        if (/^:(.*)$/) {
            $tags{ $1 }++;
            next;
        }
        push @other, $_;
    }
    return \%tags, \@other;
}

=head2 has_available_type_export

  TypeConstraint | Undef = has_available_type_export($package, $name);

This function allows you to introspect if a given type export is available 
I<at this point in time>. This means that the C<$package> must have imported
a typeconstraint with the name C<$name>, and it must be still in its symbol
table.

Two arguments are expected:

=over 4

=item $package

The name of the package to introspect.

=item $name

The name of the type export to introspect.

=back

B<Note> that the C<$name> is the I<exported> name of the type, not the declared
one. This means that if you use L<Sub::Exporter>s functionality to rename an import
like this:

  use MyTypes Str => { -as => 'MyStr' };

you would have to introspect this type like this:

  has_available_type_export $package, 'MyStr';

The return value will be either the type constraint that belongs to the export
or an undefined value.

=cut

sub has_available_type_export {
    my ($package, $name) = @_;

    my $sub = $package->can($name)
        or return undef;

    return undef
        unless blessed $sub && $sub->isa('MooseX::Types::EXPORTED_TYPE_CONSTRAINT');

    return $sub->();
}

=head1 SEE ALSO

L<MooseX::Types::Moose>, L<Exporter>

=head1 AUTHOR

See L<MooseX::Types/AUTHOR>.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the same terms as perl itself.

=cut

1;
