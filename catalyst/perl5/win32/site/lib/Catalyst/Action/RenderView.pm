package Catalyst::Action::RenderView;

use strict;
use warnings;

our $VERSION = '0.16';

use base 'Catalyst::Action';

use MRO::Compat;
use Data::Visitor::Callback;

my %ignore_classes = ();

sub execute {
    my $self = shift;
    my ($controller, $c ) = @_;
    $self->next::method( @_ );

    $c->config->{'Action::RenderView'}->{ignore_classes} =
        ( ref($c->config->{'debug'}) eq 'HASH' ? $c->config->{'debug'}->{ignore_classes} : undef )
        || [ qw/
        DBIx::Class::ResultSource::Table 
        DBIx::Class::ResultSourceHandle
        DateTime
        / ] unless exists $c->config->{'Action::RenderView'}->{ignore_classes};

    $c->config->{'Action::RenderView'}->{scrubber_func} =
        ( ref($c->config->{'debug'}) eq 'HASH' ? $c->config->{'debug'}->{scrubber_func} : undef )
        || sub { $_='[stringified to: ' .  $_ . ']' }
        unless exists $c->config->{'Action::RenderView'}->{scrubber_func};

    if ($c->debug && $c->req->params->{dump_info}) {
        unless ( keys %ignore_classes ) {
            foreach my $class (@{$c->config->{'Action::RenderView'}->{ignore_classes}}) {
                $ignore_classes{$class} = $c->config->{'Action::RenderView'}->{scrubber_func};
            }
        }
        my $scrubber=Data::Visitor::Callback->new(
            "ignore_return_values"             => 1,
            "object"                           => "visit_ref",
            %ignore_classes,
        );
        $scrubber->visit( $c->stash );
        die('Forced debug - Scrubbed output');
    }

    if(! $c->response->content_type ) {
        $c->response->content_type( 'text/html; charset=utf-8' );
    }
    return 1 if $c->req->method eq 'HEAD';
    return 1 if defined $c->response->body;
    return 1 if scalar @{ $c->error } && !$c->stash->{template};
    return 1 if $c->response->status =~ /^(?:204|3\d\d)$/;
    my $view = $c->view()
        || die "Catalyst::Action::RenderView could not find a view to forward to.\n";
    $c->forward( $view );
};

1;

=head1 NAME

Catalyst::Action::RenderView - Sensible default end action.

=head1 SYNOPSIS

    sub end : ActionClass('RenderView') {}

=head1 DESCRIPTION

This action implements a sensible default end action, which will forward
to the first available view, unless C<< $c->res->status >> is a 3xx code
(redirection, not modified, etc.), 204 (no content), or C<< $c->res->body >> has
already been set. It also allows you to pass C<dump_info=1> to the url in
order to force a debug screen, while in debug mode.

If you have more than one view, you can specify which one to use with
the C<default_view> config setting and the C<current_view> and
C<current_view_instance> stash keys (see L<Catalyst>'s C<$c-E<gt>view($name)>
method -- this module simply calls C<< $c->view >> with no argument).

=head1 METHODS

=head2 end

The default C<end> action. You can override this as required in your
application class; normal inheritance applies.

=head1 INTERNAL METHODS

=head2 execute

Dispatches control to superclasses, then forwards to the default View.

See L<Catalyst::Action/METHODS/action>.

=head1 SCRUBBING OUTPUT

When you force debug with dump_info=1, RenderView is capable of removing
classes from the objects in your stash. By default it will replace any
DBIx::Class resultsource objects with the class name, which cleans up the
debug output considerably, but you can change what gets scrubbed by 
setting a list of classes in 
$c->config->{'Action::RenderView'}->{ignore_classes}.
For instance:

    $c->config->{'Action::RenderView'}->{ignore_classes} = []; 
    
To disable the functionality. You can also set 
config->{'Action::RenderView'}->{scrubber_func} to change what it does with the 
classes. For instance, this will undef it instead of putting in the 
class name:

    $c->config->{'Action::RenderView'}->{scrubber_func} = sub { undef $_ };

=head2 Deprecation notice

This plugin used to be configured by setting C<< $c->config->{debug} >>.
That configuration key is still supported in this release, but is 
deprecated, please use the C< 'Action::RenderView' > namespace as shown 
above for configuration in new code.

=head1 EXTENDING

To add something to an C<end> action that is called before rendering,
simply place it in the C<end> method:

    sub end : ActionClass('RenderView') {
      my ( $self, $c ) = @_;
      # do stuff here; the RenderView action is called afterwards
    }

To add things to an C<end> action that are called I<after> rendering,
you can set it up like this:

    sub render : ActionClass('RenderView') { }

    sub end : Private { 
      my ( $self, $c ) = @_;
      $c->forward('render');
      # do stuff here
    }

=head1 AUTHORS

Marcus Ramberg <marcus@thefeed.no>

Florian Ragwitz E<lt>rafl@debian.orgE<gt>

=head1 COPYRIGHT

Copyright (c) 2006 - 2009
the Catalyst::Action::RenderView L</AUTHOR>
as listed above.

=head1 LICENSE

This library is free software. You can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

