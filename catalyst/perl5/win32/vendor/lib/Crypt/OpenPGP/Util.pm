package Crypt::OpenPGP::Util;
use strict;

use Math::Pari qw( PARI pari2num floor Mod lift );

use vars qw( @EXPORT_OK @ISA );
use Exporter;
@EXPORT_OK = qw( bitsize bin2mp mp2bin mod_exp mod_inverse
                 dash_escape dash_unescape canonical_text );
@ISA = qw( Exporter );

sub bitsize {
    return pari2num(floor(Math::Pari::log($_[0])/Math::Pari::log(2)) + 1);
}

sub bin2mp { Math::Pari::_hex_cvt('0x' . unpack 'H*', $_[0]) }

sub mp2bin {
    my($p) = @_;
    $p = PARI($p);
    my $base = PARI(1) << PARI(4*8);
    my $res = '';
    while ($p != 0) {
        my $r = $p % $base;
        $p = ($p-$r) / $base;
        my $buf = pack 'N', $r;
        if ($p == 0) {
            $buf = $r >= 16777216 ? $buf :
                   $r >= 65536 ? substr($buf, -3, 3) :
                   $r >= 256   ? substr($buf, -2, 2) :
                                 substr($buf, -1, 1);
        } 
        $res = $buf . $res;
    }
    $res;
}

sub mod_exp {
    my($a, $exp, $n) = @_;
    my $m = Mod($a, $n);
    lift($m ** $exp);
}

sub mod_inverse {
    my($a, $n) = @_;
    my $m = Mod(1, $n);
    lift($m / $a);
}

sub dash_escape {
    my($data) = @_;
    $data =~ s/^-/- -/mg;
    $data;
}

sub dash_unescape {
    my($data) = @_;
    $data =~ s/^-\s//mg;
    $data;
}

sub canonical_text {
    my($text) = @_;
    my @lines = split /\n/, $text, -1;
    for my $l (@lines) {
## pgp2 and pgp5 do not trim trailing whitespace from "canonical text"
## signatures, only from cleartext signatures.
## See:
##   http://cert.uni-stuttgart.de/archive/ietf-openpgp/2000/01/msg00033.html
        if ($Crypt::OpenPGP::Globals::Trim_trailing_ws) {
            $l =~ s/[ \t\r\n]*$//;
        } else {
            $l =~ s/[\r\n]*$//;
        }
    }
    join "\r\n", @lines;
}

1;
__END__

=head1 NAME

Crypt::OpenPGP::Util - Miscellaneous utility functions

=head1 DESCRIPTION

I<Crypt::OpenPGP::Util> contains a set of exportable utility functions
used through the I<Crypt::OpenPGP> set of libraries.

=head2 bitsize($n)

Returns the number of bits in the I<Math::Pari> integer object
I<$n>.

=head2 bin2mp($string)

Given a string I<$string> of any length, treats the string as a
base-256 representation of an integer, and returns that integer,
a I<Math::Pari> object.

=head2 mp2bin($int)

Given a biginteger I<$int> (a I<Math::Pari> object), linearizes
the integer into an octet string, and returns the octet string.

=head2 mod_exp($a, $exp, $n)

Computes $a ^ $exp mod $n and returns the value. The calculations
are done using I<Math::Pari>, and the return value is a I<Math::Pari>
object.

=head2 mod_inverse($a, $n)

Computes the multiplicative inverse of $a mod $n and returns the
value. The calculations are done using I<Math::Pari>, and the
return value is a I<Math::Pari> object.

=head2 canonical_text($text)

Takes a piece of text content I<$text> and formats it into PGP canonical
text, where: 1) all whitespace at the end of lines is stripped, and
2) all line endings are made up of a carriage return followed by a line
feed. Returns the canonical form of the text.

=head2 dash_escape($text)

Escapes I<$text> for use in a cleartext signature; the escaping looks
for any line starting with a dash, and on such lines prepends a dash
('-') followed by a space (' '). Returns the escaped text.

=head1 AUTHOR & COPYRIGHTS

Please see the Crypt::OpenPGP manpage for author, copyright, and
license information.

=cut
