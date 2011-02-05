package MooseX::Types::Base;
our $VERSION = "0.25";
use Moose;

=head1 NAME

MooseX::Types::Base - Type library base class

=cut

use Carp::Clan                      qw( ^MooseX::Types );
use MooseX::Types::Util             qw( filter_tags );
use Sub::Exporter                   qw( build_exporter );
use Moose::Util::TypeConstraints;

use namespace::clean -except => [qw( meta )];

=head1 DESCRIPTION

You normally won't need to interact with this class by yourself. It is
merely a collection of functionality that type libraries need to 
interact with moose and the rest of the L<MooseX::Types> module.

=cut

my $UndefMsg = q{Unable to find type '%s' in library '%s'};

=head1 METHODS

=cut

=head2 import

Provides the import mechanism for your library. See 
L<MooseX::Types/"LIBRARY USAGE"> for syntax details on this.

=cut

sub import {
    my ($class, @args) = @_;

    # filter or create options hash for S:E
    my $options = (@args and (ref($args[0]) eq 'HASH')) ? $args[0] : undef;
    unless ($options) {
        $options = {foo => 23};
        unshift @args, $options;
    }

    # all types known to us
    my @types = $class->type_names;

    # determine the wrapper, -into is supported for compatibility reasons
    my $wrapper = $options->{ -wrapper } || 'MooseX::Types';
    $args[0]->{into} = $options->{ -into } 
        if exists $options->{ -into };

    my (%ex_spec, %ex_util);
  TYPE:
    for my $type_short (@types) {

        # find type name and object, create undefined message
        my $type_full = $class->get_type($type_short)
            or croak "No fully qualified type name stored for '$type_short'";
        my $type_cons = find_type_constraint($type_full);
        my $undef_msg = sprintf($UndefMsg, $type_short, $class);

        # the type itself
        push @{ $ex_spec{exports} }, 
            $type_short,
            sub { 
                bless $wrapper->type_export_generator($type_short, $type_full),
                    'MooseX::Types::EXPORTED_TYPE_CONSTRAINT';
            };

        # the check helper
        push @{ $ex_spec{exports} },
            "is_${type_short}",
            sub { $wrapper->check_export_generator($type_short, $type_full, $undef_msg) };

        # only export coercion helper if full (for libraries) or coercion is defined
        next TYPE
            unless $options->{ -full }
            or ($type_cons and $type_cons->has_coercion);
        push @{ $ex_spec{exports} },
            "to_${type_short}",
            sub { $wrapper->coercion_export_generator($type_short, $type_full, $undef_msg) };
        $ex_util{ $type_short }{to}++;  # shortcut to remember this exists
    }

    # create S:E exporter and increase export level unless specified explicitly
    my $exporter = build_exporter \%ex_spec;
    $options->{into_level}++ 
        unless $options->{into};

    # remember requested symbols to determine what helpers to auto-export
    my %was_requested = 
        map  { ($_ => 1) } 
        grep { not ref } 
        @args;

    # determine which additional symbols (helpers) to export along
    my %add;
  EXPORT:
    for my $type (grep { exists $was_requested{ $_ } } @types) {
        $add{ "is_$type" }++
            unless $was_requested{ "is_$type" };
        next EXPORT
            unless exists $ex_util{ $type }{to};
        $add{ "to_$type" }++
            unless $was_requested{ "to_$type" };
    }

    # and on to the real exporter
    my @new_args = (@args, keys %add);
    return $class->$exporter(@new_args);
}

=head2 get_type

This returns a type from the library's store by its name.

=cut

sub get_type {
    my ($class, $type) = @_;

    # useful message if the type couldn't be found
    croak "Unknown type '$type' in library '$class'"
        unless $class->has_type($type);

    # return real name of the type
    return $class->type_storage->{ $type };
}

=head2 type_names

Returns a list of all known types by their name.

=cut

sub type_names {
    my ($class) = @_;

    # return short names of all stored types
    return keys %{ $class->type_storage };
}

=head2 add_type

Adds a new type to the library.

=cut

sub add_type {
    my ($class, $type) = @_;

    # store type with library prefix as real name
    $class->type_storage->{ $type } = "${class}::${type}";
}

=head2 has_type

Returns true or false depending on if this library knows a type by that
name.

=cut

sub has_type {
    my ($class, $type) = @_;

    # check if we stored a type under that name
    return ! ! $class->type_storage->{ $type };
}

=head2 type_storage

Returns the library's type storage hash reference. You shouldn't use this
method directly unless you know what you are doing. It is not an internal
method because overriding it makes virtual libraries very easy.

=cut

sub type_storage {
    my ($class) = @_;

    # return a reference to the storage in ourself
    {   no strict 'refs';
        return \%{ $class . '::__MOOSEX_TYPELIBRARY_STORAGE' };
    }
}

=head2 registered_class_types

Returns the class types registered within this library. Don't use directly.

=cut

sub registered_class_types {
    my ($class) = @_;

    {
        no strict 'refs';
        return \%{ $class . '::__MOOSEX_TYPELIBRARY_CLASS_TYPES' };
    }
}

=head2 register_class_type

Register a C<class_type> for use in this library by class name.

=cut

sub register_class_type {
    my ($class, $type) = @_;

    croak "Not a class_type"
        unless $type->isa('Moose::Meta::TypeConstraint::Class');

    $class->registered_class_types->{$type->class} = $type;
}

=head2 get_registered_class_type

Get a C<class_type> registered in this library by name.

=cut

sub get_registered_class_type {
    my ($class, $name) = @_;

    $class->registered_class_types->{$name};
}

=head2 registered_role_types

Returns the role types registered within this library. Don't use directly.

=cut

sub registered_role_types {
    my ($class) = @_;

    {
        no strict 'refs';
        return \%{ $class . '::__MOOSEX_TYPELIBRARY_ROLE_TYPES' };
    }
}

=head2 register_role_type

Register a C<role_type> for use in this library by role name.

=cut

sub register_role_type {
    my ($class, $type) = @_;

    croak "Not a role_type"
        unless $type->isa('Moose::Meta::TypeConstraint::Role');

    $class->registered_role_types->{$type->role} = $type;
}

=head2 get_registered_role_type

Get a C<role_type> registered in this library by role name.

=cut

sub get_registered_role_type {
    my ($class, $name) = @_;

    $class->registered_role_types->{$name};
}

=head1 SEE ALSO

L<MooseX::Types::Moose>

=head1 AUTHOR

See L<MooseX::Types/AUTHOR>.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the same terms as perl itself.

=cut

1;
