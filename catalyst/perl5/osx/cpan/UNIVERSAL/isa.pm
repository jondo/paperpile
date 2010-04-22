package UNIVERSAL::isa;

use strict;
use vars qw( $VERSION $recursing );

use UNIVERSAL ();

use Scalar::Util 'blessed';
use warnings::register;

$VERSION = '1.03';

my ( $orig, $verbose_warning );

BEGIN { $orig = \&UNIVERSAL::isa }

no warnings 'redefine';

sub import
{
    my $class = shift;
    no strict 'refs';

    for my $arg (@_)
    {
        *{ caller() . '::isa' } = \&UNIVERSAL::isa if $arg eq 'isa';
        $verbose_warning = 1 if $arg eq 'verbose';
    }
}

sub UNIVERSAL::isa
{
    goto &$orig if $recursing;
    my $type = invocant_type(@_);
    $type->(@_);
}

sub invocant_type
{
    my $invocant = shift;
    return \&nonsense unless defined($invocant);
    return \&object_or_class if blessed($invocant);
    return \&reference       if ref($invocant);
    return \&nonsense unless $invocant;
    return \&object_or_class;
}

sub nonsense
{
    report_warning('on invalid invocant') if $verbose_warning;
    return;
}

sub object_or_class
{

    local $@;
    local $recursing = 1;

    if ( my $override = eval { $_[0]->can('isa') } )
    {
        unless ( $override == \&UNIVERSAL::isa )
        {
            report_warning();
            my $obj = shift;
            return $obj->$override(@_);
        }
    }

    report_warning() if $verbose_warning;
    goto &$orig;
}

sub reference
{
    report_warning('Did you mean to use Scalar::Util::reftype() instead?')
        if $verbose_warning;
    goto &$orig;
}

sub report_warning
{
    my $extra = shift;
    $extra = $extra ? " ($extra)" : '';

    if ( warnings::enabled() )
    {
        my $calling_sub = ( caller(3) )[3] || '';
        return if $calling_sub =~ /::isa$/;
        warnings::warn(
            "Called UNIVERSAL::isa() as a function, not a method$extra" );
    }
}

__PACKAGE__;

__END__

=pod

=head1 NAME

UNIVERSAL::isa - Attempt to recover from people calling UNIVERSAL::isa as a
function

=head1 SYNOPSIS

    # from the shell
    echo 'export PERL5OPT=-MUNIVERSAL::isa' >> /etc/profile

    # within your program
    use UNIVERSAL::isa;

    # enable warnings for all dodgy uses of UNIVERSAL::isa
    use UNIVERSAL::isa 'verbose';

=head1 DESCRIPTION

Whenever you use L<UNIVERSAL/isa> as a function, a kitten using
L<Test::MockObject> dies. Normally, the kittens would be helpless, but if they
use L<UNIVERSAL::isa> (the module whose docs you are reading), the kittens can
live long and prosper.

This module replaces C<UNIVERSAL::isa> with a version that makes sure that,
when called as a function on objects which override C<isa>, C<isa> will call
the appropriate method on those objects

In all other cases, the real C<UNIVERSAL::isa> gets called directly.

=head1 WARNINGS

If the lexical warnings pragma is available, this module will emit a warning
for each naughty invocation of C<UNIVERSAL::isa>. Silence these warnings by
saying:

    no warnings 'UNIVERSAL::isa';

in the lexical scope of the naughty code.

After version 1.00, warnings only appear when naughty code calls
UNIVERSAL::isa() as a function on an invocant for which there is an overridden
isa().  These are really truly I<active> bugs, and you should fix them rather
than relying on this module to find them.

To get warnings for all potentially dangerous uses of UNIVERSAL::isa() as a
function, not a method (that is, for I<all> uses of the method as a function,
which are latent bugs, if not bugs that will break your code as it exists now),
pass the C<verbose> flag when using the module.  This can generate many extra
warnings, but they're more specific as to the actual wrong practice and they
usually suggest proper fixes.

=head1 SEE ALSO

L<UNIVERSAL::can> for another discussion of the problem at hand.

L<Test::MockObject> for one example of a module that really needs to override
C<isa()>.

Any decent explanation of OO to understand why calling methods as functions is
a staggeringly bad idea.

=head1 AUTHORS

Audrey Tang <cpan@audreyt.org>

chromatic <chromatic@wgz.org>

Yuval Kogman <nothingmuch@woobling.org>

=head1 COPYRIGHT & LICENSE

Artistic Licence 2.0, (c) 2005 - 2009.

=cut
