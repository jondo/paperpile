#!/usr/bin/perl

package Catalyst::Plugin::Session::Store;

use strict;
use warnings;

__PACKAGE__;

__END__

=pod

=head1 NAME

Catalyst::Plugin::Session::Store - Base class for session storage
drivers.

=head1 SYNOPSIS

    package Catalyst::Plugin::Session::Store::MyBackend;
    use base qw/Catalyst::Plugin::Session::Store/;

=head1 DESCRIPTION

This class doesn't actually provide any functionality, but when the
C<Catalyst::Plugin::Session> module sets up it will check to see that
C<< YourApp->isa("Catalyst::Plugin::Session::Store") >>. When you write
a session storage plugin you should subclass this module for this
reason. This documentation is intended for authors of session storage 
plugins, not for end users.

=head1 WRITING STORE PLUGINS

All session storage plugins need to adhere to the following interface
specification to work correctly:

=head2 Required Methods

=over 4

=item get_session_data $key

=item store_session_data $key, $data

Retrieve or store session data by key.

C<$data> is currently either a hash reference (for most keys) or an
integer value (for expires), but all value types should be supported.

Keys are in the format C<prefix:id>, where C<prefix> is C<session>,
C<expires>, or C<flash>, and C<id> is always the session ID. Plugins
such as L<Catalyst::Plugin::Session::PerUser> store extensions to this
format, such as C<user:username>.

It is suggested that the store should split on the colon and store the
data more efficiently - the API should remain stable, with the possible
addition of new prefixes in the future.

For example, C<Store::DBI> maps C<expires:id> a column of C<session:id>
by special-casing C<get_session_data> and C<store_session_data> for that
key format, in order to ease the implementation of
C<delete_expired_sessions>.

The only assurance stores are required to make is that given

    $c->store_session_data( $x, $y );

for any $x, 

    $y == $c->get_session_data( $x )

will hold.

=item store_session_data ( $key, $data )

Store a session whose KEY is the first parameter and data is the second
parameter in storage.

The second parameter is a hash reference, which should normally be
serialized (and later deserialized by C<get_session_data>).

=item delete_session_data ( $key )

Delete the session whose KEY is the parameter.

=item delete_expired_sessions

This method is not called by any code at present, but may be called in the
future, as part of a Catalyst-specific maintenance script.

If you are wrapping around a backend which manages its own auto expiry
you can just give this method an empty body.

=back

=head2 Error handling

All errors should be thrown using L<Catalyst::Exception>. Return values
are not checked, and are assumed to be OK. Missing values are not errors.

=head2 Auto-Expiry on the Backend

Storage plugins are encouraged to use C<< $c->session_expires >>, C<<
$c->config('Plugin::Session' => { expires => $val }) >>, or the storage of the
C<expires:$sessionid> key to perform more efficient expiration, but only
for the key prefixes C<session>, C<flash> and C<expires>.

If the backend chooses not to do so, L<Catalyst::Plugin::Session> will
detect expired sessions as they are retrieved and delete them if
necessary.

Note that session store that use this approach may leak disk space,
since nothing will actively delete an expired session. The
C<delete_expired_sessions> method is there so that regularly scheduled
maintenance scripts can give your backend the opportunity to clean up.

=cut


