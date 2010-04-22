package HTML::Mason::Plugin;

use strict;
use warnings;

sub new {
    my $class = shift;
    bless { @_ }, $class;
}

sub start_request_hook {
    # my ($self, $context) = @_;
    # $context has: request, args
}

sub end_request_hook {
    # my ($self, $context) = @_;
    # $context has: request, args, output, wantarray, result, error
}

sub start_component_hook {
    # my ($self, $context) = @_;
    # $context has: request, comp, args
}

sub end_component_hook {
    # my ($self, $context) = @_;
    # $context has: request, comp, args, wantarray, result, error
}

1;

__END__

=head1 NAME

HTML::Mason::Plugin - Plugin Base class for Mason

=head1 SYNOPIS

   package MasonX::Plugin::Timer;
   use base qw(HTML::Mason::Plugin);
   use Time::HiRes;

   sub start_component_hook {
       my ($self, $context) = @_;
       push @{$self->{ timers }}, Time::HiRes::time;
   }

   sub end_component_hook {
       my ($self, $context) = @_;
       my $elapsed = Time::HiRes::time - pop @{$self->{ timers }};
       printf STDERR "Component '%s' took %.1f seconds\n",
           $context->comp->title, $elapsed;
   }

   1;

=head1 DESCRIPTION

Use a Mason plugin to have actions occur at the beginning or end of
requests or components. Plugins are activated by passing L<plugins|HTML::Mason::Params/plugins> in
the interpreter or request object. Each plugin in the list can be
specified as a class name (in which case the plugin object is created
once for each request) or as an actual object of the plugin class.

If your plugin can be configured, place the configuration in class
variables - for example,

    $MasonX::Plugin::Timer::Units = 'seconds';

These can be set either from httpd.conf via PerlSetVar
directives, or in perl directly from a handler.pl file.

=head1 PLUGIN HOOKS

A plugin class defines one or more of the following hooks (methods):
I<start_request_hook>, I<end_request_hook>, I<start_component_hook>,
and I<end_component_hook>.

Every hook receives two arguments: the plugin object itself,
and a context object with various methods.

=over

=item start_request_hook

C<start_request_hook> is called before the Mason request begins
execution.  Its context has the following read-only methods:

    request # the current request ($m)
    args    # arguments the request was called with

When called in scalar context, I<args> returns a list reference which
may be modified to change or add to the arguments passed to the first
component. When called in list context, I<args> returns a list (which
may be assigned to a hash).

Note that subrequests (see
L<HTML::Mason::Request|HTML::Mason::Request> will create a new plugin
object and execute this code again; you can skip your code for
subrequests by checking C<is_subrequest> on I<request>. e.g.

   sub start_request_hook {
       my ($self, $context) = @_;
       unless ($context->request->is_subrequest()) {
           # perform hook action
       }
   }

Currently, this hook is called before any information about the
requested component is available, so you cannot call methods like
C<base_comp()> or C<request_args()> on the Request object.

=item end_request_hook

C<end_request_hook> is called before the Mason request
exits. Its context has the following read-only methods:

    request     # the current request ($m)
    args        # arguments the request was called with
    output      # reference to the contents of the output buffer
    wantarray   # value of wantarray the request was called with
    result      # arrayref of value(s) that the request is about to return
    error       # reference to error, if any, that the request is about to throw

When called in scalar context, I<args> returns a list reference; when
called in list context, it returns a list (which may be assigned to a
hash).

I<result> always contains an array ref; if I<wantarray> is 0, the
return value is the the first element of that array. The plugin may
modify I<output> to affect what the request outputs, and 
I<result> and I<error> to affect what the request returns.

=item start_component_hook

C<start_component_hook> is called before a component begins
executing. Its context has the following read-only methods:

    request     # the current request ($m)
    comp        # the component object
    args        # arrayref of arguments the component was called with

The plugin may NOT modify I<args> currently.

=item end_component_hook

C<end_component_hook()> is called after a component has
completed. Its context has the following read-only methods:

    request     # the current request ($m)
    comp        # the component object
    args        # arrayref of arguments the component was called with
    wantarray   # value of wantarray the component was called with
    result      # arrayref of value(s) that the component is about to return
    error       # reference to error, if any, that the component is about to throw

I<result> always contains an array ref; if I<wantarray>
is 0, the return value is the first element of that array.  The plugin
may modify both I<result> and I<error> to affect how the request
returns.

It would be desirable for this hook to have access to the component's
output as well as its return value, but this is currently impossible
because output from multiple components combine into a single buffer.

=back

=head1 WARNINGS

Do not keep an unweakened reference to a request or component object
in your plugin object, or you will create a nasty circular reference.

=head1 AUTHORS

Doug Treder, Jonathan Swartz, Dave Rolsky

=head1 SEE ALSO

L<HTML::Mason::Interp|HTML::Mason::Interp>, L<HTML::Mason::Request|HTML::Mason::Request>

=cut
