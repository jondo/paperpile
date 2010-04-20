package Object::Signature;

use 5.005;
use strict;

use vars qw{$VERSION};
BEGIN {
	$VERSION = '1.05';
}

# If prefork is installed, use it
eval "use prefork 'Storable';";
eval "use prefork 'Digest::MD5';";

sub signature {
	require Storable;
	require Digest::MD5;
	local $Storable::canonical = 1;
	Digest::MD5::md5_hex(
		Storable::nfreeze(shift)
		);
}

1;

__END__

=pod

=head1 NAME

Signature - Generate cryptographic signatures for objects

=head1 SYNOPSIS

  # In your module
  package My::Module
  use base 'Object::Signature';
  
  # In outside code
  my $Object = My::Module->new;  
  print "Object Signature: " . $Object->signature;

=head1 DESCRIPTION

L<Object::Signature> is an abstract base class that you can inherit from in
order to allow your objects to generate unique cryptographic signatures.

The method used to generate the signature is based on L<Storable> and
L<Digest::MD5>. The object is fed to C<Storable::nfreeze> to get a string,
which is then passed to L<Digest::MD5::md5_hex> to get a unique 32
character hexidecimal signature.

=head1 METHODS

=head2 signature

The C<signature> method is the only method added to your class, and will
generate a unique 32 hexidecimal signature for any object it is called on.

=head1 SUPPORT

All bugs should be filed via the bug tracker at

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Object-Signature>

For other issues, or commercial enhancement or support, contact the author.

=head1 TO DO

=head2 Incremental Generation

Currently has to generate the entire Storable string before digesting
it. Would be nice if there was a way to incrementally Storablise and Digest
in one pass so that it becomes much more memory efficient for large objects.

=head2 Strengthen the Digest Algorithm

Once the current (as of 2005) hashing controversy settles down, consider
selecting a newer and more powerful hashing algorithm to replace MD5. Or
offer alternatives depending on how important the security situation is,
as MD5 is B<very> fast (90 meg a second) and many more-secure ones are a
lot slower (more than 10 times slower in some cases).

On our side is the fact we use Storable. It should be B<much> harder to create
collisions when you don't control the string, only the structure B<before>
it goes through Storable.

=head1 AUTHORS

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2004 - 2006 Adam Kennedy.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
