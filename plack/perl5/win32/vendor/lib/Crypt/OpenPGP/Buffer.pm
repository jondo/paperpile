package Crypt::OpenPGP::Buffer;
use base qw( Data::Buffer );

use Crypt::OpenPGP::Util qw( bin2mp mp2bin bitsize );

sub get_mp_int {
    my $buf = shift;
    my $bits = $buf->get_int16;
    my $bytes = int(($bits + 7) / 8);
    my $off = $buf->{offset};
    $buf->{offset} += $bytes;
    bin2mp($buf->bytes($off, $bytes));
}

sub put_mp_int {
    my $buf = shift;
    my($n) = @_;
    $buf->put_int16(bitsize($n));
    $buf->put_bytes(mp2bin($n));
}

1;
__END__

=head1 NAME

Crypt::OpenPGP::Buffer - Binary in/out buffer

=head1 SYNOPSIS

    use Crypt::OpenPGP::Buffer;

    my $n = PARI( 1 );
    
    my $buf = Crypt::OpenPGP::Buffer->new;
    $buf->put_mp_int($n);

    my $m = $buf->get_mp_int;

=head1 DESCRIPTION

I<Crypt::OpenPGP::Buffer> subclasses the I<Data::Buffer> class to
provide binary in/out buffer capabilities for I<Crypt::OpenPGP>. In
addition to the standard I<Data::Buffer> methods, this class adds
methods to get and put multiple-precision integers (I<Math::Pari>
objects).

A PGP multiple precision integer is stored in two pieces: a two-octet
scalar representing the length of the integer in bits, followed by
a string of octets that is a serialized representation of the integer.

=head1 USAGE

As I<Crypt::OpenPGP::Buffer> subclasses I<Data::Buffer> there is no
need to reproduce the entire documentation of the latter module. Thus
this usage section will include only the methods added by
I<Crypt::OpenPGP::Buffer>.

=head2 $buf->get_mp_int

Grabs a multiple-precision integer from the buffer I<$buf> (starting
after the current offset position in the buffer) and returns that
integer.

=head2 $buf->put_mp_int($n)

Serializes a multiple-precision integer into the buffer in the above
form (two-octet bitsize, string of octets).

=head1 AUTHOR & COPYRIGHTS

Please see the Crypt::OpenPGP manpage for author, copyright, and
license information.

=cut
