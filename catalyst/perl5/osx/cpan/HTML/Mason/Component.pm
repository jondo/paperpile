# Copyright (c) 1998-2005 by Jonathan Swartz. All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

package HTML::Mason::Component;

use strict;
use warnings;
use File::Spec;
use HTML::Mason::Exceptions( abbr => [qw(param_error)] );
use HTML::Mason::Tools qw(absolute_comp_path can_weaken);
use Params::Validate qw(:all);
Params::Validate::validation_options( on_fail => sub { param_error join '', @_  } );

use HTML::Mason::Exceptions( abbr => ['error'] );
use HTML::Mason::MethodMaker
    ( read_only => [ qw( code
                         comp_id
                         compiler_id
                         declared_args
                         inherit_path
                         inherit_start_path
                         has_filter
                         load_time
                       ) ],

      read_write => [ [ dynamic_subs_request => { isa => 'HTML::Mason::Request' } ],
                      [ mfu_count => { type => SCALAR } ],
                      [ filter => { type => CODEREF } ],
                    ]
      );

# for reference later
# 
# __PACKAGE__->valid_params
#     (
#      attr               => {type => HASHREF, default => {}, public => 0},
#      code               => {type => CODEREF, public => 0, public => 0},
#      load_time          => {type => SCALAR,  optional => 1, public => 0},
#      declared_args      => {type => HASHREF, default => {}, public => 0},
#      dynamic_subs_init  => {type => CODEREF, default => sub {}, public => 0},
#      flags              => {type => HASHREF, default => {}, public => 0},
#      comp_id            => {type => SCALAR,  optional => 1, public => 0},
#      methods            => {type => HASHREF, default => {}, public => 0},
#      mfu_count          => {type => SCALAR,  default => 0, public => 0},
#      parser_version     => {type => SCALAR,  optional => 1, public => 0}, # allows older components to be instantied
#      compiler_id        => {type => SCALAR,  optional => 1, public => 0},
#      subcomps           => {type => HASHREF, default => {}, public => 0},
#     );
# 

my %defaults = ( attr              => {},
                 declared_args     => {},
                 dynamic_subs_init => sub {},
                 flags             => {},
                 methods           => {},
                 mfu_count         => 0,
                 subcomps          => {},
               );
sub new
{
    my $class = shift;
    my $self = bless { %defaults, @_ }, $class;

    # Initialize subcomponent and method properties: owner, name, and
    # is_method flag.
    while (my ($name,$c) = each(%{$self->{subcomps}})) {
        $c->assign_subcomponent_properties($self,$name,0);
        Scalar::Util::weaken($c->{owner}) if can_weaken;
    }
    while (my ($name,$c) = each(%{$self->{methods}})) {
        $c->assign_subcomponent_properties($self,$name,1);
        Scalar::Util::weaken($c->{owner}) if can_weaken;
    }

    return $self;
}

my $comp_count = 0;
sub assign_runtime_properties {
    my ($self, $interp, $source) = @_;
    $self->interp($interp);
    $self->{comp_id} = defined $source->comp_id ? $source->comp_id : "[anon ". ++$comp_count . "]";

    $self->{path} = $source->comp_path;

    $self->_determine_inheritance;

    foreach my $c (values(%{$self->{subcomps}}), values(%{$self->{methods}})) {
        $c->assign_runtime_properties($interp, $source);
    }

    # Cache of uncanonicalized call paths appearing in the
    # component. Used in $m->fetch_comp.
    #
    if ($interp->use_internal_component_caches) {
        $self->{fetch_comp_cache} = {};
    }
}

sub flush_internal_caches
{
    my ($self) = @_;

    $self->{fetch_comp_cache} = {};
    delete($self->{parent_cache});
}

sub _determine_inheritance {
    my $self = shift;

    my $interp = $self->interp;

    # Assign inheritance properties
    if (exists($self->{flags}->{inherit})) {
        if (defined($self->{flags}->{inherit})) {
            $self->{inherit_path} = absolute_comp_path($self->{flags}->{inherit}, $self->dir_path);
        }
    } elsif ( $interp->use_autohandlers ) {
        if ($self->name eq $interp->autohandler_name) {
            unless ($self->dir_path eq '/') {
                ($self->{inherit_start_path}) = $self->dir_path =~ m,^(.*/)?.*,s
            }
        } else {
            $self->{inherit_start_path} = $self->dir_path;
        }
    }
}

sub run {
    my $self = shift;

    $self->{mfu_count}++;

    $self->{code}->(@_);
}

sub dynamic_subs_init {
    my $self = shift;

    error "cannot call a method or subcomponent from a <%shared> block"
        if $self->{in_dynamic_subs_init};

    local $self->{in_dynamic_subs_init} = 1;

    $self->{dynamic_subs_hash} = $self->{dynamic_subs_init}->();
    error "could not process <%shared> section (does it contain a return()?)"
        unless ref($self->{dynamic_subs_hash}) eq 'HASH';
}

sub run_dynamic_sub {
    my ($self, $key, @args) = @_;

    error "call_dynamic: assert error - could not find code for key $key in component " . $self->title
        unless exists $self->{dynamic_subs_hash}->{$key};

    return $self->{dynamic_subs_hash}->{$key}->(@args);
}

# Legacy, left in for pre-0.8 obj files
sub assign_subcomponent_properties {}

#
# By default components are not persistent.
#
sub persistent { 0 }

#
# Only true in Subcomponent subclass.
#
sub is_subcomp { 0 }

sub is_method { 0 }

#
# Only true in FileBased subclass.
#
sub is_file_based { 0 }

#
# Basic defaults for component designators: title, path, name, dir_path
#
sub title { return $_[0]->{comp_id} }
sub name { return $_[0]->{comp_id} }
sub path { return undef }
sub dir_path { return undef }

#
# Get all subcomps or particular subcomp by name
#
sub subcomps {
    my ($self,$key) = @_;
    if (defined($key)) {
        return $self->{subcomps}->{$key};
    } else {
        return $self->{subcomps};
    }
}

#
# Get all methods or particular method by name
#
sub methods {
    my ($self,$key) = @_;
    if (defined($key)) {
        return $self->{methods}->{$key};
    } else {
        return $self->{methods};
    }
}

#
# Get all attributes
#
sub attributes { $_[0]->{attr} }

#
# Get attribute by name
#
sub attr {
    my ($self,$name) = @_;
    my $value;
    if ($self->_locate_inherited('attr',$name,\$value)) {
        return $value;
    } else {
        error "no attribute '$name' for component " . $self->title;
    }
}

sub attr_if_exists {
    my ($self,$name) = @_;
    my $value;
    if ($self->_locate_inherited('attr',$name,\$value)) {
        return $value;
    } else {
        return undef;
    }
}

#
# Determine if particular attribute exists
#
sub attr_exists {
    my ($self,$name) = @_;
    return $self->_locate_inherited('attr',$name);
}

#
# Call method by name
#
sub call_method {
    my ($self,$name,@args) = @_;
    my $method;
    if ($self->_locate_inherited('methods',$name,\$method)) {
        HTML::Mason::Request->instance->comp({base_comp=>$self},$method,@args);
    } else {
        error "no method '$name' for component " . $self->title;
    }
}

#
# Like call method, but return component output.
#
sub scall_method {
    my ($self,$name,@args) = @_;
    my $method;
    if ($self->_locate_inherited('methods',$name,\$method)) {
        HTML::Mason::Request->instance->scomp({base_comp=>$self},$method,@args);
    } else {
        error "no method '$name' for component " . $self->title;
    }
}

#
# Determine if particular method exists
#
sub method_exists {
    my ($self,$name) = @_;
    return $self->_locate_inherited('methods',$name);
}

#
# Locate a component slot element following inheritance path
#
sub _locate_inherited {
    my ($self,$field,$key,$ref) = @_;
    my $count = 0;
    for (my $comp = $self; $comp; $comp = $comp->parent) {
        if (exists($comp->{$field}->{$key})) {
            $$ref = $comp->{$field}->{$key} if $ref;
            return 1;
        }
        error "inheritance chain length > 32 (infinite inheritance loop?)"
            if ++$count > 32;
    }
    return 0;
}

#
# Get particular flag by name
#
sub flag {
    my ($self,$name) = @_;
    my %flag_defaults =
        (
         );
    if (exists($self->{flags}->{$name})) {
        return $self->{flags}->{$name};
    } elsif (exists($flag_defaults{$name})) {
        return $flag_defaults{$name};
    } else {
        error "invalid flag: $name";
    }
}

#
# Return parent component according to inherit flag.
#
sub parent {
    my ($self) = @_;

    # Return cached value for parent, if any (may be undef)
    #
    return $self->{parent_cache} if exists($self->{parent_cache});

    my $interp = $self->interp;
    my $parent;
    if ($self->inherit_path) {
        $parent = $interp->load($self->inherit_path)
            or error(sprintf("cannot find inherit path '%s' for component '%s'",
                             $self->inherit_path, $self->title));
    } elsif ($self->inherit_start_path) {
        $parent = $interp->find_comp_upwards($self->inherit_start_path, $interp->autohandler_name);
    }

    # Can only cache parent value if interp->{use_internal_component_caches} is on -
    # see definition in Interp::_initialize.
    #
    if ($interp->use_internal_component_caches) {
        $self->{parent_cache} = $parent;
    }

    return $parent;
}

sub interp {
    my $self = shift;

    if (@_) {
        validate_pos( @_, { isa => 'HTML::Mason::Interp' } );

        $self->{interp} = $_[0];

        Scalar::Util::weaken( $self->{interp} ) if can_weaken;
    } elsif ( ! defined $self->{interp} ) {
        die "The Interp object that this object contains has gone out of scope.\n";
    }

    return $self->{interp};
}

#
# Accessors for various files associated with component
#
sub object_file {
    my $self = shift;
    return $self->interp->object_file($self);
}

# For backwards compatibility with 1.0x
sub create_time {
    my $self = shift;
    return $self->load_time(@_);
}

1;

__END__

=head1 NAME

HTML::Mason::Component - Mason Component Class

=head1 SYNOPSIS

    my $comp1 = $m->current_comp;
    my $comp2 = $m->callers(1);
    my $comp3 = $m->fetch_comp('foo/bar');

    foreach ($comp1,$comp2,$comp3) {
       print "My name is ".$_->title.".\n";
    }

=head1 DESCRIPTION

Mason uses the Component class to store components loaded into
memory. Components come from three distinct sources:

=over 4

=item 1

File-based: loaded from a source or object file.

=item 2

Subcomponents: embedded components defined with the C<E<lt>%defE<gt>> 
or C<E<lt>%methodE<gt>> tags.

=item 3

Anonymous: created on-the-fly with the C<make_component> Interp method.

=back

Some of the methods below return different values (or nothing at all)
depending on the component type.

The component API is primarily useful for introspection, e.g. "what
component called me" or "does the next component take a certain
argument".  You can build complex Mason sites without ever dealing
directly with a component object.

=head2 CREATING AND ACCESSING COMPONENTS

Common ways to get handles on existing component objects include the
L<Request-E<gt>current_comp|HTML::Mason::Request/item_current_comp>,
L<Request-E<gt>callers|HTML::Mason::Request/item_callers>, and
L<Request-E<gt>fetch_comp|HTML::Mason::Request/item_fetch_comp> methods.

There is no published C<new> method, because creating a component
requires an Interpreter. Use the
L<make_component|HTML::Mason::Interp/item_make_component> method to
create a new component dynamically.

Similarly, there is no C<execute> or C<call> method, because calling a
component requires a request. All of the interfaces for calling a
component (C<< <& &> >>, C<< $m->comp >>, C<< $interp->exec >>)
which normally take a component path will also take a component
object.

=head1 METHODS

=over

=item attr (name)

Looks for the specified attribute in this component and its parents,
returning the first value found. Dies with an error if not
found. Attributes are declared in the C<E<lt>%attrE<gt>> section.

=item attr_if_exists (name)

This method works exactly like the one above but returns undef if the
attribute does not exist.

=item attr_exists (name)

Returns true if the specified attribute exists in this component or
one of its parents, undef otherwise.

=item attributes

Returns a hashref containing the attributes defined in this component,
with the attribute names as keys.  This does not return attributes
inherited from parent components.

=item call_method (name, args...)

Looks for the specified user-defined method in this component and its
parents, calling the first one found. Dies with an error if not found.
Methods are declared in the C<E<lt>%methodE<gt>> section.

=item create_time

A synonym for L<load_time|HTML::Mason::Component/item_load_time> (deprecated).

=item declared_args

Returns a reference to a hash of hashes representing the arguments
declared in the C<E<lt>%argsE<gt>> section. The keys of the main hash are the
variable names including prefix (e.g. C<$foo>, C<@list>). Each  
secondary hash contains:

=over 4

=item *

'default': the string specified for default value (e.g. 'fido') or undef
if none specified.  Note that in general this is not the default value
itself but rather a Perl expression that gets evaluated every time the
component runs.

=back

For example:

  # does $comp have an argument called $fido?
  if (exists($comp->declared_args->{'$fido'})) { ... }

  # does $fido have a default value?
  if (defined($comp->declared_args->{'$fido'}->{default})) { ... }

=item dir_path

Returns the component's notion of a current directory, relative to the
component root; this is used to resolve relative component paths. For
file-based components this is the full component path minus the filename.
For subcomponents this is the same as the component that defines it.
Undefined for anonymous components.

=item flag (name)

Returns the value for the specified system flag.  Flags are declared
in the C<E<lt>%flagsE<gt>> section and affect the behavior of the component.
Unlike attributes, flags values do not get inherited from parent components.

=item is_subcomp

Returns true if this is a subcomponent of another component.  For
historical reasons, this returns true for both methods and
subcomponents.

=item is_method

Returns true if this is a method.

=item is_file_based

Returns true if this component was loaded from a source or object
file.

=for html <a name="item_load_time"></a>

=item load_time

Returns the time (in Perl time() format) when this component object
was created.

=item method_exists (name)

Returns true if the specified user-defined method exists in this
component or one of its parents, undef otherwise.

=item methods

This method works exactly like the
L<subcomps|HTML::Mason::Component/item_subcomps> method, but it
returns methods, not subcomponents.  This does not return methods
inherited from parent components.

Methods are declared in C<E<lt>%methodE<gt>> sections.

=item name

Returns a short name of the component.  For file-based components this
is the filename without the path. For subcomponents this is the name
specified in C<E<lt>%defE<gt>>. Undefined for anonymous components.

=item object_file

Returns the object filename for this component.

=item parent

Returns the parent of this component for inheritance purposes, by
default the nearest C<autohandler> in or above the component's directory.
Can be changed via the C<inherit> flag.

=item path

Returns the entire path of this component, relative to the component root.

=item scall_method (name, args...)

Like L<item_call_method|call_method>, but returns the method output as
a string instead of printing it. (Think sprintf versus printf.) The
method's return value, if any, is discarded.

=for html <a name="item_subcomps"></a>

=item subcomps

With no arguments, returns a hashref containing the subcomponents defined
in this component, with names as keys and component objects as values.
With one argument, returns the subcomponent of that name
or undef if no such subcomponent exists. e.g.

    if (my $subcomp = $comp->subcomps('.link')) {
        ...
    }

Subcomponents are declared in C<E<lt>%defE<gt>> sections.

=item title

Returns a printable string denoting this component.  It is intended to
uniquely identify a component within a given interpreter although this
is not 100% guaranteed. Mason uses this string in error messages,
among other places.

For file-based components this is the component path.  For
subcomponents this is "parent_component_path:subcomponent_name". For
anonymous components this is a unique label like "[anon 17]".

=back

=head1 FILE-BASED METHODS

The following methods apply only to file-based components (those
loaded from source or object files). They return undef for other
component types.

=over

=item source_file

Returns the source filename for this component.

=item source_dir

Returns the directory of the source filename for this component.

=back

=head1 SEE ALSO

L<HTML::Mason|HTML::Mason>,
L<HTML::Mason::Devel|HTML::Mason::Devel>,
L<HTML::Mason::Request|HTML::Mason::Request>

=cut
