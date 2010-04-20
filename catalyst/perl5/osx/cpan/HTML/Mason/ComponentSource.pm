# Copyright (c) 1998-2005 by Jonathan Swartz. All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

package HTML::Mason::ComponentSource;

use strict;
use warnings;
use File::Basename;
use File::Spec;
use HTML::Mason::Exceptions( abbr => [qw(param_error error)] );
use Params::Validate qw(:all);
Params::Validate::validation_options( on_fail => sub { param_error join '', @_  } );

# for reference later
#
# BEGIN
# {
#     __PACKAGE__->valid_params
#         (
#          comp_id       => { type => SCALAR | UNDEF, public => 0 },
#          friendly_name => { type => SCALAR, public => 0 },
#          last_modified => { type => SCALAR, public => 0 },
#          comp_path     => { type => SCALAR, public => 0 },
#          comp_class    => { isa => 'HTML::Mason::Component',
#                             default => 'HTML::Mason::Component',
#                             public => 0 },
#          extra         => { type => HASHREF, default => {}, public => 0 },
#          source_callback => { type => CODEREF, public => 0 },
#     );
# }

use HTML::Mason::MethodMaker
    ( read_only => [ qw( comp_id
                         friendly_name
                         last_modified
                         comp_path
                         comp_class
                         extra
                        ) ],
      );

my %defaults = ( comp_class => 'HTML::Mason::Component' );

sub new
{
    my $class = shift;

    return bless { %defaults, @_ }, $class
}

sub comp_source_ref
{
    my $self = shift;

    my $source = eval { $self->{source_callback}->() };

    rethrow_exception $@;

    unless ( defined $source )
    {
	error "source callback returned no source for $self->{friendly_name} component";
    }

    my $sourceref = ref($source) ? $source : \$source;
    return $sourceref;
}

sub comp_source { ${shift()->comp_source_ref} }

sub object_code
{
    my $self = shift;
    my %p = validate( @_, { compiler => { isa => 'HTML::Mason::Compiler' } } );

    return $p{compiler}->compile( comp_source => $self->comp_source,
				  name => $self->friendly_name,
                                  comp_path => $self->comp_path,
				  comp_class => $self->comp_class,
                                );
}

1;

__END__

=head1 NAME

HTML::Mason::ComponentSource - represents information about an component

=head1 SYNOPSIS

    my $info = $resolver->get_info($comp_path);

=head1 DESCRIPTION

Mason uses the ComponentSource class to store information about a
source component, one that has yet to be compiled.

=head1 METHODS

=over

=item new

This method takes the following arguments:

=over 4

=item * comp_path

The component's component path.

=item * last_modified

This is the last modificatoin time for the component, in Unix time
(seconds since the epoch).

=item * comp_id

This is a unique id for the component used to distinguish two
components with the same name in different component roots.

If your resolver does not support multiple component roots, this can
simply be the same as the "comp_path" key or it can be any other id
you wish.

This value will be used when constructing filesystem paths so it needs
to be something that works on different filesystems.  If it contains
forward slashes, these will be converted to the appropriate
filesystem-specific path separator.

In fact, we encourage you to make sure that your component ids have
some forward slashes in them or also B<all> of your generated object
files will end up in a single directory, which could affect
performance.

=item * comp_class

The component class into which this particular component should be
blessed when it is created.  This must be a subclass of
C<HTML::Mason::Component>, which is the default.

=item * friendly_name

This is used when displaying error messages related to the component,
like parsing errors.  This should be something that will help whoever
sees the message identify the component.  For example, for component
stored on the filesystem, this should be the absolute path to the
component.

=item * source_callback

This is a subroutine reference which, when called, returns the
component source.

The reasoning behind using this parameter is that it helps avoid a
profusion of tiny little C<HTML::Mason::ComponentSource> subclasses that
don't do very much.

=item * extra

This optional parameter should be a hash reference.  It is used to
pass information from the resolver to the component class.

This is needed since a
L<C<HTML::Mason::Resolver>|HTML::Mason::Resolver> subclass and a
L<C<HTML::Mason::Component>|HTML::Mason::Component> subclass can be
rather tightly coupled, but they must communicate with each through
the interpreter (this may change in the future).

=back

=item comp_path

=item last_modified

=item comp_id

=item comp_class

=item friendly_name

=item extra

These are all simple accessors that return the value given to the
constructor.

=item comp_source

Returns the source of the component.

=item object_code ( compiler => $compiler )

Given a compiler, this method returns the object code for the
component.

=back

L<HTML::Mason|HTML::Mason>,
L<HTML::Mason::Admin|HTML::Mason::Admin>,
L<HTML::Mason::Component|HTML::Mason::Component>

=cut
