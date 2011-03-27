use strict;
use warnings;

package Class::C3::Adopt::NEXT;

use NEXT;
use MRO::Compat;
use List::MoreUtils qw/none/;
use warnings::register;

our $VERSION = '0.11';

{
    my %c3_mro_ok;
    my %warned_for;
    my @no_warn_regexes;

    {
        my $orig = NEXT->can('AUTOLOAD');

        no warnings 'redefine';
        *NEXT::AUTOLOAD = sub {
            my $class = ref $_[0] || $_[0];
            my $caller = caller();

            # 'NEXT::AUTOLOAD' is cargo-culted from C::P::C3, I have no idea if/why it's needed
            my $wanted = our $AUTOLOAD || 'NEXT::AUTOLOAD';
            my ($wanted_class) = $wanted =~ m{(.*)::};

            unless (exists $c3_mro_ok{$class}) {
                eval { mro::get_linear_isa($class, 'c3') };
                if (my $error = $@) {
                    warn "Class::C3::calculateMRO('${class}') Error: '${error}';"
                    . ' Falling back to plain NEXT.pm behaviour for this class';
                    $c3_mro_ok{$class} = 0;
                }
                else {
                    $c3_mro_ok{$class} = 1;
                }
            }

            if (length $c3_mro_ok{$class} && $c3_mro_ok{$class}) {
                unless ($warned_for{$caller}) {
                    $warned_for{$caller} = 1;
                    if (!@no_warn_regexes || none { $caller =~ $_ } @no_warn_regexes) {
                        warnings::warnif("${caller} uses NEXT, which is deprecated. Please see "
                            . "the Class::C3::Adopt::NEXT documentation for details. NEXT used ");
                    }
                }
            }

            unless ($c3_mro_ok{$class}) {
                $NEXT::AUTOLOAD = $wanted;
                goto &$orig;
            }

            goto &next::method if $wanted_class =~ /^NEXT:.*:ACTUAL/;
            goto &maybe::next::method;
        };

        *NEXT::ACTUAL::AUTOLOAD = \&NEXT::AUTOLOAD;
    }

    sub import {
        my ($class, @args) = @_;
        my $target = caller();

        for my $arg (@args) {
            $warned_for{$target} = 1
                if $arg eq '-no_warn';
        }
    }

    sub unimport {
        my $class = shift;
        my @strings = grep { !ref $_ || ref($_) ne 'Regexp' } @_;
        my @regexes = grep { ref($_) && ref($_) eq 'Regexp' } @_;
        @c3_mro_ok{@strings} = ('') x @strings;
        push @no_warn_regexes, @regexes;
    }
}

1;

__END__

=head1 NAME

Class::C3::Adopt::NEXT - make NEXT suck less

=head1 SYNOPSIS

    package MyApp::Plugin::FooBar;
    #use NEXT;
    use Class::C3::Adopt::NEXT;
    # or 'use Class::C3::Adopt::NEXT -no_warn;' to suppress warnings

    # Or use warnings::register
    # no warnings 'Class::C3::Adopt::NEXT';

    # Or suppress warnings in a set of modules from one place
    # no Class::C3::Adopt::NEXT qw/ Module1 Module2 Module3 /;
    # Or suppress using a regex
    # no Class::C3::Adopt::NEXT qr/^Module\d$/;

    sub a_method {
        my ($self) = @_;
        # Do some stuff

        # Re-dispatch method
        # Note that this will generate a warning the _first_ time the package
        # uses NEXT unless you un comment the 'no warnings' line above.
        $self->NEXT::method();
    }

=head1 DESCRIPTION

L<NEXT> was a good solution a few
years ago, but isn't any more.  It's slow, and the order in which it
re-dispatches methods appears random at times. It also encourages bad
programming practices, as you end up with code to re-dispatch methods when all
you really wanted to do was run some code before or after a method fired.

However, if you have a large application, then weaning yourself off C<NEXT> isn't
easy.

This module is intended as a drop-in replacement for NEXT, supporting the same
interface, but using L<Class::C3> to do the hard work. You can then write new
code without C<NEXT>, and migrate individual source files to use C<Class::C3> or
method modifiers as appropriate, at whatever pace you're comfortable with.

=head1 WARNINGS

This module will warn once for each package using NEXT. It uses
L<warnings::register>, and so can be disabled like by adding C<no warnings
'Class::C3::Adopt::NEXT';> to each package which generates a warning, or
adding C<use Class::C3::Adopt::NEXT -no_warn;>, or disable multiple modules at
once by saying:

    no Class::C3::Adopt::NEXT qw/ Module1 Module2 Module3 /;

somewhere before the warnings are first triggered. You can also setup entire
name spaces of modules which will not warn using a regex, e.g.

    no Class::C3::Adopt::NEXT qr/^Module\d$/;

=head1 MIGRATING

=head2 Current code using NEXT

You add C<use MRO::Compat> to the top of a package as you start converting it,
and gradually replace your calls to C<NEXT::method()> with
C<maybe::next::method()>, and calls to C<NEXT::ACTUAL::method()> with
C<next::method()>.

Example:

    sub yourmethod {
        my $self = shift;
        
        # $self->NEXT::yourmethod(@_); becomes
        $self->maybe::next::method();
    }

    sub othermethod {
        my $self = shift;

        # $self->NEXT::ACTUAL::yourmethodname(); becomes
        $self->next::method();
    }

On systems with L<Class::C3::XS> present, this will automatically be used to
speed up method re-dispatch. If you are running perl version 5.9.5 or greater
then the C3 method resolution algorithm is included in perl. Correct use
of L<MRO::Compat> as shown above allows your code to be seamlessly forward
and backwards compatible, taking advantage of native versions if available,
but falling back to using pure perl C<Class::C3>.

=head2 Writing new code

Use L<Moose> and make all of your plugins L<Moose::Roles|Moose::Role>, then use
method modifiers to wrap methods.

Example:

    package MyApp::Role::FooBar;
    use Moose::Role;

    before 'a_method' => sub {
        my ($self) = @_;
        # Do some stuff
    };

    around 'a_method' => sub {
        my $orig = shift;
        my $self = shift;
        # Do some stuff before
        my $ret = $self->$orig(@_); # Run wrapped method (or not!)
        # Do some stuff after
        return $ret;
    };

    package MyApp;
    use Moose;

    with 'MyApp::Role::FooBar';

=head1 CAVEATS

There are some inheritance hierarchies that it is possible to create which
cannot be resolved to a simple C3 hierarchy. In that case, this module will
fall back to using C<NEXT>. In this case a warning will be emitted.

Because calculating the MRO of every class every time C<< ->NEXT::foo >> is used
from within it is too expensive, runtime manipulations of C<@ISA> are
prohibited.

=head1 FUNCTIONS

This module replaces C<NEXT::AUTOLOAD> with it's own version. If warnings
are enabled then a warning will be emitted on the first use of C<NEXT> by
each package.

=head1 SEE ALSO

L<MRO::Compat> and L<Class::C3> for method re-dispatch and L<Moose> for
method modifiers and L<roles|Moose::Role>.

L<NEXT> for documentation on the functionality you'll be removing.

=head1 AUTHORS

Florian Ragwitz C<rafl@debian.org>

Tomas Doran C<bobtfish@bobtfish.net>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2008  Florian Ragwitz

You may distribute this code under the same terms as Perl itself.

=cut
