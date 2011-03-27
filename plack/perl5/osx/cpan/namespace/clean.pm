package namespace::clean;

=head1 NAME

namespace::clean - Keep imports and functions out of your namespace

=cut

use warnings;
use strict;

use vars        qw( $VERSION $STORAGE_VAR $SCOPE_HOOK_KEY $SCOPE_EXPLICIT );
use Symbol      qw( qualify_to_ref gensym );
use B::Hooks::EndOfScope;
use Sub::Identify qw(sub_fullname);
use Sub::Name qw(subname);

=head1 VERSION

0.13

=cut

$VERSION         = '0.14';
$STORAGE_VAR     = '__NAMESPACE_CLEAN_STORAGE';

=head1 SYNOPSIS

  package Foo;
  use warnings;
  use strict;

  use Carp qw(croak);   # 'croak' will be removed

  sub bar { 23 }        # 'bar' will be removed

  # remove all previously defined functions
  use namespace::clean;

  sub baz { bar() }     # 'baz' still defined, 'bar' still bound

  # begin to collection function names from here again
  no namespace::clean;

  sub quux { baz() }    # 'quux' will be removed

  # remove all functions defined after the 'no' unimport
  use namespace::clean;

  # Will print: 'No', 'No', 'Yes' and 'No'
  print +(__PACKAGE__->can('croak') ? 'Yes' : 'No'), "\n";
  print +(__PACKAGE__->can('bar')   ? 'Yes' : 'No'), "\n";
  print +(__PACKAGE__->can('baz')   ? 'Yes' : 'No'), "\n";
  print +(__PACKAGE__->can('quux')  ? 'Yes' : 'No'), "\n";

  1;

=head1 DESCRIPTION

=head2 Keeping packages clean

When you define a function, or import one, into a Perl package, it will
naturally also be available as a method. This does not per se cause
problems, but it can complicate subclassing and, for example, plugin
classes that are included via multiple inheritance by loading them as 
base classes.

The C<namespace::clean> pragma will remove all previously declared or
imported symbols at the end of the current package's compile cycle.
Functions called in the package itself will still be bound by their
name, but they won't show up as methods on your class or instances.

By unimporting via C<no> you can tell C<namespace::clean> to start
collecting functions for the next C<use namespace::clean;> specification.

You can use the C<-except> flag to tell C<namespace::clean> that you
don't want it to remove a certain function or method. A common use would
be a module exporting an C<import> method along with some functions:

  use ModuleExportingImport;
  use namespace::clean -except => [qw( import )];

If you just want to C<-except> a single sub, you can pass it directly.
For more than one value you have to use an array reference.

=head2 Explicitely removing functions when your scope is compiled

It is also possible to explicitely tell C<namespace::clean> what packages
to remove when the surrounding scope has finished compiling. Here is an
example:

  package Foo;
  use strict;

  # blessed NOT available

  sub my_class {
      use Scalar::Util qw( blessed );
      use namespace::clean qw( blessed );

      # blessed available
      return blessed shift;
  }

  # blessed NOT available

=head2 Moose

When using C<namespace::clean> together with L<Moose> you want to keep
the installed C<meta> method. So your classes should look like:

  package Foo;
  use Moose;
  use namespace::clean -except => 'meta';
  ...

Same goes for L<Moose::Role>.

=head2 Cleaning other packages

You can tell C<namespace::clean> that you want to clean up another package
instead of the one importing. To do this you have to pass in the C<-cleanee>
option like this:

  package My::MooseX::namespace::clean;
  use strict;

  use namespace::clean (); # no cleanup, just load

  sub import {
      namespace::clean->import(
        -cleanee => scalar(caller),
        -except  => 'meta',
      );
  }

If you don't care about C<namespace::clean>s discover-and-C<-except> logic, and
just want to remove subroutines, try L</clean_subroutines>.

=head1 METHODS

You shouldn't need to call any of these. Just C<use> the package at the
appropriate place.

=cut

=head2 clean_subroutines

This exposes the actual subroutine-removal logic.

  namespace::clean->clean_subroutines($cleanee, qw( subA subB ));

will remove C<subA> and C<subB> from C<$cleanee>. Note that this will remove the
subroutines B<immediately> and not wait for scope end. If you want to have this
effect at a specific time (e.g. C<namespace::clean> acts on scope compile end)
it is your responsibility to make sure it runs at that time.

=cut

my $RemoveSubs = sub {

    my $cleanee = shift;
    my $store   = shift;
  SYMBOL:
    for my $f (@_) {
        my $fq = "${cleanee}::$f";

        # ignore already removed symbols
        next SYMBOL if $store->{exclude}{ $f };
        no strict 'refs';

        next SYMBOL unless exists ${ "${cleanee}::" }{ $f };

        if (ref(\${ "${cleanee}::" }{ $f }) eq 'GLOB') {
            # convince the Perl debugger to work
            # it assumes that sub_fullname($sub) can always be used to find the CV again
            # since we are deleting the glob where the subroutine was originally
            # defined, that assumption no longer holds, so we need to move it
            # elsewhere and point the CV's name to the new glob.
            my $sub = \&$fq;
            if ( sub_fullname($sub) eq $fq ) {
                my $new_fq = "namespace::clean::deleted::$fq";
                subname($new_fq, $sub);
                *{$new_fq} = $sub;
            }

            local *__tmp;

            # keep original value to restore non-code slots
            {   no warnings 'uninitialized';    # fix possible unimports
                *__tmp = *{ ${ "${cleanee}::" }{ $f } };
                delete ${ "${cleanee}::" }{ $f };
            }

          SLOT:
            # restore non-code slots to symbol.
            # omit the FORMAT slot, since perl erroneously puts it into the
            # SCALAR slot of the new glob.
            for my $t (qw( SCALAR ARRAY HASH IO )) {
                next SLOT unless defined *__tmp{ $t };
                *{ "${cleanee}::$f" } = *__tmp{ $t };
            }
        }
        else {
            # A non-glob in the stash is assumed to stand for some kind
            # of function.  So far they all do, but the core might change
            # this some day.  Watch perl5-porters.
            delete ${ "${cleanee}::" }{ $f };
        }
    }
};

sub clean_subroutines {
    my ($nc, $cleanee, @subs) = @_;
    $RemoveSubs->($cleanee, {}, @subs);
}

=head2 import

Makes a snapshot of the current defined functions and installs a
L<B::Hooks::EndOfScope> hook in the current scope to invoke the cleanups.

=cut

sub import {
    my ($pragma, @args) = @_;

    my (%args, $is_explicit);

  ARG:
    while (@args) {

        if ($args[0] =~ /^\-/) {
            my $key = shift @args;
            my $value = shift @args;
            $args{ $key } = $value;
        }
        else {
            $is_explicit++;
            last ARG;
        }
    }

    my $cleanee = exists $args{ -cleanee } ? $args{ -cleanee } : scalar caller;
    if ($is_explicit) {
        on_scope_end {
            $RemoveSubs->($cleanee, {}, @args);
        };
    }
    else {

        # calling class, all current functions and our storage
        my $functions = $pragma->get_functions($cleanee);
        my $store     = $pragma->get_class_store($cleanee);

        # except parameter can be array ref or single value
        my %except = map {( $_ => 1 )} (
            $args{ -except }
            ? ( ref $args{ -except } eq 'ARRAY' ? @{ $args{ -except } } : $args{ -except } )
            : ()
        );

        # register symbols for removal, if they have a CODE entry
        for my $f (keys %$functions) {
            next if     $except{ $f };
            next unless    $functions->{ $f } 
                    and *{ $functions->{ $f } }{CODE};
            $store->{remove}{ $f } = 1;
        }

        # register EOF handler on first call to import
        unless ($store->{handler_is_installed}) {
            on_scope_end {
                $RemoveSubs->($cleanee, $store, keys %{ $store->{remove} });
            };
            $store->{handler_is_installed} = 1;
        }

        return 1;
    }
}

=head2 unimport

This method will be called when you do a

  no namespace::clean;

It will start a new section of code that defines functions to clean up.

=cut

sub unimport {
    my ($pragma, %args) = @_;

    # the calling class, the current functions and our storage
    my $cleanee   = exists $args{ -cleanee } ? $args{ -cleanee } : scalar caller;
    my $functions = $pragma->get_functions($cleanee);
    my $store     = $pragma->get_class_store($cleanee);

    # register all unknown previous functions as excluded
    for my $f (keys %$functions) {
        next if $store->{remove}{ $f }
             or $store->{exclude}{ $f };
        $store->{exclude}{ $f } = 1;
    }

    return 1;
}

=head2 get_class_store

This returns a reference to a hash in a passed package containing 
information about function names included and excluded from removal.

=cut

sub get_class_store {
    my ($pragma, $class) = @_;
    no strict 'refs';
    return \%{ "${class}::${STORAGE_VAR}" };
}

=head2 get_functions

Takes a class as argument and returns all currently defined functions
in it as a hash reference with the function name as key and a typeglob
reference to the symbol as value.

=cut

sub get_functions {
    my ($pragma, $class) = @_;

    return {
        map  { @$_ }                                        # key => value
        grep { *{ $_->[1] }{CODE} }                         # only functions
        map  { [$_, qualify_to_ref( $_, $class )] }         # get globref
        grep { $_ !~ /::$/ }                                # no packages
        do   { no strict 'refs'; keys %{ "${class}::" } }   # symbol entries
    };
}

=head1 BUGS

C<namespace::clean> will clobber any formats that have the same name as
a deleted sub. This is due to a bug in perl that makes it impossible to
re-assign the FORMAT ref into a new glob.

=head1 IMPLEMENTATION DETAILS

This module works through the effect that a 

  delete $SomePackage::{foo};

will remove the C<foo> symbol from C<$SomePackage> for run time lookups
(e.g., method calls) but will leave the entry alive to be called by
already resolved names in the package itself. C<namespace::clean> will
restore and therefor in effect keep all glob slots that aren't C<CODE>.

A test file has been added to the perl core to ensure that this behaviour
will be stable in future releases.

Just for completeness sake, if you want to remove the symbol completely,
use C<undef> instead.

=head1 SEE ALSO

L<B::Hooks::EndOfScope>

=head1 AUTHOR AND COPYRIGHT

Robert 'phaylon' Sedlacek C<E<lt>rs@474.atE<gt>>, with many thanks to
Matt S Trout for the inspiration on the whole idea.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify 
it under the same terms as perl itself.

=cut

no warnings;
'Danger! Laws of Thermodynamics may not apply.'
