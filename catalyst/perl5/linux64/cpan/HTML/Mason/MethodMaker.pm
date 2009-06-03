# Copyright (c) 1998-2005 by Jonathan Swartz. All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

package HTML::Mason::MethodMaker;

use strict;
use warnings;

use Params::Validate qw(validate_pos);

sub import
{
    my $caller = caller;
    shift; # don't need class name
    my %p = @_;

    if ($p{read_only})
    {
        foreach my $ro ( ref $p{read_only} ? @{ $p{read_only} } : $p{read_only} )
        {
            no strict 'refs';
            *{"$caller\::$ro"} = sub { return $_[0]->{$ro} };
        }
    }

    #
    # The slight weirdness to avoid calling shift in these rw subs is
    # _intentional_.  These subs get called a lot simply to read the
    # value, and optimizing this common case actually does achieve
    # something.
    #
    if ($p{read_write})
    {
        foreach my $rw ( ref $p{read_write} ? @{ $p{read_write} } : $p{read_write} )
        {
            if (ref $rw)
            {
                my ($name, $spec) = @$rw;
                my $sub =
                    sub { if (@_ > 1)
                          {
                              my $s = shift;
                              validate_pos(@_, $spec);
                              $s->{$name} = shift;
                              return $s->{$name};
                          }
                          return $_[0]->{$name};
                        };
                no strict 'refs';
                *{"$caller\::$name"} = $sub
            }
            else
            {
                my $sub =
                    sub { if (@_ > 1)
                          {
                              $_[0]->{$rw} = $_[1];
                          }
                          return $_[0]->{$rw};
                        };
                no strict 'refs';
                *{"$caller\::$rw"} = $sub;
            }
        }
    }

    if ($p{read_write_contained})
    {
        foreach my $object (keys %{ $p{read_write_contained} })
        {
            foreach my $rwc (@{ $p{read_write_contained}{$object} })
            {
                if (ref $rwc)
                {
                    my ($name, $spec) = @$rwc;
                    my $sub =
                        sub { my $s = shift;
                              my %new;
                              if (@_)
                              {
                                  validate_pos(@_, $spec);
                                  %new = ( $name => $_[0] );
                              }
                              my %args = $s->delayed_object_params( $object,
                                                                    %new );
                              return $args{$rwc};
                            };
                    no strict 'refs';
                    *{"$caller\::$name"} = $sub;
                }
                else
                {
                    my $sub =
                        sub { my $s = shift;
                              my %new = @_ ? ( $rwc => $_[0] ) : ();
                              my %args = $s->delayed_object_params( $object,
                                                                    %new );
                              return $args{$rwc};
                            };
                    no strict 'refs';
                    *{"$caller\::$rwc"} = $sub;
                }
            }
        }
    }
}

1;

=pod

=head1 NAME

HTML::Mason::MethodMaker - Used to create simple get & get/set methods in other classes

=head1 SYNOPSIS

 use HTML::Mason::MethodMaker
     ( read_only => 'foo',
       read_write => [
                      [ bar => { type => SCALAR } ],
                      [ baz => { isa => 'HTML::Mason::Baz' } ],
                      'quux', # no validation
                     ],
       read_write_contained => { other_object =>
                                 [
                                  [ 'thing1' => { isa => 'Thing1' } ],
                                  'thing2', # no validation
                                 ]
                               },
     );

=head1 DESCRIPTION

This automates the creation of simple accessor methods.

=head1 USAGE

This module creates methods when it is C<use>'d by another module.
There are three types of methods: 'read_only', 'read_write',
'read_write_contained'.

Attributes specified as 'read_only' get an accessor that only returns
the value of the attribute.  Presumably, these attributes are set via
more complicated methods in the class or as a side effect of one of
its methods.

Attributes specified as 'read_write' will take a single optional
parameter.  If given, this parameter will become the new value of the
attribute.  This value is then returned from the method.  If no
parameter is given, then the current value is returned.

If you want the accessor to use C<Params::Validate> to validate any
values passed to the accessor (and you _do_), then the the accessor
specification should be an array reference containing two elements.
The first element is the accessor name and the second is the
validation spec.

The 'read_write_contained' parameter is used to create accessor for
delayed contained objects.  A I<delayed> contained object is one that
is B<not> created in the containing object's accessor, but rather at
some point after the containing object is constructed.  For example,
the Interpreter object creates Request objects after the Interpreter
itself has been created.

The value of the 'read_write_contained' parameter should be a hash
reference.  The keys are the internal name of the contained object,
such as "request" or "compiler".  The values for the keys are the same
as the parameters given for 'read_write' accessors.

=head1 SEE ALSO

L<HTML::Mason|HTML::Mason>

=cut
