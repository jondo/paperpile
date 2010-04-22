# Copyright (c) 1998-2005 by Jonathan Swartz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.

package HTML::Mason::Component::Subcomponent;

use strict;
use warnings;

use HTML::Mason::Component;

use vars qw(@ISA);

@ISA = qw(HTML::Mason::Component);

use HTML::Mason::MethodMaker ( read_only => [ qw( comp_id is_method name owner path ) ] );

#
# Assign parent, name, and is_method flag when owner component is created.
#
sub assign_subcomponent_properties {
    my $self = shift;
    ($self->{owner}, $self->{name}, $self->{is_method}) = @_;
}

#
# Override path that would be set by parent's version of method.
#
sub assign_runtime_properties {
    my ($self, $interp, $source) = @_;
    $self->SUPER::assign_runtime_properties($interp, $source);
    $self->{comp_id} = sprintf("[%s '%s' of %s]", $self->{is_method} ? 'method' : 'subcomponent',
                               $self->name, $self->owner->comp_id);
    $self->{path} = $self->owner->path . ":" . $self->name;
}

sub cache_file { return $_[0]->owner->cache_file }
sub load_time { return $_[0]->owner->load_time }
sub compiler_id { return $_[0]->owner->compilation_params }
sub dir_path { return $_[0]->owner->dir_path }
sub is_subcomp { 1 }
sub object_file { return $_[0]->owner->object_file }
sub parent { return $_[0]->owner->parent }
sub persistent { return $_[0]->owner->persistent }
sub title { return $_[0]->owner->title . ":" . $_[0]->name }

1;

__END__

=head1 NAME

HTML::Mason::Component::Subcomponent - Mason Subcomponent Class

=head1 DESCRIPTION

This is a subclass of
L<HTML::Mason::Component|HTML::Mason::Component>. Mason uses it to
implement both subcomponents (defined by C<< <%def> >>) and methods (defined
by C<< <%method> >>).

A subcomponent/method gets most of its properties from its owner. Note
that the link from the subcomponent to its owner is a weak reference
(to prevent circular references), so if you grab a subcomponent/method
object, you should also grab and hold a reference to its owner. If the
owner goes out of scope, the subcomponent/method object will become unusable.

=head1 METHODS

=over 4

=item is_method

Returns 1 if this is a method (declared by C<< <%method> >>), 0 if it is a
subcomponent (defined by c<< <%def> >>).

=item owner

Returns the component object within which this subcomponent or method
was defined.

=back

=head1 SEE ALSO

L<HTML::Mason::Component|HTML::Mason::Component>

=cut
