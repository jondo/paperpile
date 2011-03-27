# -*- cperl-indent-level: 4; cperl-continued-brace-offset: -4; cperl-continued-statement-offset: 4 -*-

# Copyright (c) 1998-2005 by Jonathan Swartz. All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

package HTML::Mason::Interp;

use strict;
use warnings;

use File::Basename;
use File::Path;
use File::Spec;
use File::Temp;
use HTML::Mason;
use HTML::Mason::Escapes;
use HTML::Mason::Request;
use HTML::Mason::Resolver::File;
use HTML::Mason::Tools qw(read_file taint_is_on load_pkg);

use HTML::Mason::Exceptions( abbr => [qw(param_error system_error wrong_compiler_error compilation_error error)] );

use Params::Validate qw(:all);
Params::Validate::validation_options( on_fail => sub { param_error join '', @_  } );

use Class::Container;
use base qw(Class::Container);

BEGIN
{
    # Fields that can be set in new method, with defaults
    __PACKAGE__->valid_params
        (
         autohandler_name =>
         { parse => 'string',  default => 'autohandler', type => SCALAR,
           descr => "The filename to use for Mason's 'autohandler' capability" },

         buffer_preallocate_size =>
         { parse => 'string', default => 0, type => SCALAR,
           descr => "Number of bytes to preallocate in request buffer" },
         
         code_cache_max_size =>
         { parse => 'string',  default => 'unlimited', type => SCALAR,
           descr => "The maximum number of components in the code cache" },

         comp_root =>
         { parse => 'list',
           type => SCALAR|ARRAYREF,
           default => File::Spec->rel2abs( Cwd::cwd ),
           descr => "A string or array of arrays indicating the search path for component calls" },

         compiler =>
         { isa => 'HTML::Mason::Compiler',
           descr => "A Compiler object for compiling components" },

         data_dir =>
         { parse => 'string', optional => 1, type => SCALAR,
           descr => "A directory for storing cache files and other state information" },

         dynamic_comp_root =>
         { parse => 'boolean', default => 0, type => BOOLEAN,
           descr => "Indicates whether the comp_root may be changed between requests" },

         escape_flags =>
         { parse => 'hash_list', optional => 1, type => HASHREF,
           descr => "A list of escape flags to set (as if calling the set_escape() method" },

         object_file_extension =>
         { parse => 'string',  type => SCALAR, default => '.obj',
           descr => "Extension to add to the end of object files" },

         # OBJECT cause qr// returns an object
         ignore_warnings_expr =>
         { parse => 'string',  type => SCALAR|OBJECT, default => qr/Subroutine .* redefined/i,
           descr => "A regular expression describing Perl warning messages to ignore" },

         preloads =>
         { parse => 'list', optional => 1, type => ARRAYREF,
           descr => "A list of components to load immediately when creating the Interpreter" },

         resolver =>
         { isa => 'HTML::Mason::Resolver',
           descr => "A Resolver object for fetching components from storage" },

         static_source =>
         { parse => 'boolean', default => 0, type => BOOLEAN,
           descr => "When true, we only compile source files once" },

         static_source_touch_file =>
         { parse => 'string', optional => 1, type => SCALAR, 
           descr => "A file that, when touched, causes Mason to clear its component caches" },

         use_object_files =>
         { parse => 'boolean', default => 1, type => BOOLEAN,
           descr => "Whether to cache component objects on disk" },
        );

    __PACKAGE__->contained_objects
        (
         resolver => { class => 'HTML::Mason::Resolver::File',
                       descr => "This class is expected to return component information based on a component path" },
         compiler => { class => 'HTML::Mason::Compiler::ToObject',
                       descr => "This class is used to translate component source into code" },
         request  => { class => 'HTML::Mason::Request',
                       delayed => 1,
                       descr => "Objects returned by make_request are members of this class" },
        );
}

use HTML::Mason::MethodMaker
    ( read_only => [ qw( autohandler_name
                         buffer_preallocate_size
                         code_cache
                         code_cache_min_size
                         code_cache_max_size
                         compiler
                         data_dir
                         dynamic_comp_root
                         object_file_extension
                         preallocated_output_buffer
                         preloads
                         resolver
                         source_cache
                         static_source
                         static_source_touch_file
                         use_internal_component_caches
                         use_object_files
                        ) ],

      read_write => [ map { [ $_ => __PACKAGE__->validation_spec->{$_} ] }
                      qw( ignore_warnings_expr
                         )
                    ],

      read_write_contained => { request =>
                                [ [ autoflush => { type => BOOLEAN } ],
                                  [ data_cache_api => { type => SCALAR } ],
                                  [ data_cache_defaults => { type => HASHREF } ],
                                  [ dhandler_name => { type => SCALAR } ],
                                  [ error_format => { type => SCALAR } ],
                                  [ error_mode => { type => SCALAR } ],
                                  [ max_recurse => { type => SCALAR } ],
                                  [ out_method => { type => SCALARREF | CODEREF } ],
                                  [ plugins => { type => ARRAYREF } ],
                                ]
                              },
      );

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->_initialize;
    return $self;
}

sub _initialize
{
    my ($self) = shift;
    $self->{code_cache} = {};
    $self->{source_cache} = {};
    $self->{files_written} = [];
    $self->{static_source_touch_file_lastmod} = 0;

    $self->_assign_comp_root($self->{comp_root});
    $self->_check_data_dir();
    $self->_create_data_subdirs();
    $self->_initialize_escapes();

    #
    # Create preallocated buffer for requests.
    #
    $self->{preallocated_output_buffer} = ' ' x $self->buffer_preallocate_size;

    $self->_set_code_cache_attributes();

    #
    # If static_source=1, unlimited_code_cache=1, and
    # dynamic_comp_root=0, we can safely cache component objects keyed
    # on path throughout the framework (e.g. within other component
    # objects). These internal caches can be cleared in
    # $interp->flush_code_cache (the only legimiate place for a
    # component to be eliminated from the cache), eliminating any
    # chance for leaked objects.
    #
    # static_source has to be on or else we might keep around
    # old versions of components that have changed.
    #
    # unlimited_code_cache has to be on or else we might leak
    # components when we discard.
    #
    # dynamic_comp_root has to be 0 because the cache would not be
    # valid for different combinations of component root across
    # different requests.
    #
    $self->{use_internal_component_caches} =
        ($self->{static_source} &&
         $self->{unlimited_code_cache} &&
         !$self->{dynamic_comp_root});

    $self->_preload_components();
}

sub _check_data_dir
{
    my $self = shift;

    return unless $self->{data_dir};

    $self->{data_dir} = File::Spec->canonpath( $self->{data_dir} );
    param_error "data_dir '$self->{data_dir}' must be an absolute directory"
        unless File::Spec->file_name_is_absolute( $self->{data_dir} );
}

sub _create_data_subdirs
{
    my $self = shift;

    if ($self->data_dir) {
        $self->_make_object_dir;
        $self->_make_cache_dir;
    } else {
        $self->{use_object_files} = 0;
    }
}

sub _initialize_escapes
{
    my $self = shift;

    #
    # Add the escape flags (including defaults)
    #
    foreach ( [ h => \&HTML::Mason::Escapes::html_entities_escape ],
              [ u => \&HTML::Mason::Escapes::url_escape ],
            )
    {
        $self->set_escape(@$_);
    }

    if ( my $e = delete $self->{escape_flags} )
    {
        while ( my ($flag, $code) = each %$e )
        {
            $self->set_escape( $flag => $code );
        }
    }
}

sub _set_code_cache_attributes
{
    my $self = shift;

    $self->{unlimited_code_cache} = ($self->{code_cache_max_size} eq 'unlimited');
    unless ($self->{unlimited_code_cache}) {
        $self->{code_cache_min_size} = $self->{code_cache_max_size} * 0.75;
    }
}

sub _preload_components
{
    my $self = shift;

    return unless $self->preloads;

    foreach my $pattern (@{$self->preloads}) {
        error "preload pattern '$pattern' must be an absolute path"
            unless File::Spec->file_name_is_absolute($pattern);
        my %path_hash;
        foreach my $pair ($self->comp_root_array) {
            my $root = $pair->[1];
            foreach my $path ($self->resolver->glob_path($pattern, $root)) {
                $path_hash{$path}++;
            }
        }
        my @paths = keys(%path_hash);
        warn "Didn't find any components for preload pattern '$pattern'"
            unless @paths;
        foreach (@paths)
        {
            $self->load($_)
                or error "Cannot load component $_, found via pattern $pattern";
        }
    }
}

#
# Functions for retrieving and creating data subdirectories.
#
sub object_dir { my $self = shift; return $self->data_dir ? File::Spec->catdir( $self->data_dir, 'obj' ) : ''; }
sub object_create_marker_file { my $self = shift; return $self->object_dir ? File::Spec->catfile($self->object_dir, '.__obj_create_marker') : ''; }
sub cache_dir  { my $self = shift; return $self->data_dir ? File::Spec->catdir( $self->data_dir, 'cache' ) : ''; }

sub _make_data_subdir
{
    my ($self, $dir) = @_;

    unless (-d $dir) {
        my @newdirs = eval { mkpath( $dir, 0, 0775 ) };
        if ($@) {
            my $user  = getpwuid($<);
            my $group = getgrgid($();
            my $data_dir = $self->data_dir;
            error "Cannot create directory '$dir' ($@) for user '$user', group '$group'. " .
                "Perhaps you need to create or set permissions on your data_dir ('$data_dir'). ";
        }
        $self->push_files_written(@newdirs);
    }
}

sub _make_object_dir
{
    my ($self) = @_;

    my $object_dir = $self->object_dir;
    $self->_make_data_subdir($object_dir);
    my $object_create_marker_file = $self->object_create_marker_file;
    unless (-f $object_create_marker_file) {
        open my $fh, ">$object_create_marker_file"
            or system_error "Could not create '$object_create_marker_file': $!";
        $self->push_files_written($object_create_marker_file);
    }
}

sub _make_cache_dir
{
    my ($self) = @_;

    my $cache_dir = $self->cache_dir;
    $self->_make_data_subdir($cache_dir);
}

#
# exec is the initial entry point for executing a component
# in a new request.
#
sub exec {
    my $self = shift;
    my $comp = shift;
    $self->make_request(comp=>$comp, args=>\@_)->exec;
}

sub make_request {
    my $self = shift;

    return $self->create_delayed_object( 'request', interp => $self, @_ );
}

sub comp_exists {
    my ($self, $path) = @_;
    return $self->resolve_comp_path_to_source($path);
}

#
# Load <$path> into a component, possibly parsing the source and/or
# caching the code. Returns a component object or undef if the
# component was not found.
#
sub load {
    my ($self, $path) = @_;
    my ($maxfilemod, $objfile, $objfilemod);
    my $code_cache = $self->{code_cache};
    my $resolver = $self->{resolver};

    #
    # Path must be absolute.
    #
    unless (substr($path, 0, 1) eq '/') {
        error "Component path given to Interp->load must be absolute (was given $path)";
    }

    #
    # Get source info from resolver.
    #
    my $source = $self->resolve_comp_path_to_source($path);

    # No component matches this path.
    return unless defined $source;

    # comp_id is the unique name for the component, used for cache key
    # and object file name.
    my $comp_id = $source->comp_id;

    #
    # Get last modified time of source.
    #
    my $srcmod = $source->last_modified;

    #
    # If code cache contains an up to date entry for this path, use
    # the cached comp.  Always use the cached comp in static_source
    # mode.
    #
    if ( exists $code_cache->{$comp_id} &&
         ( $self->static_source || $code_cache->{$comp_id}->{lastmod} >= $srcmod )
       ) {
        return $code_cache->{$comp_id}->{comp};
    }

    if ($self->{use_object_files}) {
        $objfile = $self->comp_id_to_objfile($comp_id);

        my @stat = stat $objfile;
        if ( @stat && ! -f _ ) {
            error "The object file '$objfile' exists but it is not a file!";
        }

        if ($self->static_source) {
            # No entry in the code cache so if the object file exists,
            # we will use it, otherwise we must create it.  These
            # values make that happen.
            $objfilemod = @stat ? $srcmod : 0;
        } else {
            # If the object file exists, get its modification time.
            # Otherwise (it doesn't exist or it is a directory) we
            # must create it.
            $objfilemod = @stat ? $stat[9] : 0;
        }
    }

    my $comp;
    if ($objfile) {
        #
        # We are using object files.  Update object file if necessary
        # and load component from there.
        #
        # If loading the object file generates an error, or results in
        # a non-component object, try regenerating the object file
        # once before giving up and reporting an error. This can be
        # handy in the rare case of an empty or corrupted object file.
        # (But add an exception for "Compilation failed in require" errors, since
        # the bad module will be added to %INC and the error will not occur
        # the second time - RT #39803).
        #
        if ($objfilemod < $srcmod) {
            $self->compiler->compile_to_file( file => $objfile, source => $source);
        }
        $comp = eval { $self->eval_object_code( object_file => $objfile ) };

        if (!UNIVERSAL::isa($comp, 'HTML::Mason::Component')) {
            if (!defined($@) || $@ !~ /failed in require/) {
                $self->compiler->compile_to_file( file => $objfile, source => $source);
                $comp = eval { $self->eval_object_code( object_file => $objfile ) };
            }

            if (!UNIVERSAL::isa($comp, 'HTML::Mason::Component')) {
                my $error = $@ ? $@ : "Could not get HTML::Mason::Component object from object file '$objfile'";
                $self->_compilation_error( $source->friendly_name, $error );
            }
        }
    } else {
        #
        # Not using object files. Load component directly into memory.
        #
        my $object_code = $source->object_code( compiler => $self->compiler );
        $comp = eval { $self->eval_object_code( object_code => $object_code ) };
        $self->_compilation_error( $source->friendly_name, $@ ) if $@;
    }
    $comp->assign_runtime_properties($self, $source);

    #
    # Delete any stale cached version of this component, then
    # cache it.
    #
    $self->delete_from_code_cache($comp_id);
    $code_cache->{$comp_id} = { lastmod => $srcmod, comp => $comp };

    return $comp;
}

sub delete_from_code_cache {
    my ($self, $comp_id) = @_;
    return unless defined $self->{code_cache}{$comp_id}{comp};

    delete $self->{code_cache}{$comp_id};
    return;
}

sub comp_id_to_objfile {
    my ($self, $comp_id) = @_;

    return File::Spec->catfile
               ( $self->object_dir,
                 $self->compiler->object_id,
                 ( split /\//, $comp_id ),
               ) . $self->object_file_extension;
}

#
# Empty in-memory code cache.
#
sub flush_code_cache {
    my $self = shift;

    # Necessary for preventing memory leaks
    if ($self->use_internal_component_caches) {
        foreach my $entry (values %{$self->{code_cache}}) {
            my $comp = $entry->{comp};
            $comp->flush_internal_caches;
        }
    }
    $self->{code_cache} = {};
    $self->{source_cache} = {};
}

#
# If code cache has exceeded maximum, remove least frequently used
# elements from cache until size falls below minimum.
#
sub purge_code_cache {
    my ($self) = @_;

    return if $self->{unlimited_code_cache};
    my $current_size = scalar(keys(%{$self->{code_cache}}));
    if ($current_size > $self->code_cache_max_size) {
        my $code_cache = $self->{code_cache};
        my $min_size = $self->code_cache_min_size;
        my $decay_factor = 0.75;

        my @elems;
        while (my ($path,$href) = each(%{$code_cache})) {
            push(@elems,[$path,$href->{comp}->mfu_count,$href->{comp}]);
        }
        @elems = sort { $a->[1] <=> $b->[1] } @elems;
        while (($current_size > $min_size) and @elems) {
            $self->delete_from_code_cache(shift(@elems)->[0]);
            $current_size--;
        }

        #
        # Multiply each remaining cache item's count by a decay factor,
        # to gradually reduce impact of old information.
        #
        foreach my $elem (@elems) {
            $elem->[2]->mfu_count( $elem->[2]->mfu_count * $decay_factor );
        }
    }
}

#
# Clear the object directory of all current files and subdirectories.
# Do this by renaming the object directory to a temporary name,
# immediately recreating an empty object directory, then removing
# the empty object directory. If another process tries to write
# the object file in between these steps, it'll create the top
# object directory instead.
#
# Would be nice to fork off a separate process to do the removing so
# that it doesn't affect a request's response time, but difficult to
# do this in an environment-generic way.
#
sub remove_object_files
{
    my $self = shift;

    my $object_dir = $self->object_dir;
    if (-d $object_dir) {
        my $temp_dir = File::Temp::tempdir(DIR => $self->data_dir);
        rename($object_dir, File::Spec->catdir( $temp_dir, 'target' ) )
            or die "could not rename '$object_dir' to '$temp_dir': $@";
        $self->_make_object_dir();
        rmtree($temp_dir);
    } else {
        $self->_make_object_dir();
    }
}

#
# Check the static_source_touch_file, if one exists, to see if it has
# changed since we last checked. If it has, clear the code cache and
# object files if appropriate.
#
sub check_static_source_touch_file
{
    my $self = shift;

    if (my $touch_file = $self->static_source_touch_file) {
        return unless -f $touch_file;
        my $touch_file_lastmod = (stat($touch_file))[9];
        if ($touch_file_lastmod > $self->{static_source_touch_file_lastmod}) {

            # File has been touched since we last checked.  First,
            # clear the object file directory if the last mod of
            # its ._object_create_marker is earlier than the touch file,
            # or if the marker doesn't exist.
            #
            if ($self->use_object_files) {
                my $object_create_marker_file = $self->object_create_marker_file;
                if (!-e $object_create_marker_file ||
                    (stat($object_create_marker_file))[9] < $touch_file_lastmod) {
                    $self->remove_object_files;
                }
            }

            # Next, clear the in-memory component cache.
            #
            $self->flush_code_cache;

            # Reset lastmod value.
            #
            $self->{static_source_touch_file_lastmod} = $touch_file_lastmod;
        }
    }
}

#
# Construct a component on the fly.  Virtual if 'path' parameter is
# given, otherwise anonymous.
#
sub make_component {
    my $self = shift;

    my %p = validate(@_, { comp_source => { type => SCALAR, optional => 1 },
                           comp_file   => { type => SCALAR, optional => 1 },
                           name        => { type => SCALAR, optional => 1 } });

    $p{comp_source} = read_file(delete $p{comp_file}) if exists $p{comp_file};
    param_error "Must specify either 'comp_source' or 'comp_file' parameter to 'make_component()'"
        unless defined $p{comp_source};

    $p{name} ||= '<anonymous component>';

    my $source = HTML::Mason::ComponentSource->new( friendly_name => $p{name},
                                                    comp_path => $p{name},
                                                    comp_id => undef,
                                                    last_modified => time,
                                                    comp_class => 'HTML::Mason::Component',
                                                    source_callback => sub { $p{comp_source} },
                                                  );

    my $object_code = $source->object_code( compiler => $self->compiler);

    my $comp = eval { $self->eval_object_code( object_code => $object_code ) };
    $self->_compilation_error( $p{name}, $@ ) if $@;

    $comp->assign_runtime_properties($self, $source);

    return $comp;
}

sub set_global
{
    my ($self, $decl, @values) = @_;
    param_error "Interp->set_global: expects a variable name and one or more values"
        unless @values;
    my ($prefix, $name) = ($decl =~ s/^([\$@%])//) ? ($1, $decl) : ('$', $decl);

    my $varname = sprintf("%s::%s",$self->compiler->in_package,$name);
    no strict 'refs';
    no warnings 'once';
    if ($prefix eq '$') {
        $$varname = $values[0];
    } elsif ($prefix eq '@') {
        @$varname = @values;
    } else {
        %$varname = @values;
    }
}

sub comp_root
{
    my $self = shift;
    
    if (my $new_comp_root = shift) {
        die "cannot assign new comp_root unless dynamic_comp_root parameter is set"
          unless $self->dynamic_comp_root;
        $self->_assign_comp_root($new_comp_root);
    }
    if (@{$self->{comp_root}} == 1 and $self->{comp_root}[0][0] eq 'MAIN') {
        return $self->{comp_root}[0][1];
    } else {
        return $self->{comp_root};
    }
}

sub comp_root_array
{
    return @{ $_[0]->{comp_root} };
}

sub _assign_comp_root
{
    my ($self, $new_comp_root) = @_;

    # Force into lol format.
    if (!ref($new_comp_root)) {
        $new_comp_root = [[ MAIN => $new_comp_root ]];
    } elsif (ref($new_comp_root) ne 'ARRAY') {
        die "Component root $new_comp_root must be a scalar or array reference";
    }

    # Validate key/path pairs, and check to see if any of them
    # conflict with old pairs.
    my $comp_root_key_map = $self->{comp_root_key_map} ||= {};
    foreach my $pair (@$new_comp_root) {
        param_error "Multiple-path component root must consist of a list of two-element lists"
          if ref($pair) ne 'ARRAY';
        param_error "Component root key '$pair->[0]' cannot contain slash"
          if $pair->[0] =~ /\//;
        $pair->[1] = File::Spec->canonpath( $pair->[1] );
        param_error "comp_root path '$pair->[1]' is not an absolute directory"
          unless File::Spec->file_name_is_absolute( $pair->[1] );
            
        my ($key, $path) = @$pair;
        if (my $orig_path = $comp_root_key_map->{$key}) {
            if ($path ne $orig_path) {
                die "comp_root key '$key' was originally associated with '$path', cannot change to '$orig_path'";
            }
        } else {
            $comp_root_key_map->{$key} = $path;
        }
    }
    $self->{comp_root} = $new_comp_root;
}

sub resolve_comp_path_to_source
{
    my ($self, $path) = @_;
    
    my $source;
    if ($self->{static_source}) {
        # Maintain a separate source_cache for each component root,
        # because the set of active component roots can change
        # from request to request.
        #
        my $source_cache = $self->{source_cache};
        foreach my $pair (@{$self->{comp_root}}) {
            my $source_cache_for_root = $source_cache->{$pair->[0]} ||= {};
            unless (exists($source_cache_for_root->{$path})) {
                $source_cache_for_root->{$path}
                  = $self->{resolver}->get_info($path, @$pair);
            }
            last if $source = $source_cache_for_root->{$path};
        }
    } else {
        my $resolver = $self->{resolver};
        foreach my $pair ($self->comp_root_array) {
            last if $source = $resolver->get_info($path, @$pair);
        }
    }
    return $source;
}

sub files_written
{
    my $self = shift;
    return @{$self->{files_written}};
}

#
# Push onto list of written files.
#
sub push_files_written
{
    my $self = shift;
    my $fref = $self->{'files_written'};
    push(@$fref,@_);
}

#
# Look for component <$name> starting in <$startpath> and moving upwards
# to the root. Return component object or undef.
#
sub find_comp_upwards
{
    my ($self, $startpath, $name) = @_;
    $startpath =~ s{/+$}{};

    # Don't use File::Spec here, this is a URL path.
    do {
      my $comp = $self->load("$startpath/$name");
      return $comp if $comp;
    } while $startpath =~ s{/+[^/]*$}{};

    return;  # Nothing found
}

###################################################################
# The eval_object_code & write_object_file methods used to be in
# Parser.pm.  This is a temporary home only.  They need to be moved
# again at some point in the future (during some sort of interp
# re-architecting).
###################################################################

#
# eval_object_code
#   (object_code, object_file, error)
# Evaluate an object file or object text.  Return a component object
# or undef if error.
#
# I think this belongs in the resolver (or comp loader) - Dave
#
sub eval_object_code
{
    my ($self, %p) = @_;

    #
    # Evaluate object file or text with warnings on, unless
    # ignore_warnings_expr is '.'.
    #
    my $ignore_expr = $self->ignore_warnings_expr;
    my ($comp, $err);
    my $warnstr = '';

    {
        local $^W = $ignore_expr eq '.' ? 0 : 1;
        local $SIG{__WARN__} =
            ( $ignore_expr ?
              ( $ignore_expr eq '.' ?
                sub { } :
                sub { $warnstr .= $_[0] if $_[0] !~ /$ignore_expr/ }
              ) :
              sub { $warnstr .= $_[0] } );
        
        $comp = $self->_do_or_eval(\%p);
    }

    $err = $warnstr . $@;

    #
    # Return component or error
    #
    if ($err) {
        # attempt to stem very long eval errors
        $err =~ s/has too many errors\..+/has too many errors./s;
        compilation_error $err;
    } else {
        return $comp;
    }
}

sub _do_or_eval
{
    my ($self, $p) = @_;

    if ($p->{object_file}) {
        return do $p->{object_file};
    } else {
        # If in taint mode, untaint the object text
        (${$p->{object_code}}) = ${$p->{object_code}} =~ /^(.*)/s if taint_is_on;

        return eval ${$p->{object_code}};
    }
}

sub _compilation_error {
    my ($self, $filename, $err) = @_;

    HTML::Mason::Exception::Compilation->throw(error=>$err, filename=>$filename);
}


sub object_file {
    my ($self, $comp) = @_;
    return $comp->persistent ?
        $self->comp_id_to_objfile($comp->comp_id) :
        undef;
}

sub use_autohandlers
{
    my $self = shift;
    return defined $self->{autohandler_name} and length $self->{autohandler_name};
}

# Generate HTML that describes Interp's current status.
# This is used in things like Apache::Status reports.  Currently shows:
# -- Interp properties
# -- loaded (cached) components
sub status_as_html {
    my ($self, %p) = @_;

    # Should I be scared about this?  =)

    my $comp_source = <<'EOF';
<h3>Interpreter properties:</h3>
<blockquote>
 <h4>Startup options:</h4>
 <tt>
<table width="100%">
<%perl>
foreach my $property (sort keys %$interp) {
    my $val = $interp->{$property};

    my $default = ( defined $val && defined $valid{$property}{default} && $val eq $valid{$property}{default} ) || ( ! defined $val && exists $valid{$property}{default} && ! defined $valid{$property}{default} );

    my $display = $val;
    if (ref $val) {
        $display = '<font color="darkred">';
        # only object can ->can, others die
        my $is_object = eval { $val->can('anything'); 1 };
        if ($is_object) {
            $display .= ref $val . ' object';
        } else {
            if (UNIVERSAL::isa($val, 'ARRAY')) {
                $display .= 'ARRAY reference - [ ';
                $display .= join ', ', @$val;
                $display .= '] ';
            } elsif (UNIVERSAL::isa($val, 'HASH')) {
                $display .= 'HASH reference - { ';
                my @pairs;
                while (my ($k, $v) = each %$val) {
                   push @pairs, "$k => $v";
                }
                $display .= join ', ', @pairs;
                $display .= ' }';
            } else {
                $display = ref $val . ' reference';
            }
        }
        $display .= '</font>';
    }

    defined $display && $display =~ s,([\x00-\x1F]),'<font color="purple">control-' . chr( ord('A') + ord($1) - 1 ) . '</font>',eg; # does this work for non-ASCII?
</%perl>
 <tr valign="top" cellspacing="10">
  <td>
    <% $property | h %>
  </td>
  <td>
   <% defined $display ? $display : '<i>undef</i>' %>
   <% $default ? '<font color=green>(default)</font>' : '' %>
  </td>
 </tr>
% }
</table>
  </tt>

 <h4>Components in memory cache:</h4>
 <tt>
% my $cache;
% if ($cache = $interp->code_cache and %$cache) {
%   foreach my $key (sort keys %$cache) {
      <% $key |h%> (modified <% scalar localtime $cache->{$key}->{lastmod} %>)
      <br>
%   }
% } else {
    <I>None</I>
% }
  </tt>
</blockquote>

<%args>
 $interp   # The interpreter we'll elucidate
 %valid    # Default values for interp member data
</%args>
EOF

    my $comp = $self->make_component(comp_source => $comp_source);
    my $out;

    my $args = [interp => $self, valid => $self->validation_spec];
    $self->make_request(comp=>$comp, args=>$args, out_method=>\$out, %p)->exec;

    return $out;
}

sub set_escape
{
    my $self = shift;
    my %p = @_;

    while ( my ($name, $sub) = each %p )
    {
        my $flag_regex = $self->compiler->lexer->escape_flag_regex;

        param_error "Invalid escape name ($name)"
            if $name !~ /^$flag_regex$/ || $name =~ /^n$/;

        my $coderef;
        if ( ref $sub )
        {
            $coderef = $sub;
        }
        else
        {
            if ( $sub =~ /^\w+$/ )
            {
                no strict 'refs';
                unless ( defined &{"HTML::Mason::Escapes::$sub"} )
                {
                    param_error "Invalid escape: $sub (no matching subroutine in HTML::Mason::Escapes";
                }

                $coderef = \&{"HTML::Mason::Escapes::$sub"};
            }
            else
            {
                $coderef = eval $sub;
                param_error "Invalid escape: $sub ($@)" if $@;
            }
        }

        $self->{escapes}{$name} = $coderef;
    }
}

sub remove_escape
{
    my $self = shift;

    delete $self->{escapes}{ shift() };
}

sub apply_escapes
{
    my $self = shift;
    my $text = shift;

    foreach my $flag (@_)
    {
        param_error "Invalid escape flag: $flag"
            unless exists $self->{escapes}{$flag};

        $self->{escapes}{$flag}->(\$text);
    }

    return $text;
}

1;

__END__

=head1 NAME

HTML::Mason::Interp - Mason Component Interpreter

=head1 SYNOPSIS

    my $i = HTML::Mason::Interp->new (data_dir=>'/usr/local/mason',
                                      comp_root=>'/usr/local/www/htdocs/',
                                      ...other params...);

=head1 DESCRIPTION

Interp is the Mason workhorse, executing components and routing their
output and errors to all the right places. In a mod_perl environment,
Interp objects are handed off immediately to an ApacheHandler object
which internally calls the Interp implementation methods. In that case
the only user method is the new() constructor.

=head1 PARAMETERS TO THE new() CONSTRUCTOR

=over

=item autohandler_name

File name used for
L<autohandlers|HTML::Mason::Devel/autohandlers>. Default is
"autohandler".  If this is set to an empty string ("") then
autohandlers are turned off entirely.

=item buffer_preallocate_size

=for html <a name="item_buffer_preallocate_size"></a>

Number of bytes to preallocate in the output buffer for each request.
Defaults to 0. Setting this to, say, your maximum page size (or close
to it) can reduce the number of reallocations Perl performs as
components add to the output buffer.

=item code_cache_max_size

=for html <a name="item_code_cache_max_size"></a>

Specifies the maximum number of components that should be held in the
in-memory code cache. The default is 'unlimited', meaning no
components will ever be discarded; Mason can perform certain
optimizations in this mode. Setting this to zero disables the code
cache entirely. See the L<code cache|HTML::Mason::Admin/code cache>
section of the administrator's manual for further details.

=item comp_root

=for html <a name="item_comp_root"></a>

The component root marks the top of your component hierarchy and
defines how component paths are translated into real file paths. For
example, if your component root is F</usr/local/httpd/docs>, a component
path of F</products/index.html> translates to the file
F</usr/local/httpd/docs/products/index.html>.

Under L<Apache|HTML::Mason::ApacheHandler> and
L<CGI|HTML::Mason::CGIHandler>, comp_root defaults to the server's
document root. In standalone mode comp_root defaults to the current
working directory.

This parameter may be either a scalar or an array reference.  If it is
a scalar, it should be a filesystem path indicating the component
root. If it is an array reference, it should be of the following form:

 [ [ foo => '/usr/local/foo' ],
   [ bar => '/usr/local/bar' ] ]

This is an array of two-element array references, not a hash.  The
"keys" for each path must be unique and their "values" must be
filesystem paths.  These paths will be searched in the provided order
whenever a component path is resolved. For example, given the above
component roots and a component path of F</products/index.html>, Mason
would search first for F</usr/local/foo/products/index.html>, then for
F</usr/local/bar/products/index.html>.

The keys are used in several ways. They help to distinguish component
caches and object files between different component roots, and they
appear in the C<title()> of a component.

When you specify a single path for a component root, this is actually
translated into

  [ [ MAIN => path ] ]

If you have turned on L<dynamic_comp_root|HTML::Mason::Params/dynamic_comp_root>, you may modify the
component root(s) of an interpreter between requests by calling
C<$interp-E<gt>comp_root> with a value. However, the path associated
with any given key may not change between requests. For example,
if the initial component root is

 [ [ foo => '/usr/local/foo' ],
   [ bar => '/usr/local/bar' ], ]

then it may not be changed to

 [ [ foo => '/usr/local/bar' ],
   [ bar => '/usr/local/baz' ],

but it may be changed to

 [ [ foo   => '/usr/local/foo' ],
   [ blarg => '/usr/local/blarg' ] ]

In other words, you may add or remove key/path pairs but not modify an
already-used key/path pair. The reason for this restriction is that
the interpreter maintains a component cache per key that would become
invalid if the associated paths were to change.

=item compiler

The Compiler object to associate with this Interpreter.  By default a
new object of class L<compiler_class|HTML::Mason::Params/compiler_class> will be created.

=item compiler_class

The class to use when creating a compiler. Defaults to
L<HTML::Mason::Compiler|HTML::Mason::Compiler>.

=item data_dir

The data directory is a writable directory that Mason uses for various
features and optimizations: for example, component object files and
data cache files. Mason will create the directory on startup, if necessary, and set its
permissions according to the web server User/Group.

Under L<Apache|HTML::Mason::ApacheHandler>, data_dir defaults to a
directory called "mason" under the Apache server root. You will
need to change this on certain systems that assign a high-level
server root such as F</usr>!

In non-Apache environments, data_dir has no default. If it is left
unspecified, Mason will not use L<object files|HTML::Mason::Admin/object files>, and the default
L<data cache class|HTML::Mason::Request/item_cache> will be
C<MemoryCache> instead of C<FileCache>.

=item dynamic_comp_root

True or false, defaults to false. Indicates whether the L<comp_root|HTML::Mason::Params/comp_root>
can be modified on this interpreter between requests. Mason can
perform a few optimizations with a fixed component root, so you
should only set this to true if you actually need it.

=item escape_flags

A hash reference of escape flags to set for this object.  See the
section on the L<set_escape
method|HTML::Mason::Interp/item_set_escape> for more details.

=item ignore_warnings_expr

Regular expression indicating which warnings to ignore when loading
components. Any warning that is not ignored will prevent the
component from being loaded and executed. For example:

    ignore_warnings_expr =>
        'Global symbol.*requires explicit package'

If set to undef, all warnings are heeded. If set to '.', warnings
are turned off completely as a specially optimized case.

By default, this is set to 'Subroutine .* redefined'.  This allows you
to declare global subroutines inside <%once> sections and not receive
an error when the component is reloaded.

=item object_file_extension

Extension to add to the end of object files. Default is ".obj".

=item preloads

A list of component paths, optionally with glob wildcards, to load
when the interpreter initializes. e.g.

    preloads => ['/foo/index.html','/bar/*.pl']

Default is the empty list.  For maximum performance, this should only
be used for components that are frequently viewed and rarely updated.
See the L<preloading components|HTML::Mason::Admin/preloading components> section of the administrator's manual for further details.

As mentioned in the developer's manual, a component's C<< <%once> >>
section is executed when it is loaded.  For preloaded components, this
means that this section will be executed before a Mason or Apache
request exist, so preloading a component that uses C<$m> or C<$r> in a
C<< <%once> >> section will fail.

=item request_class

The class to use when creating requests. Defaults to
L<HTML::Mason::Request|HTML::Mason::Request>.

=item resolver

The Resolver object to associate with this Compiler. By default a new
object of class L<resolver_class|HTML::Mason::Params/resolver_class> will be created.

=item resolver_class

The class to use when creating a resolver. Defaults to
L<HTML::Mason::Resolver::File|HTML::Mason::Resolver::File>.

=item static_source

True or false, default is false. When false, Mason checks the
timestamp of the component source file each time the component is used
to see if it has changed. This provides the instant feedback for
source changes that is expected for development.  However it does
entail a file stat for each component executed.

When true, Mason assumes that the component source tree is unchanging:
it will not check component source files to determine if the memory
cache or object file has expired.  This can save many file stats per
request. However, in order to get Mason to recognize a component
source change, you must flush the memory cache and remove object files.
See L<static_source_touch_file|HTML::Mason::Params/static_source_touch_file> for one easy way to arrange this.

We recommend turning this mode on in your production sites if
possible, if performance is of any concern.

=item static_source_touch_file

Specifies a filename that Mason will check once at the beginning of
of every request. When the file timestamp changes, Mason will (1) clear
its in-memory component cache, and (2) remove object files if
they have not already been deleted by another process.

This provides a convenient way to implement L<static_source|HTML::Mason::Params/static_source> mode.
All you need to do is make sure that a single file gets touched
whenever components change. For Mason's part, checking a single
file at the beginning of a request is much cheaper than checking
every component file when static_source=0.

=item use_object_files

True or false, default is true.  Specifies whether Mason creates
object files to save the results of component parsing. You may want to
turn off object files for disk space reasons, but otherwise this
should be left alone.

=back

=head1 ACCESSOR METHODS

All of the above properties have standard accessor methods of the same
name. Only comp_root and ignore_warnings_expr can be modified in an
existing interpreter; the rest are read-only.

=head1 ESCAPE FLAG METHODS

=over

=item apply_escapes ($text, $flags, [more flags...])

=for html <a name="item_apply_escapes"></a>

This method applies a one or more escapes to a piece of text.  The
escapes are specified by giving their flag.  Each escape is applied to
the text in turn, after which the now-modified text is returned.

=item remove_escape ($name)

=for html <a name="item_remove_escape"></a>

Given an escape name, this removes that escape from the interpreter's
known escapes.  If the name is not recognized, it is simply ignored.

=item set_escape ($name => see below])

=for html <a name="item_set_escape"></a>

This method is called to add an escape flag to the list of known
escapes for the interpreter.  The flag may only consist of the
characters matching C<\w> and the dash (-).  It must start with an
alpha character or an underscore (_).

The right hand side may be one of several things.  It can be a
subroutine reference.  It can also be a string match C</^\w+$/>, in
which case it is assumed to be the name of a subroutine in the
C<HTML::Mason::Escapes> module.  Finally, if it is a string that does
not match the above regex, then it is assumed to be C<eval>able code,
which will return a subroutine reference.

When setting these with C<PerlSetVar> directives in an Apache
configuration file, you can set them like this:

  PerlSetVar  MasonEscapeFlags  "h => \&HTML::Mason::Escapes::basic_html_escape"
  PerlSetVar  MasonEscapeFlags  "flag  => \&subroutine"
  PerlSetVar  MasonEscapeFlags  "uc    => sub { ${$_[0]} = uc ${$_[0]}; }"
  PerlAddVar  MasonEscapeFlags  "thing => other_thing"

=back

=head1 OTHER METHODS

=over

=item comp_exists (path)

=for html <a name="item_comp_exists"></a>

Given an I<absolute> component path, this method returns a boolean
value indicating whether or not a component exists for that path.

=item exec (comp, args...)

=for html <a name="item_exec"></a>

Creates a new HTML::Mason::Request object for the given I<comp> and
I<args>, and executes it. The return value is the return value of
I<comp>, if any.

This is useful for running Mason outside of a web environment.
See L<HTML::Mason::Admin/using Mason from a standalone script>
for examples.

This method isn't generally useful in a mod_perl environment; see
L<subrequests|HTML::Mason::Devel/Subrequests> instead.

=item flush_code_cache

=for html <a name="flush_code_cache"></a>

Empties the component cache. When using Perl 5.00503 or earlier, you
should call this when finished with an interpreter, in order to remove
circular references that would prevent the interpreter from being
destroyed.

=item load (path)

=for html <a name="item_load"></a>

Returns the component object corresponding to an absolute component
C<path>, or undef if none exists. Dies with an error if the component
fails to load because of a syntax error.

=item make_component (comp_source => ... )

=item make_component (comp_file => ... )

=for html <a name="item_make_component"></a>

This method compiles Mason component source code and returns a
Component object.  The source may be passed in as a string in C<comp_source>,
or as a filename in C<comp_file>.  When using C<comp_file>, the
filename is specified as a path on the file system, not as a path
relative to Mason's component root (see 
L<$m-E<gt>fetch_comp|HTML::Mason::Request/item_fetch_comp> for that).

If Mason encounters an error during processing, an exception will be thrown.

Example of usage:

    # Make an anonymous component
    my $anon_comp =
      eval { $interp->make_component
               ( comp_source => '<%perl>my $name = "World";</%perl>Hello <% $name %>!' ) };
    die $@ if $@;

    $m->comp($anon_comp);

=item make_request (@request_params)

=for html <a name="item_make_request"></a>

This method creates a Mason request object. The arguments to be passed
are the same as those for the C<< HTML::Mason::Request->new >>
constructor or its relevant subclass. This method will likely only be
of interest to those attempting to write new handlers or to subclass
C<HTML::Mason::Interp>.  If you want to create a I<subrequest>, see
L<subrequests|HTML::Mason::Devel/Subrequests> instead.

=item purge_code_cache ()

=for html <a name="purge_code_cache"></a>

Called during request execution in order to clear out the code
cache. Mainly useful to subclasses that may want to take some custom
action upon clearing the cache.

=item set_global ($varname, [values...])

=for html <a name="item_set_global"></a>

This method sets a global to be used in components. C<varname> is a
variable name, optionally preceded with a prefix (C<$>, C<@>, or
C<%>); if the prefix is omitted then C<$> is assumed. C<varname> is
followed by a value, in the case of a scalar, or by one or more values
in the case of a list or hash.  For example:

    # Set a global variable $dbh containing the database handle
    $interp->set_global(dbh => DBI->connect(...));

    # Set a global hash %session from a local hash
    $interp->set_global('%session', %s);

The global is set in the package that components run in: usually
C<HTML::Mason::Commands>, although this can be overridden via the
L<in_package|HTML::Mason::Params/in_package> parameter.
The lines above, for example, are equivalent to:

    $HTML::Mason::Commands::dbh = DBI->connect(...);
    %HTML::Mason::Commands::session = %s;

assuming that L<in_package|HTML::Mason::Params/in_package> has not been changed.

Any global that you set should also be registered with the
L<allow_globals|HTML::Mason::Params/allow_globals> parameter; otherwise you'll get warnings from
C<strict>.

=back

=head1 SEE ALSO

L<HTML::Mason|HTML::Mason>,
L<HTML::Mason::Admin|HTML::Mason::Admin>,
L<HTML::Mason::ApacheHandler|HTML::Mason::ApacheHandler>

=cut
