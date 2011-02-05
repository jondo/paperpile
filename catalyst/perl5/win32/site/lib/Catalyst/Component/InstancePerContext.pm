package Catalyst::Component::InstancePerContext;

use Moose::Role;
use Scalar::Util qw/blessed refaddr/;
use strict;
use warnings;

our $VERSION = '0.001001';

requires 'build_per_context_instance';

# Hi, this is why I exist:
# <mst> I'd like to see a Catalyst::Component::InstancePerContext role
# <mst> that requires 'build_per_context_instance'
# <mst> and provides an ACCEPT_CONTEXT that does the appropriate magic
# <mst> ACCEPT_CONTEXT would do the stash persist as well

sub ACCEPT_CONTEXT {
    my $self = shift;
    my ($c) = @_;

    return $self->build_per_context_instance(@_) unless ref $c;
    my $key = blessed $self ? refaddr $self : $self;
    return $c->stash->{"__InstancePerContext_${key}"} ||= $self->build_per_context_instance(@_);
}

1;

=head1 NAME

Catalyst::Component::InstancePerContext -
Return a new instance a component on each request

=head1 SYNOPSYS

    package MyComponent;
    use Moose;
    with 'Catalyst::Component::InstancePerContext';

    sub build_per_context_instance{
        my ($self, $c) = @_;
        # ... do your thing here
        return SomeModule->new(%args);
    }

=head1 REQUIRED METHODS

Your consuming class B<must> implement the following method.

=head2 build_per_context_instance

The value returned by this call is what you will recieve when you call
$c->component('YourComponent').

=head1 PROVIDED METHODS

This role will add the following method to your consuming class.

=head2 ACCEPT_CONTEXT

If the context is not blessed, it will simple pass through the value of
C<build_per_context_instance>. If context is blessed it will look in the
C<stash> for an instance of the requested component and return that or,
if the value is not found, the value returned by C<build_per_context_instance>
will be stored and return.

The idea behind this behavior is that a component can be built on a
per-request basis, as the name of this module implies.

=head1 SEE ALSO

L<Moose>, L<Moose::Role>, L<Catalyst::Component>

=head1 AUTHOR

Guillermo Roditi (groditi) <groditi@cpan.org>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
