package Class::MOP::Mixin::HasMethods;

use strict;
use warnings;

use Class::MOP::Method::Meta;

our $VERSION   = '1.12';
$VERSION = eval $VERSION;
our $AUTHORITY = 'cpan:STEVAN';

use Scalar::Util 'blessed';
use Carp         'confess';
use Sub::Name    'subname';

use base 'Class::MOP::Mixin';

sub method_metaclass         { $_[0]->{'method_metaclass'}            }
sub wrapped_method_metaclass { $_[0]->{'wrapped_method_metaclass'}    }
sub _meta_method_class       { 'Class::MOP::Method::Meta'             }

sub _add_meta_method {
    my $self = shift;
    my ($name) = @_;
    my $existing_method = $self->can('find_method_by_name')
                              ? $self->find_method_by_name($name)
                              : $self->get_method($name);
    return if $existing_method
           && $existing_method->isa($self->_meta_method_class);
    $self->add_method(
        $name => $self->_meta_method_class->wrap(
            name                 => $name,
            package_name         => $self->name,
            associated_metaclass => $self,
        )
    );
}

# This doesn't always get initialized in a constructor because there is a
# weird object construction path for subclasses of Class::MOP::Class. At one
# point, this always got initialized by calling into the XS code first, but
# that is no longer guaranteed to happen.
sub _method_map { $_[0]->{'methods'} ||= {} }

sub wrap_method_body {
    my ( $self, %args ) = @_;

    ( 'CODE' eq ref $args{body} )
        || confess "Your code block must be a CODE reference";

    $self->method_metaclass->wrap(
        package_name => $self->name,
        %args,
    );
}

sub add_method {
    my ( $self, $method_name, $method ) = @_;
    ( defined $method_name && length $method_name )
        || confess "You must define a method name";

    my $package_name = $self->name;

    my $body;
    if ( blessed($method) ) {
        $body = $method->body;
        if ( $method->package_name ne $package_name ) {
            $method = $method->clone(
                package_name => $package_name,
                name         => $method_name,
            ) if $method->can('clone');
        }

        $method->attach_to_class($self);
    }
    else {
        # If a raw code reference is supplied, its method object is not created.
        # The method object won't be created until required.
        $body = $method;
    }

    $self->_method_map->{$method_name} = $method;

    my ( $current_package, $current_name ) = Class::MOP::get_code_info($body);

    if ( !defined $current_name || $current_name =~ /^__ANON__/ ) {
        my $full_method_name = ( $package_name . '::' . $method_name );
        subname( $full_method_name => $body );
    }

    $self->add_package_symbol(
        { sigil => '&', type => 'CODE', name => $method_name },
        $body,
    );
}

sub _code_is_mine {
    my ( $self, $code ) = @_;

    my ( $code_package, $code_name ) = Class::MOP::get_code_info($code);

    return $code_package && $code_package eq $self->name
        || ( $code_package eq 'constant' && $code_name eq '__ANON__' );
}

sub has_method {
    my ( $self, $method_name ) = @_;

    ( defined $method_name && length $method_name )
        || confess "You must define a method name";

    return defined( $self->_get_maybe_raw_method($method_name) );
}

sub get_method {
    my ( $self, $method_name ) = @_;

    ( defined $method_name && length $method_name )
        || confess "You must define a method name";

    my $method = $self->_get_maybe_raw_method($method_name)
        or return;

    return $method if blessed $method;

    return $self->_method_map->{$method_name} = $self->wrap_method_body(
        body                 => $method,
        name                 => $method_name,
        associated_metaclass => $self,
    );
}

sub _get_maybe_raw_method {
    my ( $self, $method_name ) = @_;

    my $method_map = $self->_method_map;
    my $map_entry  = $method_map->{$method_name};
    my $code       = $self->get_package_symbol(
        {
            name  => $method_name,
            sigil => '&',
            type  => 'CODE',
        }
    );

    # The !$code case seems to happen in some weird cases where methods
    # modifiers are added via roles or some other such bizareness. Honestly, I
    # don't totally understand this, but returning the entry works, and keeps
    # various MX modules from blowing up. - DR
    return $map_entry
        if blessed $map_entry && ( !$code || $map_entry->body == $code );

    unless ($map_entry) {
        return unless $code && $self->_code_is_mine($code);
    }

    return $code;
}

sub remove_method {
    my ( $self, $method_name ) = @_;
    ( defined $method_name && length $method_name )
        || confess "You must define a method name";

    my $removed_method = delete $self->_full_method_map->{$method_name};

    $self->remove_package_symbol(
        { sigil => '&', type => 'CODE', name => $method_name } );

    $removed_method->detach_from_class
        if $removed_method && blessed $removed_method;

    # still valid, since we just removed the method from the map
    $self->update_package_cache_flag;

    return $removed_method;
}

sub get_method_list {
    my $self = shift;

    my $namespace = $self->namespace;

    # Constants may show up as some sort of non-GLOB reference in the
    # namespace hash ref, depending on the Perl version.
    return grep {
        defined $namespace->{$_}
            && ( ref( \$namespace->{$_} ) ne 'GLOB'
            || *{ $namespace->{$_} }{CODE} )
            && $self->has_method($_)
        }
        keys %{$namespace};
}

# This should probably be what get_method_list actually does, instead of just
# returning names. This was created as a much faster alternative to
# $meta->get_method($_) for $meta->get_method_list
sub _get_local_methods {
    my $self = shift;

    my $namespace = $self->namespace;

    return map { $self->get_method($_) }
        grep {
        defined $namespace->{$_}
            && ( ref $namespace->{$_}
            || *{ $namespace->{$_} }{CODE} )
        }
        keys %{$namespace};
}

sub _restore_metamethods_from {
    my $self = shift;
    my ($old_meta) = @_;

    for my $method ($old_meta->_get_local_methods) {
        $method->_make_compatible_with($self->method_metaclass);
        $self->add_method($method->name => $method);
    }
}

1;

__END__

=pod

=head1 NAME

Class::MOP::Mixin::HasMethods - Methods for metaclasses which have methods

=head1 DESCRIPTION

This class implements methods for metaclasses which have methods
(L<Class::MOP::Package> and L<Moose::Meta::Role>). See L<Class::MOP::Package>
for API details.

=head1 AUTHORS

Dave Rolsky E<lt>autarch@urth.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2010 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
