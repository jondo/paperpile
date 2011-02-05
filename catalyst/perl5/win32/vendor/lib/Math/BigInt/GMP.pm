###############################################################################
# core math lib for BigInt, representing big numbers by the GMP library

package Math::BigInt::GMP;

use strict;
use 5.006002;
# use warnings; # dont use warnings for older Perls

use vars qw/$VERSION/;

$VERSION = '1.24';

use XSLoader;
XSLoader::load "Math::BigInt::GMP", $VERSION;

sub import { }			# catch and throw away
sub api_version() { 2; }	# we are compatible with MBI v1.83 and up

BEGIN
  {
  # both _num and _str just return a string
  *_str = \&_num;
  }

##############################################################################
# Routines not present here are in GMP.xs

sub _digit
  {
  # return the nth digit, negative values count backward; this is costly!
  my ($c,$x,$n) = @_;

  $n++; substr( Math::BigInt::GMP::_num($c,$x), -$n, 1 );
  }

###############################################################################
# routine to test internal state for corruptions

sub _check
  {
  # no checks yet, pull it out from the test suite
  my ($x) = $_[1];
  return "$x is not a reference to Math::BigInt::GMP"
   if ref($x) ne 'Math::BigInt::GMP';
  0;
  }

sub _log_int
  {
  my ($c,$x,$base) = @_;

  # X == 0 => NaN
  return if _is_zero($c,$x);

  $base = _new($c,2) unless defined $base;
  $base = _new($c,$base) unless ref $base;

  # BASE 0 or 1 => NaN
  return if _is_zero($c,$base) || _is_one($c,$base);

  my $cmp = _acmp($c,$x,$base); 	# X == BASE => 1
  if ($cmp == 0)
    {
    # return one
    return (_one($c), 1);
    }
  # X < BASE
  if ($cmp < 0)
    {
    return (_zero($c),undef);
    }

  # Compute a guess for the result based on:
  # $guess = int ( length_in_base_10(X) / ( log(base) / log(10) ) )
  my $len = _alen($c,$x);
  my $log = log( _num($c,$base) ) / log(10);

  # calculate now a guess based on the values obtained above:
  my $x_org = _copy($c,$x);

  # keep the reference to $x, modifying it in place
  _set($c, $x, int($len / $log) - 1);

  my $trial = _pow ($c, _copy($c, $base), $x);
  my $a = _acmp($c,$trial,$x_org);

  if ($a == 0)
    {
    return ($x,1);
    }
  elsif ($a > 0)
    {
    # too big, shouldn't happen
    _div($c,$trial,$base); _dec($c, $x);
    }

  # find the real result by going forward:
  my $base_mul = _mul($c, _copy($c,$base), $base);
  my $two = _two($c);

  while (($a = _acmp($c, $trial, $x_org)) < 0)
    {
    _mul($c,$trial,$base_mul); _add($c, $x, $two);
    }

  my $exact = 1;
  if ($a > 0)
    {
    # overstepped the result
    _dec($c, $x);
    _div($c,$trial,$base);
    $a = _acmp($c,$trial,$x_org);
    if ($a > 0)
      {
      _dec($c, $x);
      }
    $exact = 0 if $a != 0;
    }

  ($x,$exact);
  }

1;
__END__

=pod

=head1 NAME

Math::BigInt::GMP - Use the GMP library for Math::BigInt routines

=head1 SYNOPSIS

Provides support for big integer calculations via means of the GMP c-library.

Math::BigInt::GMP now no longer uses Math::GMP, but provides it's own XS layer
to access the GMP c-library. This cut's out another (perl sub routine) layer
and also reduces the memory footprint by not loading Math::GMP and Carp at
all.

=head1 LICENSE
 
This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself. 

=head1 AUTHOR

Tels <http://bloodgate.com/> in 2001-2007.

Thanx to Chip Turner for providing Math::GMP, which was inspiring my work.

=head1 SEE ALSO

L<Math::BigInt>, L<Math::BigInt::Calc>.

=cut
