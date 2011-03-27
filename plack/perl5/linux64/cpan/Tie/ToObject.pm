#!/usr/bin/perl

package Tie::ToObject;

use strict;
#use warnings;

use vars qw($VERSION $AUTOLOAD);

use Carp qw(croak);
use Scalar::Util qw(blessed);

$VERSION = "0.03";

sub AUTOLOAD {
	my ( $self, $tied ) = @_;
	my ( $method ) = ( $AUTOLOAD =~ /([^:]+)$/ );

	if ( $method =~ /^TIE/ ) {
		if ( blessed($tied) ) {
			return $tied;
		} else {
			croak "You must supply an object as the argument to tie()";
		}
	} else {
		croak "Unsupported method for $method, this module is only for tying to existing objects";
	}
}

__PACKAGE__

__END__

=pod

=head1 NAME

Tie::ToObject - Tie to an existing object.

=head1 SYNOPSIS

	use Tie::ToObject;

	my $stolen = tied(%something);

	tie %something_else, 'Tie::ToObject', $stolen;

=head1 DESCRIPTION

While L<perldoc/tie> allows tying to an arbitrary object, the class in question
must support this in it's implementation of C<TIEHASH>, C<TIEARRAY> or
whatever.

This class provides a very tie constructor that simply returns the object it
was given as it's first argument.

This way side effects of calling C<< $object->TIEHASH >> are avoided.

This is used in L<Data::Visitor> in order to tie a variable to an already
existing object. This is also useful for cloning, when you want to clone the
internal state object instead of going through the tie interface for that
variable.

=head1 VERSION CONTROL

This module is maintained using Darcs. You can get the latest version from
L<http://nothingmuch.woobling.org/code>, and use C<darcs send> to commit
changes.

=head1 AUTHOR

Yuval Kogman E<lt>nothingmuch@woobling.orgE<gt>

=head1 COPYRIGHT

	Copyright (c) 2008 Yuval Kogman. All rights reserved
	This program is free software; you can redistribute
	it and/or modify it under the same terms as Perl itself.

=cut
