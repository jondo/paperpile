# -*- cperl-indent-level: 4; cperl-continued-brace-offset: -4; cperl-continued-statement-offset: 4 -*-

# Copyright (c) 1998-2005 by Jonathan Swartz. All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.


#
# A note about the internals:
#
# Because request is the single most intensively used piece of the
# Mason architecture, this module is often the best target for
# optimization.
#
# By far, the two methods called most often are comp() and print().
# We have attempted to optimize the parts of these methods that handle
# the _normal_ path through the code.
#
# Code paths that are followed less frequently (like the path that
# handles the $mods{store} parameter in comp, for example) are
# intentionally not optimized because doing so would clutter the code
# while providing a minimal benefit.
#
# Many of the optimizations consist of ignoring defined interfaces for
# accessing parts of the request object's internal data structure, and
# instead accessing it directly.
#
# We have attempted to comment these various optimizations
# appropriately, so that future hackers understand that we did indeed
# mean to not use the relevant interface in that particular spot.
#

package HTML::Mason::Request;

use strict;
use warnings;

use File::Spec;
use HTML::Mason::Cache::BaseCache;
use HTML::Mason::Plugin::Context;
use HTML::Mason::Tools qw(can_weaken read_file compress_path load_pkg pkg_loaded absolute_comp_path);
use HTML::Mason::Utils;
use Log::Any qw($log);
use Class::Container;
use base qw(Class::Container);

# Stack frame constants
use constant STACK_COMP         => 0;
use constant STACK_ARGS         => 1;
use constant STACK_BUFFER       => 2;
use constant STACK_MODS         => 3;
use constant STACK_PATH         => 4;
use constant STACK_BASE_COMP    => 5;
use constant STACK_IN_CALL_SELF => 6;
use constant STACK_BUFFER_IS_FLUSHABLE => 7;
use constant STACK_HIDDEN_BUFFER => 8;

# HTML::Mason::Exceptions always exports rethrow_exception() and isa_mason_exception()
use HTML::Mason::Exceptions( abbr => [qw(error param_error syntax_error
                                         top_level_not_found_error error)] );

use Params::Validate qw(:all);
Params::Validate::validation_options( on_fail => sub { param_error( join '', @_ ) } );

BEGIN
{
    __PACKAGE__->valid_params
        (
         args =>
         { type => ARRAYREF, default => [],
           descr => "Array of arguments to initial component",
           public => 0 },

         autoflush =>
         { parse => 'boolean', default => 0, type => SCALAR,
           descr => "Whether output should be buffered or sent immediately" },

         comp =>
         { type => SCALAR | OBJECT, optional => 0,
           descr => "Initial component, either an absolute path or a component object",
           public => 0 },

         data_cache_api =>
         { parse => 'string', default => '1.1', type => SCALAR,
           regex => qr/^(?:1\.0|1\.1|chi)$/,
           descr => "Data cache API to use: 1.0, 1.1, or chi" },

         data_cache_defaults =>
         { parse => 'hash_list', type => HASHREF|UNDEF, optional => 1,
           descr => "A hash of default parameters for Cache::Cache or CHI" },

         declined_comps =>
         { type => HASHREF, optional => 1,
           descr => "Hash of components that have been declined in previous parent requests",
           public => 0 },

         dhandler_name =>
         { parse => 'string', default => 'dhandler', type => SCALAR,
           descr => "The filename to use for Mason's 'dhandler' capability" },

         interp =>
         { isa => 'HTML::Mason::Interp',
           descr => "An interpreter for Mason control functions",
           public => 0 },

         error_format =>
         { parse => 'string', type => SCALAR, default => 'text',
           callbacks => { "HTML::Mason::Exception->can( method )'" =>
                          sub { HTML::Mason::Exception->can("as_$_[0]"); } },
           descr => "How error conditions are returned to the caller (brief, text, line or html)" },

         error_mode =>
         { parse => 'string', type => SCALAR, default => 'fatal',
           regex => qr/^(?:output|fatal)$/,
           descr => "How error conditions are manifest (output or fatal)" },

         component_error_handler =>
         { parse => 'code', type => CODEREF|SCALAR, default => \&rethrow_exception,
           descr => "A subroutine reference called on component compilation or runtime errors" },

         max_recurse =>
         { parse => 'string', default => 32, type => SCALAR,
           descr => "The maximum recursion depth for component, inheritance, and request stack" },

         out_method =>
         { parse => 'code' ,type => CODEREF|SCALARREF,
           default => sub { print STDOUT $_[0] },
           descr => "A subroutine or scalar reference through which all output will pass" },

         # Only used when creating subrequests
         parent_request =>
         { isa => __PACKAGE__,
           default => undef,
           public  => 0,
         },

         plugins =>
         { parse => 'list', default => [], type => ARRAYREF,
           descr => 'List of plugin classes or objects to run hooks around components and requests' },

         # Only used when creating subrequests
         request_depth =>
         { type => SCALAR,
           default => 1,
           public  => 0,
         },

        );
}

my @read_write_params;
BEGIN { @read_write_params = qw(
                                autoflush
                                component_error_handler
                                data_cache_api
                                data_cache_defaults
                                dhandler_name
                                error_format
                                error_mode
                                max_recurse
                                out_method
                                ); }

use HTML::Mason::MethodMaker
    ( read_only => [ qw(
                        count
                        dhandler_arg
                        initialized
                        interp
                        parent_request
                        plugin_instances
                        request_depth
                        request_comp
                        ) ],

      read_write => [ map { [ $_ => __PACKAGE__->validation_spec->{$_} ] }
                      @read_write_params ]
    );

sub _properties { @read_write_params }

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    # These are mandatory values for all requests.
    #
    %$self = (%$self,
              dhandler_arg   => undef,
              execd          => 0,
              initialized    => 0,
              stack          => [],
              top_stack      => undef,
              wrapper_chain  => undef,
              wrapper_index  => undef,
              notes          => {},
              );

    $self->{request_comp} = delete($self->{comp});
    $self->{request_args} = delete($self->{args});
    if (UNIVERSAL::isa($self->{request_args}, 'HASH')) {
        $self->{request_args} = [%{$self->{request_args}}];
    }
    $self->{count} = ++$self->{interp}{request_count};
    if (ref($self->{out_method}) eq 'SCALAR') {
        my $bufref = $self->{out_method};
        $self->{out_method} = sub { $$bufref .= $_[0] };
    }
    $self->{use_internal_component_caches} =
        $self->{interp}->use_internal_component_caches;
    $self->_initialize;

    return $self;
}

# in the future this method may do something completely different but
# for now this works just fine.
sub instance {
    return $HTML::Mason::Commands::m; #; this comment fixes a parsing bug in Emacs cperl-mode
}

# Attempt to load each plugin module once per process
my %plugin_loaded;

sub _initialize {
    my ($self) = @_;

    local $SIG{'__DIE__'} = $self->component_error_handler
        if $self->component_error_handler;

    eval {
        # Check the static_source touch file, if it exists, before the
        # first component is loaded.
        #
        $self->interp->check_static_source_touch_file();

        # request_comp can be an absolute path or component object.  If a path,
        # load into object.
        my $request_comp = $self->{request_comp};
        my ($path);
        if (!ref($request_comp)) {
            $request_comp =~ s{/+}{/}g;
            $self->{top_path} = $path = $request_comp;
            $log->debugf("top path is '%s'", $self->{top_path})
                if $log->is_debug;

            my $retry_count = 0;
            search: {
                $request_comp = $self->interp->load($path);

                last search unless $self->use_dhandlers;

                # If path was not found, check for dhandler.
                unless ($request_comp) {
                    if ( $request_comp = $self->interp->find_comp_upwards($path, $self->dhandler_name) ) {
                        my $parent_path = $request_comp->dir_path;
                        ($self->{dhandler_arg} = $self->{top_path}) =~ s{^$parent_path/?}{};
                        $log->debugf("found dhandler '%s', dhandler_arg '%s'", $parent_path, $self->{dhandler_arg})
                            if $log->is_debug;
                    }
                }

                # If the component was declined previously in this
                # request, look for the next dhandler up the
                # tree. 
                if ($request_comp and $self->{declined_comps}->{$request_comp->comp_id}) {
                    $path = $request_comp->dir_path;
                    if ($request_comp->name eq $self->dhandler_name) {
                        if ($path eq '/') {
                            undef $request_comp;
                            last search;  # End search if /dhandler declined
                        } else {
                            $path =~ s:/[^\/]+$::;
                            $path ||= '/';
                        }
                    }
                    if ($retry_count++ > $self->max_recurse) {
                        error "could not find dhandler after " . $self->max_recurse . " tries (infinite loop bug?)";
                    }
                    redo search;
                }
            }

            unless ($self->{request_comp} = $request_comp) {
                top_level_not_found_error "could not find component for initial path '$self->{top_path}' " .
                    "(component roots are: " .
                    join(", ", map { "'" . $_->[1] . "'" } $self->{interp}->comp_root_array) .
                    ")";
            }

        } elsif ( ! UNIVERSAL::isa( $request_comp, 'HTML::Mason::Component' ) ) {
            param_error "comp ($request_comp) must be a component path or a component object";
        }

        # Construct a plugin instance for each plugin class in each request.
        #
        $self->{has_plugins} = 0;
        $self->{plugin_instances} = [];
        foreach my $plugin (@{ delete $self->{plugins} }) {
            $self->{has_plugins} = 1;
            my $plugin_instance = $plugin;
            unless (ref $plugin) {

                # Load information about each plugin class once per
                # process.  Right now the only information we need is
                # whether there is a new() method.
                #
                unless ($plugin_loaded{$plugin}) {
                    # Load plugin package if it isn't already loaded.
                    #
                    {
                        no strict 'refs';
                        unless (keys %{$plugin . "::"}) {
                            eval "use $plugin;";
                            die $@ if $@;
                        }
                    }
                    $plugin_loaded{$plugin} = 1;
                }
                $plugin_instance = $plugin->new();
            }
            push @{$self->{plugin_instances}}, $plugin_instance;
        }
        $self->{plugin_instances_reverse} = [reverse(@{$self->{plugin_instances}})];

        # Check for autoflush and !enable_autoflush
        #
        if ($self->{autoflush} && !$self->interp->compiler->enable_autoflush) {
            die "Cannot use autoflush unless enable_autoflush is set";
        }

    };

    my $err = $@;
    if ($err and !$self->_aborted_or_declined($err)) {
        $self->_handle_error($err);
    } else {
        $self->{initialized} = 1;
    }
}

sub use_dhandlers
{
    my $self = shift;
    return defined $self->{dhandler_name} and length $self->{dhandler_name};
}

sub alter_superclass
{
    my $self = shift;
    my $new_super = shift;

    my $class = caller;

    my $isa_ref;
    {
        no strict 'refs';
        my @isa = @{ $class . '::ISA' };
        $isa_ref = \@isa;
    }

    # handles multiple inheritance properly and preserve
    # inheritance order
    for ( my $x = 0; $x <= $#{$isa_ref} ; $x++ )
    {
        if ( $isa_ref->[$x]->isa('HTML::Mason::Request') )
        {
            my $old_super = $isa_ref->[$x];

            if ( $old_super ne $new_super )
            {
                $isa_ref->[$x] = $new_super;
            }

            last;
        }
    }

    {
        no strict 'refs';
        @{ $class . '::ISA' } = @{ $isa_ref };
    }

    $class->valid_params( %{ $class->valid_params } );
}

sub exec {
    my ($self) = @_;

    # If the request failed to initialize, the error has already been handled
    # at the bottom of _initialize(); just return.
    return unless $self->initialized();

    local $SIG{'__DIE__'} = $self->component_error_handler
        if $self->component_error_handler;

    # Cheap way to prevent users from executing the same request twice.
    #
    if ($self->{execd}++) {
        error "Can only call exec() once for a given request object. Did you want to use a subrequest?";
    }

    # Check for infinite subrequest loop.
    #
    error "subrequest depth > " . $self->max_recurse . " (infinite subrequest loop?)"
        if $self->request_depth > $self->max_recurse;

    #
    # $m is a dynamically scoped global containing this
    # request. This needs to be defined in the HTML::Mason::Commands
    # package, as well as the component package if that is different.
    #
    local $HTML::Mason::Commands::m = $self;

    # Dynamically scoped global pointing at the top of the request stack.
    #
    $self->{top_stack} = undef;

    # Save context of subroutine for use inside eval.
    my $wantarray = wantarray;
    my @result;

    # Initialize output buffer to interpreter's preallocated buffer
    # before clearing, to reduce memory reallocations.
    #
    $self->{request_buffer} = $self->interp->preallocated_output_buffer;
    $self->{request_buffer} = '';

    $log->debugf("starting request for '%s'", $self->request_comp->title)
        if $log->is_debug;

    eval {
        # Build wrapper chain and index.
        my $request_comp = $self->request_comp;
        my $first_comp;
        {
            my @wrapper_chain = ($request_comp);

            for (my $parent = $request_comp->parent; $parent; $parent = $parent->parent) {
                unshift(@wrapper_chain,$parent);
                error "inheritance chain length > " . $self->max_recurse . " (infinite inheritance loop?)"
                    if (@wrapper_chain > $self->max_recurse);
            }

            $first_comp = $wrapper_chain[0];
            $self->{wrapper_chain} = [@wrapper_chain];
            $self->{wrapper_index} = { map
                                       { $wrapper_chain[$_]->comp_id => $_ }
                                       (0..$#wrapper_chain)
                                     };
        }

        # Get original request_args array reference to avoid copying.
        my $request_args = $self->{request_args};
        {
            local *SELECTED;
            tie *SELECTED, 'Tie::Handle::Mason';

            my $old = select SELECTED;
            my $mods = {base_comp => $request_comp, store => \($self->{request_buffer}), flushable => 1};

            if ($self->{has_plugins}) {
                my $context = bless
                    [$self, $request_args],
                    'HTML::Mason::Plugin::Context::StartRequest';
                eval {
                    foreach my $plugin_instance (@{$self->plugin_instances}) {
                        $plugin_instance->start_request_hook( $context );
                    }
                };
                if ($@) {
                    select $old;
                    rethrow_exception $@;
                }
            }

            if ($wantarray) {
                @result = eval {$self->comp($mods, $first_comp, @$request_args)};
            } elsif (defined($wantarray)) {
                $result[0] = eval {$self->comp($mods, $first_comp, @$request_args)};
            } else {
                eval {$self->comp($mods, $first_comp, @$request_args)};
            }
 
            my $error = $@;

            if ($self->{has_plugins}) {
                # plugins called in reverse order when exiting.
                my $context = bless
                    [$self, $request_args, \$self->{request_buffer}, $wantarray, \@result, \$error],
                    'HTML::Mason::Plugin::Context::EndRequest';
                eval {
                    foreach my $plugin_instance (@{$self->{plugin_instances_reverse}}) {
                        $plugin_instance->end_request_hook( $context );
                    }
                };
                if ($@) {
                    # plugin errors take precedence over component errors
                    $error = $@;
                }
            }
            
            select $old;
            rethrow_exception $error;
        }
    };

    $log->debugf("finishing request for '%s'", $self->request_comp->title)
        if $log->is_debug;

    # Purge code cache if necessary.
    $self->interp->purge_code_cache;

    # Handle errors.
    my $err = $@;
    if ($err and !$self->_aborted_or_declined($err)) {
        $self->_handle_error($err);
        return;
    }

    # If there's anything in the output buffer, send it to out_method.
    # Otherwise skip out_method call to avoid triggering side effects
    # (e.g. HTTP header sending).
    if (length($self->{request_buffer}) > 0) {
        $self->out_method->($self->{request_buffer});
    }

    # Return aborted value or result.
    @result = ($err->aborted_value) if $self->aborted($err);
    @result = ($err->declined_value) if $self->declined($err);
    return $wantarray ? @result : defined($wantarray) ? $result[0] : undef;
}

#
# Display or die with error as dictated by error_mode and error_format.
#
sub _handle_error
{
    my ($self, $err) = @_;

    $self->interp->purge_code_cache;

    rethrow_exception $err if $self->is_subrequest;

    # Set error format for when error is stringified.
    if (UNIVERSAL::can($err, 'format')) {
        $err->format($self->error_format);
    }

    # In fatal mode, die with error. In display mode, output stringified error.
    if ($self->error_mode eq 'fatal') {
        rethrow_exception $err;
    } else {
        if ( UNIVERSAL::isa( $self->out_method, 'CODE' ) ) {
            # This may not be set if an error occurred in
            # _initialize(), for example with a compilation error.
            # But the output method may rely on being able to get at
            # the request object.  This is a nasty code smell but
            # fixing it properly is probably out of scope.
            #
            # Previously this method could only be called from exec().
            #
            # Without this one of the tests in 16-live_cgi.t was
            # failing.
            local $HTML::Mason::Commands::m ||= $self;
            $self->out_method->("$err");
        } else {
            ${ $self->out_method } = "$err";
        }
    }
}

sub subexec
{
    my $self = shift;
    my $comp = shift;

    $self->make_subrequest(comp=>$comp, args=>\@_)->exec;
}

sub make_subrequest
{
    my ($self, %params) = @_;
    my $interp = $self->interp;

    # Coerce a string 'comp' parameter into an absolute path.  Don't
    # create it if it's missing, though - it's required, but for
    # consistency we let exceptions be thrown later.
    $params{comp} = absolute_comp_path($params{comp}, $self->current_comp->dir_path)
        if exists $params{comp} && !ref($params{comp});

    # Give subrequest the same values as parent request for read/write params
    my %defaults = map { ($_, $self->$_()) } $self->_properties;

    unless ( $params{out_method} )
    {
        $defaults{out_method} = sub {
            $self->print($_[0]);
        };
    }

    # Make subrequest, and set parent_request and request_depth appropriately.
    my $subreq =
        $interp->make_request(%defaults, %params,
                              parent_request => $self,
                              request_depth => $self->request_depth + 1);

    return $subreq;
}

sub is_subrequest
{
    my ($self) = @_;

    return $self->parent_request ? 1 : 0;
}

sub clear_and_abort
{
    my $self = shift;

    $self->clear_buffer;
    $self->abort(@_);
}

sub abort
{
    my ($self, $aborted_value) = @_;
    HTML::Mason::Exception::Abort->throw( error => 'Request->abort was called', aborted_value => $aborted_value );
}

#
# Determine whether $err (or $@ by default) is an Abort exception.
#
sub aborted {
    my ($self, $err) = @_;
    $err = $@ if !defined($err);
    return isa_mason_exception( $err, 'Abort' );
}

#
# Determine whether $err (or $@ by default) is an Decline exception.
#
sub declined {
    my ($self, $err) = @_;
    $err = $@ if !defined($err);
    return isa_mason_exception( $err, 'Decline' );
}

sub _aborted_or_declined {
    my ($self, $err) = @_;
    return $self->aborted($err) || $self->declined($err);
}

#
# Return a new cache object specific to this component.
#
sub cache
{
    my ($self, %options) = @_;

    # If using 1.0x cache API, save off options for end of routine.
    my %old_cache_options;
    if ($self->data_cache_api eq '1.0') {
        %old_cache_options = %options;
        %options = ();
    }

    # Combine defaults with options passed in here.
    if ($self->data_cache_defaults) {
        %options = (%{$self->data_cache_defaults}, %options);
    }

    # If using the CHI API, just create and return a CHI handle. Namespace will be escaped by CHI.
    if ($self->data_cache_api eq 'chi') {
        my $chi_root_class = delete($options{chi_root_class}) || 'CHI';
        load_pkg($chi_root_class);
        if (!exists($options{namespace})) {
            $options{namespace} = $self->current_comp->comp_id;
        }
        if (!exists($options{driver}) && !exists($options{driver_class})) {
            $options{driver} = $self->interp->cache_dir ? 'File' : 'Memory';
            $options{global} = 1 if $options{driver} eq 'Memory';            
        }
        $options{root_dir} ||= $self->interp->cache_dir;
        return $chi_root_class->new(%options);
    }

    $options{cache_root} ||= $self->interp->cache_dir;
    $options{namespace}  ||= compress_path($self->current_comp->comp_id);

    # Determine cache_class, adding 'Cache::' in front of user's
    # specification if necessary.
    my $cache_class = $self->interp->cache_dir ? 'Cache::FileCache' : 'Cache::MemoryCache';
    if ($options{cache_class}) {
        $cache_class = $options{cache_class};
        $cache_class = "Cache::$cache_class" unless $cache_class =~ /::/;
        delete($options{cache_class});
    }

    # Now prefix cache class with "HTML::Mason::". This will be a
    # dynamically constructed package that simply inherits from
    # HTML::Mason::Cache::BaseCache and the chosen cache class.
    my $mason_cache_class = "HTML::Mason::$cache_class";
    unless (pkg_loaded($mason_cache_class)) {
        load_pkg('Cache::Cache', '$m->cache requires the Cache::Cache module, available from CPAN.');
        load_pkg($cache_class, 'Fix your Cache::Cache installation or choose another cache class.');
        # need to break up mention of VERSION var or else CPAN/EU::MM can choke when running 'r'
        eval sprintf('package %s; use base qw(HTML::Mason::Cache::BaseCache %s); use vars qw($' . 'VERSION); $' . 'VERSION = 1.0;',
                     $mason_cache_class, $cache_class);
        error "Error constructing mason cache class $mason_cache_class: $@" if $@;
    }

    my $cache = $mason_cache_class->new (\%options)
        or error "could not create cache object";

    # Implement 1.0x cache API or just return cache object.
    if ($self->data_cache_api eq '1.0') {
        return $self->_cache_1_x($cache, %old_cache_options);
    } else {
        return $cache;
    }
}

#
# Implement 1.0x cache API in terms of Cache::Cache.
# Supported: action, busy_lock, expire_at, expire_if, expire_in, expire_next, key, value
# Silently not supported: keep_in_memory, tie_class
#
sub _cache_1_x
{
    my ($self, $cache, %options) = @_;

    my $action = $options{action} || 'retrieve';
    my $key = $options{key} || 'main';
    
    if ($action eq 'retrieve') {
        
        # Validate parameters.
        if (my @invalids = grep(!/^(expire_if|action|key|busy_lock|keep_in_memory|tie_class)$/, keys(%options))) {
            param_error "cache: invalid parameter '$invalids[0]' for action '$action'\n";
        }

        # Handle expire_if.
        if (my $sub = $options{expire_if}) {
            if (my $obj = $cache->get_object($key)) {
                if ($sub->($obj->get_created_at)) {
                    $cache->expire($key);
                }
            }
        }

        # Return the value or undef, handling busy_lock.
        if (my $result = $cache->get($key, ($options{busy_lock} ? (busy_lock=>$options{busy_lock}) : ()))) {
            return $result;
        } else {
            return undef;
        }

    } elsif ($action eq 'store') {

        # Validate parameters   
        if (my @invalids = grep(!/^(expire_(at|next|in)|action|key|value|keep_in_memory|tie_class)$/, keys(%options))) {
            param_error "cache: invalid parameter '$invalids[0]' for action '$action'\n";
        }
        param_error "cache: no store value provided" unless exists($options{value});

        # Determine $expires_in if expire flag given. For the "next"
        # options, we're jumping through hoops to find the *top* of
        # the next hour or day.
        #
        my $expires_in;
        my $time = time;
        if (exists($options{expire_at})) {
            param_error "cache: invalid expire_at value '$options{expire_at}' - must be a numeric time value\n" if $options{expire_at} !~ /^[0-9]+$/;
            $expires_in = $options{expire_at} - $time;
        } elsif (exists($options{expire_next})) {
            my $term = $options{expire_next};
            my ($sec, $min, $hour) = localtime($time);
            if ($term eq 'hour') {
                $expires_in = 60*(59-$min)+(60-$sec);
            } elsif ($term eq 'day') {
                $expires_in = 3600*(23-$hour)+60*(59-$min)+(60-$sec);
            } else {
                param_error "cache: invalid expire_next value '$term' - must be 'hour' or 'day'\n";
            }
        } elsif (exists($options{expire_in})) {
            $expires_in = $options{expire_in};
        }

        # Set and return the value.
        my $value = $options{value};
        $cache->set($key, $value, $expires_in);
        return $value;

    } elsif ($action eq 'expire') {
        my @keys = (ref($key) eq 'ARRAY') ? @$key : ($key);
        foreach my $key (@keys) {
            $cache->expire($key);
        }

    } elsif ($action eq 'keys') {
        return $cache->get_keys;
    }
}

sub cache_self {
    my ($self, %options) = @_;

    return if $self->{top_stack}->[STACK_IN_CALL_SELF]->{'CACHE_SELF'};

    my (%store_options, %retrieve_options);
    my ($expires_in, $key, $cache);
    if ($self->data_cache_api eq '1.0') {
        foreach (qw(key expire_if busy_lock)) {
            $retrieve_options{$_} = $options{$_} if (exists($options{$_}));
        }
        foreach (qw(key expire_at expire_next expire_in)) {
            $store_options{$_} = $options{$_} if (exists($options{$_}));
        }
    } else {
        #
        # key, expires_in/expire_in, expire_if and busy_lock go into
        # the set and get methods as appropriate. All other options
        # are passed into $self->cache.
        #
        foreach (qw(expire_if busy_lock)) {
            $retrieve_options{$_} = delete($options{$_}) if (exists($options{$_}));
        }
        $expires_in = delete $options{expires_in} || delete $options{expire_in} || 'never';
        $key = delete $options{key} || '__mason_cache_self__';
        $cache = $self->cache(%options);
    }

    my ($output, @retval, $error);

    my $cached =
        ( $self->data_cache_api eq '1.0' ?
          $self->cache(%retrieve_options) :
          $cache->get($key, %retrieve_options)
        );

    if ($cached) {
        ($output, my $retval) = @$cached;
        @retval = @$retval;
    } else {
        $self->call_self( \$output, \@retval, \$error, 'CACHE_SELF' );

        # If user aborted or declined, store in cache and print output
        # before repropagating.
        #
        rethrow_exception $error
            unless ($self->_aborted_or_declined($error));

        my $value = [$output, \@retval];
        if ($self->data_cache_api eq '1.0') {
            $self->cache(action=>'store', key=>$key, value=>$value, %store_options);
        } else {
            $cache->set($key, $value, $expires_in);
        }
    }

    #
    # Print the component output.
    #
    $self->print($output);

    #
    # Rethrow abort/decline exception if any.
    #
    rethrow_exception $error;

    #
    # Return the component return value in case the caller is interested,
    # followed by 1 indicating the cache retrieval success.
    #
    return (@retval, 1);
}

sub call_self
{
    my ($self, $output, $retval, $error, $tag) = @_;

    # Keep track of each individual invocation of call_self in the
    # component, via $tag.  $tag is 'CACHE_SELF' or 'FILTER' when used
    # by $m->cache_self and <%filter> sections respectively.
    #
    $tag ||= 'DEFAULT';
    my $top_stack = $self->{top_stack};
    $top_stack->[STACK_IN_CALL_SELF] ||= {};
    return if $top_stack->[STACK_IN_CALL_SELF]->{$tag};
    local $top_stack->[STACK_IN_CALL_SELF]->{$tag} = 1;

    # Determine wantarray based on retval reference
    my $wantarray =
        ( defined $retval ?
          ( UNIVERSAL::isa( $retval, 'ARRAY' ) ? 1 : 0 ) :
          undef
          );

    # If output or retval references were left undefined, just point
    # them to a dummy variable.
    #
    my $dummy;
    $output ||= \$dummy;
    $retval ||= \$dummy;

    # Temporarily put $output in place of the current top buffer.
    local $top_stack->[STACK_BUFFER] = $output;

    # Call the component again, capturing output, return value and
    # error. Don't catch errors unless the error reference was specified.
    #
    my $comp = $top_stack->[STACK_COMP];
    my $args = $top_stack->[STACK_ARGS];
    my @result;
    eval {
        if ($wantarray) {
            @$retval = $comp->run(@$args);
        } elsif (defined $wantarray) {
            $$retval = $comp->run(@$args);
        } else {
            $comp->run(@$args);
        }
    };
    if ($@) {
        if ($error) {
            $$error = $@;
        } else {
            die $@;
        }
    }

    # Return 1, indicating that this invocation of call_self is done.
    #
    return 1;
}

sub call_dynamic {
    my ($m, $key, @args) = @_;
    my $comp = ($m->current_comp->is_subcomp) ? $m->current_comp->owner : $m->current_comp;
    if (!defined($comp->dynamic_subs_request) or $comp->dynamic_subs_request ne $m) {
        $comp->dynamic_subs_init;
        $comp->dynamic_subs_request($m);
    }

    return $comp->run_dynamic_sub($key, @args);
}

sub call_next {
    my ($self,@extra_args) = @_;
    my $comp = $self->fetch_next
        or error "call_next: no next component to invoke";
    return $self->comp({base_comp=>$self->request_comp}, $comp, @{$self->current_args}, @extra_args);
}

sub caller
{
    my ($self) = @_;
    return $self->callers(1);
}

#
# Return a specified component from the stack, or the whole stack as a list.
#
sub callers
{
    my ($self, $levels_back) = @_;
    if (defined($levels_back)) {
        my $frame = $self->_stack_frame($levels_back);
        return unless defined $frame;
        return $frame->[STACK_COMP];
    } else {
        my $depth = $self->depth;
        return map($_->[STACK_COMP], $self->_stack_frames);
    }
}

#
# Return a specified argument list from the stack.
#
sub caller_args
{
    my ($self, $levels_back) = @_;
    param_error "caller_args expects stack level as argument" unless defined $levels_back;

    my $frame = $self->_stack_frame($levels_back);
    return unless $frame;
    my $args = $frame->[STACK_ARGS];
    return wantarray ? @$args : { @$args };
}

sub comp_exists
{
    my ($self, $path) = @_;

    # In order to support SELF, PARENT, REQUEST, subcomponents and
    # methods, it is easiest just to defer to fetch_comp.
    #
    return $self->fetch_comp($path) ? 1 : 0;
}

sub decline
{
    my ($self) = @_;

    $self->clear_buffer;
    my $subreq = $self->make_subrequest
        (comp => $self->{top_path},
         args => $self->{request_args},
         declined_comps => {$self->request_comp->comp_id, 1, %{$self->{declined_comps}}});
    my $retval = $subreq->exec;
    HTML::Mason::Exception::Decline->throw( error => 'Request->decline was called', declined_value => $retval );
}

#
# Return the current number of stack levels. 1 means top level, 0
# means that no component has been called yet.
#
sub depth
{
    return scalar @{ $_[0]->{stack} };
}

#
# Given a component path (absolute or relative), returns a component.
# Handles SELF, PARENT, REQUEST, comp:method, relative->absolute
# conversion, and local subcomponents.
#
# fetch_comp handles caching if use_internal_component_caches is on.
# _fetch_comp does the real work.
#
sub fetch_comp
{
    my ($self, $path, $current_comp, $error, $exists_only) = @_;

    return undef unless defined($path);
    $current_comp ||= $self->{top_stack}->[STACK_COMP];

    return $self->_fetch_comp($path, $current_comp, $error)
        unless $self->{use_internal_component_caches};

    my $fetch_comp_cache = $current_comp->{fetch_comp_cache};
    unless (defined($fetch_comp_cache->{$path})) {

        # Cache the component objects associated with
        # uncanonicalized paths like ../foo/bar.html.  SELF and
        # REQUEST are dynamic and cannot be cached. Weaken the
        # references in this cache so that we don't hang on to the
        # coponent if it disappears from the main code cache.
        #
        # See Interp::_initialize for the definition of
        # use_internal_component_caches and the conditions under
        # which we can create this cache safely.
        #
        if ($path =~ /^(?:SELF|REQUEST)/) {
            return $self->_fetch_comp($path, $current_comp, $error);
        } else {
            $fetch_comp_cache->{$path} =
                $self->_fetch_comp($path, $current_comp, $error);
            Scalar::Util::weaken($fetch_comp_cache->{$path}) if can_weaken;
        }
    }

    return $fetch_comp_cache->{$path};
}

sub _fetch_comp
{
    my ($self, $path, $current_comp, $error) = @_;

    #
    # Handle paths SELF, PARENT, and REQUEST
    #
    if ($path eq 'SELF') {
        return $self->base_comp;
    }
    if ($path eq 'PARENT') {
        my $c = $current_comp->parent;
        $$error = "PARENT designator used from component with no parent" if !$c && defined($error);
        return $c;
    }
    if ($path eq 'REQUEST') {
        return $self->request_comp;
    }

    #
    # Handle paths of the form comp_path:method_name
    #
    if (index($path,':') != -1) {
        my $method_comp;
        my ($owner_path,$method_name) = split(':',$path,2);
        if (my $owner_comp = $self->fetch_comp($owner_path, $current_comp, $error)) {
            if ($owner_comp->_locate_inherited('methods',$method_name,\$method_comp)) {
                return $method_comp;
            } else {
                $$error = "no such method '$method_name' for component " . $owner_comp->title if defined($error);
            }
        } else {
            $$error ||= "could not find component for path '$owner_path'\n" if defined($error);
        }

        return $method_comp;
    }

    #
    # If path does not contain a slash, check for a subcomponent in the
    # current component first.
    #
    if ($path !~ /\//) {
        # Check my subcomponents.
        if (my $subcomp = $current_comp->subcomps($path)) {
            return $subcomp;
        }
        # If I am a subcomponent, also check my owner's subcomponents.
        # This won't work when we go to multiply embedded subcomponents...
        if ($current_comp->is_subcomp and my $subcomp = $current_comp->owner->subcomps($path)) {
            return $subcomp;
        }
    }

    #
    # Otherwise pass the canonicalized absolute path to interp->load.
    #
    $path = absolute_comp_path($path, $current_comp->dir_path);
    my $comp = $self->interp->load($path);

    return $comp;
}

#
# Fetch the index of the next component in wrapper chain. If current
# component is not in chain, search the component stack for the most
# recent one that was.
#
sub _fetch_next_helper {
    my ($self) = @_;
    my $index = $self->{wrapper_index}->{$self->current_comp->comp_id};
    unless (defined($index)) {
        my @callers = $self->callers;
        shift(@callers);
        while (my $comp = shift(@callers) and !defined($index)) {
            $index = $self->{wrapper_index}->{$comp->comp_id};
        }
    }
    return $index;
}

#
# Fetch next component in wrapper chain.
#
sub fetch_next {
    my ($self) = @_;
    my $index = $self->_fetch_next_helper;
    error "fetch_next: cannot find next component in chain"
        unless defined($index);
    return $self->{wrapper_chain}->[$index+1];
}

#
# Fetch remaining components in wrapper chain.
#
sub fetch_next_all {
    my ($self) = @_;
    my $index = $self->_fetch_next_helper;
    error "fetch_next_all: cannot find next component in chain"
        unless defined($index);
    my @wc = @{$self->{wrapper_chain}};
    return @wc[($index+1)..$#wc];
}

sub file
{
    my ($self,$file) = @_;
    my $interp = $self->interp;
    unless ( File::Spec->file_name_is_absolute($file) ) {
        # use owner if current comp is a subcomp
        my $context_comp =
            ( $self->current_comp->is_subcomp ?
              $self->current_comp->owner :
              $self->current_comp );

        if ($context_comp->is_file_based) {
            my $source_dir = $context_comp->source_dir;
            $file = File::Spec->catfile( $source_dir, $file );
        } else {
            $file = File::Spec->catfile( File::Spec->rootdir, $file );
        }
    }
    my $content = read_file($file,1);
    return $content;
}

sub print
{
    my $self = shift;

    # $self->{top_stack} is always defined _except_ in the case of a
    # call to print inside a start-/end-request plugin.
    my $bufref =
        ( defined $self->{top_stack}
          ? $self->{top_stack}->[STACK_BUFFER]
          : \$self->{request_buffer}
        );

    # use 'if defined' for maximum efficiency; grep creates a list.
    for ( @_ ) {
        $$bufref .= $_ if defined;
    }

    $self->flush_buffer if $self->{autoflush};
}

*out = \&print;

#
# Execute the given component
#
sub comp {
    my $self = shift;
    my $log_is_debug = $log->is_debug;

    # Get modifiers: optional hash reference passed in as first argument.
    # Merge multiple hash references to simplify user and internal usage.
    #
    my %mods;
    %mods = (%{shift()}, %mods) while ref($_[0]) eq 'HASH';

    # Get component path or object. If a path, load into object.
    #
    my $path;
    my $comp = shift;
    if (!ref($comp)) {
        die "comp called without component - must pass a path or component object"
            unless defined($comp);
        $path = $comp;
        my $error;
        $comp = $self->fetch_comp($path, undef, \$error)
            or error($error || "could not find component for path '$path'\n");
    }

    # Increment depth and check for maximum recursion. Depth starts at 1.
    #
    my $depth = $self->depth;
    error "$depth levels deep in component stack (infinite recursive call?)\n"
        if $depth >= $self->{max_recurse};

    # Log start of component call.
    #
    $log->debugf("entering component '%s' [depth %d]", $comp->title(), $depth)
        if $log_is_debug;

    # Keep the same output buffer unless store modifier was passed. If we have
    # a filter, put the filter buffer on the stack instead of the regular buffer.
    #
    my $filter_buffer = '';
    my $top_buffer = defined($mods{store}) ? $mods{store} : $self->{top_stack}->[STACK_BUFFER];
    my $stack_buffer = $comp->{has_filter} ? \$filter_buffer : $top_buffer;
    my $flushable = exists $mods{flushable} ? $mods{flushable} : ($self->{top_stack}->[STACK_BUFFER_IS_FLUSHABLE] && ! defined($mods{store})) ;

    # Add new stack frame and point dynamically scoped $self->{top_stack} at it.
    push @{ $self->{stack} },
        [ $comp,           # STACK_COMP
          \@_,             # STACK_ARGS
          $stack_buffer,   # STACK_BUFFER
          \%mods,          # STACK_MODS
          $path,           # STACK_PATH
          undef,           # STACK_BASE_COMP
          undef,           # STACK_IN_CALL_SELF
          $flushable,      # STACK_BUFFER_IS_FLUSHABLE
        ];
    local $self->{top_stack} = $self->{stack}->[-1];

    # Run start_component hooks for each plugin.
    #
    if ($self->{has_plugins}) {
        my $context = bless
            [$self, $comp, \@_],
            'HTML::Mason::Plugin::Context::StartComponent';

        foreach my $plugin_instance (@{$self->{plugin_instances}}) {
            $plugin_instance->start_component_hook( $context );
        }
    }

    # Finally, call the component.
    #
    my $wantarray = wantarray;
    my @result;
    
    eval {
        # By putting an empty block here, we protect against stack
        # corruption when a component calls next or last outside of a
        # loop. See 05-request.t #28 for a test.
        {
            if ($wantarray) {
                @result = $comp->run(@_);
            } elsif (defined $wantarray) {
                $result[0] = $comp->run(@_);
            } else {
                $comp->run(@_);
            }
        }
    };
    my $error = $@;

    # Run component's filter if there is one, and restore true top buffer
    # (e.g. in case a plugin prints something).
    #
    if ($comp->{has_filter}) {
        # We have to check $comp->filter because abort or error may
        # occur before filter gets defined in component. In such cases
        # there should be no output, but should look into this more.
        #
        if (defined($comp->filter)) {
            $$top_buffer .= $comp->filter->($filter_buffer);
        }
        $self->{top_stack}->[STACK_BUFFER] = $top_buffer;
    }

    # Run end_component hooks for each plugin, in reverse order.
    #
    if ($self->{has_plugins}) {
        my $context = bless
            [$self, $comp, \@_, $wantarray, \@result, \$error],
            'HTML::Mason::Plugin::Context::EndComponent';
        
        foreach my $plugin_instance (@{$self->{plugin_instances_reverse}}) {
            $plugin_instance->end_component_hook( $context );
        }
    }

    # This is very important in order to avoid memory leaks, since we
    # stick the arguments on the stack. If we don't pop the stack,
    # they don't get cleaned up until the component exits.
    pop @{ $self->{stack} };

    # Log end of component call.
    #
    $log->debug(sprintf("exiting component '%s' [depth %d]", $comp->title(), $depth))
        if $log_is_debug;

    # Repropagate error if one occurred, otherwise return result.
    rethrow_exception $error if $error;
    return $wantarray ? @result : $result[0];
}

#
# Like comp, but return component output.
#
sub scomp {
    my $self = shift;
    my $buf;
    $self->comp({store => \$buf},@_);
    return $buf;
}

sub has_content {
    my $self = shift;
    return defined($self->{top_stack}->[STACK_MODS]->{content});
}

sub content {
    my $self = shift;
    my $content = $self->{top_stack}->[STACK_MODS]->{content};
    return undef unless defined($content);

    # Run the content routine with the previous stack frame active and
    # with output going to a new buffer.
    #
    my $err;
    my $buffer;
    my $save_frame = pop @{ $self->{stack} };
    {
        local $self->{top_stack} = $self->{stack}[-1];
        local $self->{top_stack}->[STACK_BUFFER] = \$buffer;
        local $self->{top_stack}->[STACK_BUFFER_IS_FLUSHABLE] = 0;
        local $self->{top_stack}->[STACK_HIDDEN_BUFFER] = $save_frame->[STACK_BUFFER];
        eval { $content->(); };
        $err = $@;
    }

    push @{ $self->{stack} }, $save_frame;

    rethrow_exception $err;

    # Return the output from the content routine.
    #
    return $buffer;
}

sub notes {
  my $self = shift;
  return $self->{notes} unless @_;
  
  my $key = shift;
  return $self->{notes}{$key} unless @_;
  
  return $self->{notes}{$key} = shift;
}

sub clear_buffer
{
    my $self = shift;

    foreach my $frame (@{$self->{stack}}) {
        my $bufref = $frame->[STACK_BUFFER];
        $$bufref = '';
        $bufref = $frame->[STACK_HIDDEN_BUFFER];
        $$bufref = '' if $bufref;
    }
}

sub flush_buffer
{
    my $self = shift;

    $self->out_method->($self->{request_buffer})
        if length $self->{request_buffer};
    $self->{request_buffer} = '';

    if ( $self->{top_stack}->[STACK_BUFFER_IS_FLUSHABLE]
         && $self->{top_stack}->[STACK_BUFFER] )
    {
        my $comp = $self->{top_stack}->[STACK_COMP];
        if ( $comp->has_filter()
             && defined $comp->filter() )
        {
            $self->out_method->
                ( $comp->filter->( ${ $self->{top_stack}->[STACK_BUFFER] } ) );
        }
        else
        {
            $self->out_method->( ${ $self->{top_stack}->[STACK_BUFFER] } );
        }
        ${$self->{top_stack}->[STACK_BUFFER]} = '';
    }
}

sub request_args
{
    my ($self) = @_;
    if (wantarray) {
        return @{$self->{request_args}};
    } else {
        return { @{$self->{request_args}} };
    }
}

# For backward compatibility:
*top_args = \&request_args;
*top_comp = \&request_comp;

#
# Subroutine called by every component while in debug mode, convenient
# for breakpointing.
#
sub debug_hook
{
    1;
}


#
# stack handling
#

# Return the stack frame $levels down from the top of the stack.
# If $levels is negative, count from the bottom of the stack.
# 
sub _stack_frame {
    my ($self, $levels) = @_;
    my $depth = $self->depth();
    my $index;
    if ($levels < 0) {
        $index = (-1 * $levels) - 1;
    } else {
        $index = $depth-1 - $levels;
    }
    return if $index < 0 or $index >= $depth;
    return $self->{stack}->[$index];
}

# Return all stack frames, in order from the top of the stack to the
# initial frame.
sub _stack_frames {
    my ($self) = @_;

    my $depth = $self->depth;
    return reverse map { $self->{stack}->[$_] } (0..$depth-1);
}

#
# Accessor methods for top of stack elements.
#
sub current_comp { return $_[0]->{top_stack}->[STACK_COMP] }
sub current_args { return $_[0]->{top_stack}->[STACK_ARGS] }

sub base_comp {
    my ($self) = @_;

    return unless $self->{top_stack};

    unless ( defined $self->{top_stack}->[STACK_BASE_COMP] ) {
        $self->_compute_base_comp_for_frame( $self->depth - 1 );
    }
    return $self->{top_stack}->[STACK_BASE_COMP];
}

#
# Determine the base_comp for a stack frame. See the user
# documentation for base_comp for a description of these rules.
#
sub _compute_base_comp_for_frame {
    my ($self, $frame_num) = @_;
    die "Invalid frame number: $frame_num" if $frame_num < 0;

    my $frame = $self->{stack}->[$frame_num];

    unless (defined($frame->[STACK_BASE_COMP])) {
        my $mods = $frame->[STACK_MODS];
        my $path = $frame->[STACK_PATH];
        my $comp = $frame->[STACK_COMP];
        
        my $base_comp;
        if (exists($mods->{base_comp})) {
            $base_comp = $mods->{base_comp};
        } elsif (!$path ||
                 $path =~ m/^(?:SELF|PARENT|REQUEST)(?:\:..*)?$/ ||
                 ($comp->is_subcomp && !$comp->is_method)) {
            $base_comp = $self->_compute_base_comp_for_frame($frame_num-1);
        } elsif ($path =~ m/(.*):/) {
            my $calling_comp = $self->{stack}->[$frame_num-1]->[STACK_COMP];
            $base_comp = $self->fetch_comp($1, $calling_comp);
        } else {
            $base_comp = $comp;
        }
        $frame->[STACK_BASE_COMP] = $base_comp;
    }
    return $frame->[STACK_BASE_COMP];
}

sub log
{
    my ($self) = @_;
    return $self->current_comp->logger();
}

package Tie::Handle::Mason;

sub TIEHANDLE
{
    my $class = shift;


    return bless {}, $class;
}

sub PRINT
{
    my $self = shift;

    my $old = select STDOUT;
    # Use direct $m access instead of Request->instance() to optimize common case
    $HTML::Mason::Commands::m->print(@_);

    select $old;
}

sub PRINTF
{
    my $self = shift;

    # apparently sprintf(@_) won't work, it needs to be a scalar
    # followed by a list
    $self->PRINT(sprintf(shift, @_));
}

1;

__END__

=head1 NAME

HTML::Mason::Request - Mason Request Class

=head1 SYNOPSIS

    $m->abort (...)
    $m->comp (...)
    etc.

=head1 DESCRIPTION

The Request API is your gateway to all Mason features not provided by
syntactic tags. Mason creates a new Request object for every web
request. Inside a component you access the current request object via
the global C<$m>.  Outside of a component, you can use the class
method C<instance>.

=head1 COMPONENT PATHS

The methods L<Request-E<gt>comp|HTML::Mason::Request/item_comp>,
L<Request-E<gt>comp_exists|HTML::Mason::Request/item_comp_exists>, and
L<Request-E<gt>fetch_comp|HTML::Mason::Request/item_fetch_comp> take a
component path argument.  Component paths are like URL paths, and
always use a forward slash (/) as the separator, regardless of what
your operating system uses.

=over

=item *

If the path is absolute (starting with a '/'), then the component is
found relative to the component root.

=item *

If the path is relative (no leading '/'), then the component is found
relative to the current component directory.

=item *

If the path matches both a subcomponent and file-based component, the
subcomponent takes precedence.

=back

=head1 PARAMETERS TO THE new() CONSTRUCTOR

=over 4

=item autoflush

True or false, default is false. Indicates whether to flush the output
buffer (C<$m-E<gt>flush_buffer>) after every string is output. Turn on
autoflush if you need to send partial output to the client, for
example in a progress meter.

As of Mason 1.3, autoflush will only work if L<enable_autoflush|HTML::Mason::Params/enable_autoflush> has
been set.  Components can be compiled more efficiently if they don't
have to check for autoflush. Before using autoflush you might consider
whether a few manual C<$m-E<gt>flush_buffer> calls would work nearly
as well.

=item data_cache_api

The C<$m-E<gt>cache> API to use:

=over

=item *

'1.1', the default, indicates a C<Cache::Cache> based API.

=item *

'chi' indicates a C<CHI> based API.

=item *

'1.0' indicates the custom cache API used in Mason 1.0x and
earlier. This compatibility layer is provided as a convenience for
users upgrading from older versions of Mason, but will not be
supported indefinitely.

=back

=item data_cache_defaults

A hash reference of default options to use for the C<$m-E<gt>cache>
command.  For example, to use Cache::Cache's C<MemoryCache>
implementation by default:

    data_cache_defaults => {cache_class => 'MemoryCache'}

To use the CHI C<FastMmap> driver by default:

    data_cache_api      => 'CHI',
    data_cache_defaults => {driver => 'FastMmap'},

These settings are overriden by options given to particular
C<$m-E<gt>cache> calls.

=item dhandler_name

File name used for L<dhandlers|HTML::Mason::Devel/dhandlers>. Default
is "dhandler".  If this is set to an empty string ("") then dhandlers
are turned off entirely.

=item error_format

Indicates how errors are formatted. The built-in choices are

=over

=item *

I<brief> - just the error message with no trace information

=item *

I<text> - a multi-line text format

=item *

I<line> - a single-line text format, with different pieces of
information separated by tabs (useful for log files)

=item *

I<html> - a fancy html format

=back

The default format under L<Apache|HTML::Mason::ApacheHandler> and
L<CGI|HTML::Mason::CGIHandler> is either I<line> or I<html> depending
on whether the error mode is I<fatal> or I<output>, respectively. The
default for standalone mode is I<text>.

The formats correspond to C<HTML::Mason::Exception> methods named
as_I<format>. You can define your own format by creating an
appropriately named method; for example, to define an "xml" format,
create a method C<HTML::Mason::Exception::as_xml> patterned after one of
the built-in methods.

=item error_mode

Indicates how errors are returned to the caller.  The choices are
I<fatal>, meaning die with the error, and I<output>, meaning output
the error just like regular output.

The default under L<Apache|HTML::Mason::ApacheHandler> and
L<CGI|HTML::Mason::CGIHandler> is I<output>, causing the error to be
displayed in the browser.  The default for standalone mode is
I<fatal>.

=item component_error_handler

A code reference used to handle errors thrown during component
compilation or runtime. By default, this is a subroutine that turns
non-exception object errors in components into exceptions. If this
parameter is set to a false value, these errors are simply rethrown
as-is.

Turning exceptions into objects can be expensive, since this will
cause the generation of a stack trace for each error. If you are using
strings or unblessed references as exceptions in your code, you may
want to turn this off as a performance boost.

=item max_recurse

The maximum recursion depth for the component stack, for the request
stack, and for the inheritance stack. An error is signalled if the
maximum is exceeded.  Default is 32.

=item out_method

Indicates where to send output. If out_method is a reference to a
scalar, output is appended to the scalar.  If out_method is a
reference to a subroutine, the subroutine is called with each output
string. For example, to send output to a file called "mason.out":

    my $fh = new IO::File ">mason.out";
    ...
    out_method => sub { $fh->print($_[0]) }

By default, out_method prints to standard output. Under
L<Apache|HTML::Mason::ApacheHandler>, standard output is
redirected to C<< $r->print >>.

=item plugins

An array of plugins that will be called at various stages of request
processing.  Please see L<HTML::Mason::Plugin|HTML::Mason::Plugin> for
details.

=back

=head1 ACCESSOR METHODS

All of the above properties have standard accessor methods of the same
name. In general, no arguments retrieves the value, and one argument
sets and returns the value.  For example:

    my $max_recurse_level = $m->max_recurse;
    $m->autoflush(1);

=head1 OTHER METHODS

=over

=item abort ([return value])

=for html <a name="item_abort"></a>

Ends the current request, finishing the page without returning
through components. The optional argument specifies the return
value from C<Interp::exec>; in a web environment, this ultimately
becomes the HTTP status code.

C<abort> is implemented by throwing an HTML::Mason::Exception::Abort
object and can thus be caught by eval(). The C<aborted> method is a
shortcut for determining whether a caught error was generated by
C<abort>.

If C<abort> is called from a component that has a C<< <%filter> >>,
than any output generated up to that point is filtered, I<unless>
C<abort> is called from a C<< <%shared> >> block.

=item clear_and_abort ([return value])

=for html <a name="item_clear_and_abort"></a>

This method is syntactic sugar for calling C<clear_buffer()> and then
C<abort()>.  If you are aborting the request because of an error, you
will often want to clear the buffer first so that any output generated
up to that point is not sent to the client.

=item aborted ([$err])

=for html <a name="item_aborted"></a>

Returns true or undef indicating whether the specified C<$err>
was generated by C<abort>. If no C<$err> was passed, uses C<$@>.

In this code, we catch and process fatal errors while letting C<abort>
exceptions pass through:

    eval { code_that_may_fail_or_abort() };
    if ($@) {
        die $@ if $m->aborted;

        # handle fatal errors...

C<$@> can lose its value quickly, so if you are planning to call
$m->aborted more than a few lines after the eval, you should save $@
to a temporary variable.

=item base_comp

=for html <a name="item_base_comp"></a>

Returns the current base component.

Here are the rules that determine base_comp as you move from
component to component.

=over

=item * At the beginning of a request, the base component is
initialized to the requested component (C<< $m->request_comp() >>).

=item * When you call a regular component via a path, the base
component changes to the called component.

=item * When you call a component method via a path (/foo/bar:baz),
the base component changes to the method's owner.

=item * The base component does not change when:

=over

=item * a component call is made to a component object

=item * a component call is made to SELF:x or PARENT:x or REQUEST:x

=item * a component call is made to a subcomponent (<%def>)

=back

=back

This may return nothing if the base component is not yet known, for
example inside a plugin's C<start_request_hook()> method, where we
have created a request but it does not yet know anything about the
component being called.

=item cache

=for html <a name="item_cache"></a>

C<$m-E<gt>cache> returns a new L<cache object|HTML::Mason::Cache::BaseCache> with a
namespace specific to this component. The parameters to and return value from
C<$m-E<gt>cache> differ depending on which L<data_cache_api> you are using.

=over

=item If data_cache_api = 1.1 (default)

I<cache_class> specifies the class of cache object to create. It
defaults to C<FileCache> in most cases, or C<MemoryCache> if the
interpreter has no data directory, and must be a backend subclass of
C<Cache::Cache>. The prefix "Cache::" need not be included.  See the
C<Cache::Cache> package for a full list of backend subclasses.
 
Beyond that, I<cache_options> may include any valid options to the new() method of the
cache class. e.g. for C<FileCache>, valid options include C<default_expires_in> and
C<cache_depth>.

See L<HTML::Mason::Cache::BaseCache|HTML::Mason::Cache::BaseCache> for
information about the object returend from C<$m-E<gt>cache>.

=item If data_cache_api = CHI

I<chi_root_class> specifies the factory class that will be called to
create cache objects. The default is 'CHI'.

I<driver> specifies the driver to use, for example C<Memory> or
C<FastMmap>.  The default is C<File> in most cases, or C<Memory> if
the interpreter has no data directory.

Beyond that, I<cache_options> may include any valid options to the
new() method of the driver. e.g. for the C<File> driver, valid options
include C<expires_in> and C<depth>.

=back

=item cache_self ([expires_in => '...'], [key => '...'], [get_options], [cache_options])

=for html <a name="item_cache_self"></a>

C<$m-E<gt>cache_self> caches the entire output and return result of a
component.

C<cache_self> either returns undef, or a list containing the
return value of the component followed by '1'. You should return
immediately upon getting the latter result, as this indicates
that you are inside the second invocation of the component.

C<cache_self> takes any of parameters to C<$m-E<gt>cache>
(e.g. I<cache_depth>), any of the optional parameters to
C<$cache-E<gt>get> (I<expire_if>, I<busy_lock>), and two additional
options:

=over

=item *

I<expire_in> or I<expires_in>: Indicates when the cache expires - it
is passed as the third argument to C<$cache-E<gt>set>. e.g. '10 sec',
'5 min', '2 hours'.

=item *

I<key>: An identifier used to uniquely identify the cache results - it
is passed as the first argument to C<$cache-E<gt>get> and
C<$cache-E<gt>set>.  The default key is '__mason_cache_self__'.

=back

To cache the component's output:

    <%init>
    return if $m->cache_self(expire_in => '10 sec'[, key => 'fookey']);
    ... <rest of init> ...
    </%init>

To cache the component's scalar return value:

    <%init>
    my ($result, $cached) = $m->cache_self(expire_in => '5 min'[, key => 'fookey']);

    return $result if $cached;
    ... <rest of init> ...
    </%init>

To cache the component's list return value:

    <%init>
    my (@retval) = $m->cache_self(expire_in => '3 hours'[, key => 'fookey']);

    return @retval if pop @retval;
    ... <rest of init> ...
    </%init>

We call C<pop> on C<@retval> to remove the mandatory '1' at the end of
the list.

If a component has a C<< <%filter> >> block, then the I<filtered>
output is cached.

Note: users upgrading from 1.0x and earlier can continue to use the
old C<$m-E<gt>cache_self> API by setting L<data_cache_api|HTML::Mason::Params/data_cache_api> to '1.0'.
This support will be removed at a later date.

See the the L<DATA CACHING|HTML::Mason::Devel/DATA CACHING> section of the developer's manual section for more details on how to
exercise finer control over caching.

=item caller_args

=for html <a name="item_caller_args"></a>

Returns the arguments passed by the component at the specified stack
level. Use a positive argument to count from the current component and
a negative argument to count from the component at the bottom of the
stack. e.g.

    $m->caller_args(0)   # arguments passed to current component
    $m->caller_args(1)   # arguments passed to component that called us
    $m->caller_args(-1)  # arguments passed to first component executed

When called in scalar context, a hash reference is returned.  When
called in list context, a list of arguments (which may be assigned to
a hash) is returned.  Returns undef or an empty list, depending on
context, if the specified stack level does not exist.

=item callers

=for html <a name="item_callers"></a>

With no arguments, returns the current component stack as a list of
component objects, starting with the current component and ending with
the top-level component. With one numeric argument, returns the
component object at that index in the list. Use a positive argument to
count from the current component and a negative argument to count from
the component at the bottom of the stack. e.g.

    my @comps = $m->callers   # all components
    $m->callers(0)            # current component
    $m->callers(1)            # component that called us
    $m->callers(-1)           # first component executed

Returns undef or an empty list, depending on context, if the specified
stack level does not exist.

=item caller

=for html <a name="item_caller"></a>

A synonym for C<< $m->callers(1) >>, i.e. the component that called the
currently executing component.

=item call_next ([args...])

=for html <a name="item_call_next"></a>

Calls the next component in the content wrapping chain; usually called
from an autohandler. With no arguments, the original arguments are
passed to the component.  Any arguments specified here serve to
augment and override (in case of conflict) the original
arguments. Works like C<$m-E<gt>comp> in terms of return value and
scalar/list context.  See the L<autohandlers|HTML::Mason::Devel/autohandlers> section of the developer's manual for examples.

=item call_self (output, return, error, tag)

This method allows a component to call itself so that it can filter
both its output and return values.  It is fairly advanced; for most
purposes the C<< <%filter> >> tag will be sufficient and simpler.

C<< $m->call_self >> takes four arguments, all of them optional.

=over

=item output - scalar reference that will be populated with the
component output.

=item return - scalar reference that will be populated with the
component return value.

=item error - scalar reference that will be populated with the error
thrown by the component, if any. If this parameter is not defined,
then call_self will not catch errors.

=item tag - a name for this call_self invocation; can almost always be omitted.

=back

C<< $m->call_self >> acts like a C<fork()> in the sense that it will
return twice with different values.  When it returns 0, you allow
control to pass through to the rest of your component.  When it
returns 1, that means the component has finished and you can
examine the output, return value and error. (Don't worry, it doesn't
really do a fork! See next section for explanation.)

The following examples would generally appear at the top of a C<<
<%init> >> section.  Here is a no-op C<< $m->call_self >> that leaves
the output and return value untouched:

    <%init>
    my ($output, $retval);
    if ($m->call_self(\$output, \$retval)) {
        $m->print($output);
        return $retval;
    }
    ...

Here is a simple output filter that makes the output all uppercase.
Note that we ignore both the original and the final return value.

    <%init>
    my ($output, $error);
    if ($m->call_self(\$output, undef)) {
        $m->print(uc $output);
        return;
    }
    ...

Here is a piece of code that traps all errors occuring anywhere in a
component or its children, e.g. for the purpose of handling
application-specific exceptions. This is difficult to do with a manual
C<eval> because it would have to span multiple code sections and the
main component body.

    <%init>
    my ($output, undef, $error);
    if ($m->call_self(\$output, undef, \$error)) {
        if ($error) {
            # check $error and do something with it
        }
        $m->print($output);
        return;
    }
    ...

=item clear_buffer

=for html <a name="item_clear_buffer"></a>

Clears the Mason output buffer. Any output sent before this line is
discarded. Useful for handling error conditions that can only be
detected in the middle of a request.

clear_buffer is, of course, thwarted by C<flush_buffer>.

=item comp (comp, args...)

=for html <a name="item_comp"></a>

Calls the component designated by I<comp> with the specified
option/value pairs. I<comp> may be a component path or a component
object.

Components work exactly like Perl subroutines in terms of return
values and context. A component can return any type of value, which is
then returned from the C<$m-E<gt>comp> call.

The <& &> tag provides a convenient shortcut for C<$m-E<gt>comp>.

As of 1.10, component calls can accept an initial hash reference of
I<modifiers>.  The only currently supported modifier is C<store>, which
stores the component's output in a scalar reference. For example:

  my $buf;
  my $return = $m->comp( { store => \$buf }, '/some/comp', type => 'big' );

This mostly duplicates the behavior of I<scomp>, but can be useful in
rare cases where you need to capture both a component's output and
return value.

This modifier can be used with the <& &> tag as well, for example:

  <& { store => \$buf }, '/some/comp', size => 'medium' &>

=item comp_exists (comp_path)

=for html <a name="item_comp_exists"></a>

Returns 1 if I<comp_path> is the path of an existing component, 0
otherwise.  I<comp_path> may be any path accepted by
L<comp|HTML::Mason::Request/item_comp> or
L<fetch_comp|HTML::Mason::Request/item_fetch_comp>, including method or
subcomponent paths.

Depending on implementation, <comp_exists> may try to load the
component referred to by the path, and may throw an error if the
component contains a syntax error.

=item content

=for html <a name="content"></a>

Evaluates the content (passed between <&| comp &> and </&> tags) of the 
current component, and returns the resulting text.

Returns undef if there is no content.

=item has_content

=for html <a name="has_content"></a>

Returns true if the component was called with content (i.e. with <&|
comp &> and </&> tags instead of a single <& comp &> tag). This is
generally better than checking the defined'ness of C<< $m->content >>
because it will not try to evaluate the content.

=item count

=for html <a name="item_count"></a>

Returns the number of this request, which is unique for a given
request and interpreter.

=item current_args

=for html <a name="item_current_args"></a>

Returns the arguments passed to the current component. When called in
scalar context, a hash reference is returned.  When called in list
context, a list of arguments (which may be assigned to a hash) is
returned.

=item current_comp

=for html <a name="item_current_comp"></a>

Returns the current component object.

=item decline

=for html <a name="item_decline"></a>

Used from a top-level component or dhandler, this method clears the
output buffer, aborts the current request and restarts with the next
applicable dhandler up the tree. If no dhandler is available, a
not-found error occurs.

This method bears no relation to the Apache DECLINED status except in
name.

=item declined ([$err])

=for html <a name="item_declined"></a>

Returns true or undef indicating whether the specified C<$err> was
generated by C<decline>. If no C<$err> was passed, uses C<$@>.

=item depth

=for html <a name="item_depth"></a>

Returns the current size of the component stack.  The lowest possible
value is 1, which indicates we are in the top-level component.

=item dhandler_arg

=for html <a name="item_dhandler_arg"></a>

If the request has been handled by a dhandler, this method returns the
remainder of the URI or C<Interp::exec> path when the dhandler directory is
removed. Otherwise returns undef.

C<dhandler_arg> may be called from any component in the request, not just
the dhandler.

=item exec (comp, args...)

=for html <a name="item_exec"></a>

Starts the request by executing the top-level component and
arguments. This is normally called for you on the main request, but
you can use it to execute subrequests.

A request can only be executed once; e.g. it is an error to call this
recursively on the same request.

=item fetch_comp (comp_path)

=for html <a name="item_fetch_comp"></a>

Given a I<comp_path>, returns the corresponding component object or
undef if no such component exists.

=item fetch_next

=for html <a name="item_fetch_next"></a>

Returns the next component in the content wrapping chain, or undef if
there is no next component. Usually called from an autohandler.  See
the L<autohandlers|HTML::Mason::Devel/autohandlers> section of the developer's manual for usage and examples.

=item fetch_next_all

=for html <a name="item_fetch_next_all"></a>

Returns a list of the remaining components in the content wrapping
chain. Usually called from an autohandler.  See the L<autohandlers|HTML::Mason::Devel/autohandlers> section of the developer's manual
for usage and examples.

=item file (filename)

=for html <a name="item_file"></a>

Returns the contents of I<filename> as a string. If I<filename> is a
relative path, Mason prepends the current component directory.

=item flush_buffer

=for html <a name="item_flush_buffer"></a>

Flushes the Mason output buffer. Under mod_perl, also sends HTTP
headers if they haven't been sent and calls C<< $r->rflush >> to flush
the Apache buffer. Flushing the initial bytes of output can make your
servers appear more responsive.

Attempts to flush the buffers are ignored within the context of a call
to C<< $m->scomp >> or when output is being stored in a scalar
reference, as with the C< { store =E<gt> \$out } > component call
modifier.

C<< <%filter> >> blocks will process the output whenever the buffers
are flushed.  If C<autoflush> is on, your data may be filtered in 
small pieces.

=item instance

=for html <a name="item_instance"></a>

This class method returns the C<HTML::Mason::Request> currently in
use.  If called when no Mason request is active it will return
C<undef>.

If called inside a subrequest, it returns the subrequest object.

=item interp

=for html <a name="item_interp"></a>

Returns the Interp object associated with this request.

=item make_subrequest (comp => path, args => arrayref, other parameters)

=for html <a name="item_make_subrequest"></a>

This method creates a new Request object which inherits its parent's
settable properties, such as L<autoflush|HTML::Mason::Params/autoflush> and L<out_method|HTML::Mason::Params/out_method>.  These
values may be overridden by passing parameters to this method.

The C<comp> parameter is required, while all other parameters are
optional.  It may be specified as an absolute path or as a path
relative to the current component.

See the L<subrequests|HTML::Mason::Devel/subrequests> section of the developer's manual for more information about subrequests.

=item log

=for html <a name="item_log"></a>

Returns a C<Log::Any> logger with a log category specific to the
current component.  The category for a component "/foo/bar" would be
"HTML::Mason::Component::foo::bar".

=item notes (key, value)

=for html <a name="notes"></a>

The C<notes()> method provides a place to store application data,
giving developers a way to share data among multiple components.  Any
data stored here persists for the duration of the request, i.e. the
same lifetime as the Request object.

Conceptually, C<notes()> contains a hash of key-value pairs.
C<notes($key, $value)> stores a new entry in this hash.
C<notes($key)> returns a previously stored value.  C<notes()> without
any arguments returns a reference to the entire hash of key-value
pairs.

C<notes()> is similar to the mod_perl method C<< $r->pnotes() >>.  The
main differences are that this C<notes()> can be used in a
non-mod_perl environment, and that its lifetime is tied to the
I<Mason> request object, not the I<Apache> request object.  In
particular, a Mason subrequest has its own C<notes()> structure, but
would access the same C<< $r->pnotes() >> structure.

=item out (string)

=for html <a name="item_out"></a>

A synonym for C<$m-E<gt>print>.

=item print (string)

=for html <a name="item_print"></a>

Print the given I<string>. Rarely needed, since normally all text is just
placed in the component body and output implicitly. C<$m-E<gt>print> is useful
if you need to output something in the middle of a Perl block.

In 1.1 and on, C<print> and C<$r-E<gt>print> are remapped to C<$m-E<gt>print>,
so they may be used interchangeably. Before 1.1, one should only use
C<$m-E<gt>print>.

=item request_args

=for html <a name="item_request_args"></a>

Returns the arguments originally passed to the top level component
(see L<request_comp|HTML::Mason::Request/item_request_comp> for
definition).  When called in scalar context, a hash reference is
returned. When called in list context, a list of arguments (which may
be assigned to a hash) is returned.

=item request_comp

=for html <a name="item_request_comp"></a>

Returns the component originally called in the request. Without
autohandlers, this is the same as the first component executed.  With
autohandlers, this is the component at the end of the
C<$m-E<gt>call_next> chain.

=item request_depth

=for html <a name="request_depth"></a>

Returns the current size of the request/subrequest stack.  The lowest
possible value is 1, which indicates we are in the top-level request.
A value of 2 indicates we are inside a subrequest of the top-level request,
and so on.

=item scomp (comp, args...)

=for html <a name="item_scomp"></a>

Like L<comp|HTML::Mason::Request/item_comp>, but returns the component output as a string
instead of printing it. (Think sprintf versus printf.) The
component's return value is discarded.

=item subexec (comp, args...)

=for html <a name="item_subexec"></a>

This method creates a new subrequest with the specified top-level
component and arguments, and executes it. This is most often used
to perform an "internal redirect" to a new component such that
autohandlers and dhandlers take effect.

=item time

=for html <a name="item_time"></a>

Returns the interpreter's notion of the current time (deprecated).

=back

=head1 APACHE-ONLY METHODS

These additional methods are available when running Mason with mod_perl
and the ApacheHandler.

=over

=item ah

=for html <a name="item_ah"></a>

Returns the ApacheHandler object associated with this request.

=item apache_req

=for html <a name="item_apache_req"></a>

Returns the Apache request object.  This is also available in the
global C<$r>.

=item auto_send_headers

=for html <a name="item_auto_send_headers"></a>

True or false, default is true.  Indicates whether Mason should
automatically send HTTP headers before sending content back to the
client. If you set to false, you should call C<$r-E<gt>send_http_header>
manually.

See the L<sending HTTP headers|HTML::Mason::Devel/sending HTTP headers> section of the developer's manual for more details about the automatic
header feature.

NOTE: This parameter has no effect under mod_perl-2, since calling
C<$r-E<gt>send_http_header> is no longer needed.

=back

=head1 CGI-ONLY METHODS

This additional method is available when running Mason with the
CGIHandler module.

=over

=item cgi_request

=for html <a name="item_cgi_request"></a>

Returns the Apache request emulation object, which is available as
C<$r> inside components.

See the L<CGIHandler docs|HTML::Mason::CGIHandler/"$r Methods"> for
more details.

=back

=head1 APACHE- OR CGI-ONLY METHODS

This method is available when Mason is running under either the
ApacheHandler or CGIHandler modules.

=over 4

=item cgi_object

=for html <a name="item_cgi_object"></a>

Returns the CGI object used to parse any CGI parameters submitted to
the component, assuming that you have not changed the default value of
the ApacheHandler L<args_method|HTML::Mason::Params/args_method> parameter.  If you are using the
'mod_perl' args method, then calling this method is a fatal error.
See the L<ApacheHandler|HTML::Mason::ApacheHandler> and
L<CGIHandler|HTML::Mason::CGIHandler> documentation for more details.

=item redirect ($url, [$status])

=for html <a name="item_redirect_url_status_"></a>

Given a url, this generates a proper HTTP redirect for that URL. It
uses C<< $m->clear_and_abort >> to clear out any previous output, and
abort the request.  By default, the status code used is 302, but this
can be overridden by the user.

Since this is implemented using C<< $m->abort >>, it will be trapped
by an C< eval {} > block.  If you are using an C< eval {} > block in
your code to trap errors, you need to make sure to rethrow these
exceptions, like this:

  eval {
      ...
  };

  die $@ if $m->aborted;

  # handle other exceptions

=back

=head1 AUTHORS

Jonathan Swartz <swartz@pobox.com>, Dave Rolsky <autarch@urth.org>, Ken Williams <ken@mathforum.org>

=head1 SEE ALSO

L<HTML::Mason|HTML::Mason>,
L<HTML::Mason::Devel|HTML::Mason::Devel>,
L<HTML::Mason::Component|HTML::Mason::Component>

=cut
