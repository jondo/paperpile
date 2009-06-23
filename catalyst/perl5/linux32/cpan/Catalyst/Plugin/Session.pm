#!/usr/bin/perl

package Catalyst::Plugin::Session;

use Moose;
with 'MooseX::Emulate::Class::Accessor::Fast';
use MRO::Compat;
use Catalyst::Exception ();
use Digest              ();
use overload            ();
use Object::Signature   ();
use Carp;

use namespace::clean -except => 'meta';

our $VERSION = '0.22';

my @session_data_accessors; # used in delete_session

__PACKAGE__->mk_accessors(
        "_session_delete_reason",
        @session_data_accessors = qw/
          _sessionid
          _session
          _session_expires
          _extended_session_expires
          _session_data_sig
          _flash
          _flash_keep_keys
          _flash_key_hashes
          _tried_loading_session_id
          _tried_loading_session_data
          _tried_loading_session_expires
          _tried_loading_flash_data
          /
);


sub setup {
    my $c = shift;

    $c->maybe::next::method(@_);

    $c->check_session_plugin_requirements;
    $c->setup_session;

    return $c;
}

sub check_session_plugin_requirements {
    my $c = shift;

    unless ( $c->isa("Catalyst::Plugin::Session::State")
        && $c->isa("Catalyst::Plugin::Session::Store") )
    {
        my $err =
          (     "The Session plugin requires both Session::State "
              . "and Session::Store plugins to be used as well." );

        $c->log->fatal($err);
        Catalyst::Exception->throw($err);
    }
}

sub setup_session {
    my $c = shift;

    my $cfg = ( $c->config->{session} ||= {} );

    %$cfg = (
        expires        => 7200,
        verify_address => 0,
        %$cfg,
    );

    $c->maybe::next::method();
}

sub prepare_action {
    my $c = shift;

    if (    $c->config->{session}{flash_to_stash}
        and $c->sessionid
        and my $flash_data = $c->flash )
    {
        @{ $c->stash }{ keys %$flash_data } = values %$flash_data;
    }

    $c->maybe::next::method(@_);
}

sub finalize_headers {
    my $c = shift;

    # fix cookie before we send headers
    $c->_save_session_expires;

    return $c->maybe::next::method(@_);
}

sub finalize_body {
    my $c = shift;

    # We have to finalize our session *before* $c->engine->finalize_xxx is called,
    # because we do not want to send the HTTP response before the session is stored/committed to
    # the session database (or whatever Session::Store you use).
    $c->finalize_session;

    return $c->maybe::next::method(@_);
}

sub finalize_session {
    my $c = shift;

    $c->maybe::next::method(@_);

    $c->_save_session_id;
    $c->_save_session;
    $c->_save_flash;

    $c->_clear_session_instance_data;
}

sub _save_session_id {
    my $c = shift;

    # we already called set when allocating
    # no need to tell the state plugins anything new
}

sub _save_session_expires {
    my $c = shift;

    if ( defined($c->_session_expires) ) {
        my $expires = $c->session_expires; # force extension

        my $sid = $c->sessionid;
        $c->store_session_data( "expires:$sid" => $expires );
    }
}

sub _save_session {
    my $c = shift;

    if ( my $session_data = $c->_session ) {

        no warnings 'uninitialized';
        if ( Object::Signature::signature($session_data) ne
            $c->_session_data_sig )
        {
            $session_data->{__updated} = time();
            my $sid = $c->sessionid;
            $c->store_session_data( "session:$sid" => $session_data );
        }
    }
}

sub _save_flash {
    my $c = shift;

    if ( my $flash_data = $c->_flash ) {

        my $hashes = $c->_flash_key_hashes || {};
        my $keep = $c->_flash_keep_keys || {};
        foreach my $key ( keys %$hashes ) {
            if ( !exists $keep->{$key} and Object::Signature::signature( \$flash_data->{$key} ) eq $hashes->{$key} ) {
                delete $flash_data->{$key};
            }
        }
        
        my $sid = $c->sessionid;

        my $session_data = $c->_session;
        if (%$flash_data) {
            $session_data->{__flash} = $flash_data;
        }
        else {
            delete $session_data->{__flash};
        }
        $c->_session($session_data);
        $c->_save_session;
    }
}

sub _load_session_expires {
    my $c = shift;
    return $c->_session_expires if $c->_tried_loading_session_expires;
    $c->_tried_loading_session_expires(1);

    if ( my $sid = $c->sessionid ) {
        my $expires = $c->get_session_data("expires:$sid") || 0;

        if ( $expires >= time() ) {
            $c->_session_expires( $expires );
            return $expires;
        } else {
            $c->delete_session( "session expired" );
            return 0;
        }
    }

    return;
}

sub _load_session {
    my $c = shift;
    return $c->_session if $c->_tried_loading_session_data;
    $c->_tried_loading_session_data(1);

    if ( my $sid = $c->sessionid ) {
        if ( $c->_load_session_expires ) {    # > 0

            my $session_data = $c->get_session_data("session:$sid") || return;
            $c->_session($session_data);

            no warnings 'uninitialized';    # ne __address
            if (   $c->config->{session}{verify_address}
                && $session_data->{__address} ne $c->request->address )
            {
                $c->log->warn(
                        "Deleting session $sid due to address mismatch ("
                      . $session_data->{__address} . " != "
                      . $c->request->address . ")"
                );
                $c->delete_session("address mismatch");
                return;
            }

            $c->log->debug(qq/Restored session "$sid"/) if $c->debug;
            $c->_session_data_sig( Object::Signature::signature($session_data) ) if $session_data;
            $c->_expire_session_keys;

            return $session_data;
        }
    }

    return;
}

sub _load_flash {
    my $c = shift;
    return $c->_flash if $c->_tried_loading_flash_data;
    $c->_tried_loading_flash_data(1);

    if ( my $sid = $c->sessionid ) {

        my $session_data = $c->session;
        $c->_flash($session_data->{__flash});

        if ( my $flash_data = $c->_flash )
        {
            $c->_flash_key_hashes({ map { $_ => Object::Signature::signature( \$flash_data->{$_} ) } keys %$flash_data });
            
            return $flash_data;
        }
    }

    return;
}

sub _expire_session_keys {
    my ( $c, $data ) = @_;

    my $now = time;

    my $expire_times = ( $data || $c->_session || {} )->{__expire_keys} || {};
    foreach my $key ( grep { $expire_times->{$_} < $now } keys %$expire_times ) {
        delete $c->_session->{$key};
        delete $expire_times->{$key};
    }
}

sub _clear_session_instance_data {
    my $c = shift;
    $c->$_(undef) for @session_data_accessors;
    $c->maybe::next::method(@_); # allow other plugins to hook in on this
}

sub delete_session {
    my ( $c, $msg ) = @_;

    $c->log->debug("Deleting session" . ( defined($msg) ? "($msg)" : '(no reason given)') ) if $c->debug;

    # delete the session data
    if ( my $sid = $c->sessionid ) {
        $c->delete_session_data("${_}:${sid}") for qw/session expires flash/;
        $c->delete_session_id($sid);
    }

    # reset the values in the context object
    # see the BEGIN block
    $c->_clear_session_instance_data;

    $c->_session_delete_reason($msg);
}

sub session_delete_reason {
    my $c = shift;

    $c->session_is_valid; # check that it was loaded

    $c->_session_delete_reason(@_);
}

sub session_expires {
    my $c = shift;

    if ( defined( my $expires = $c->_extended_session_expires ) ) {
        return $expires;
    } elsif ( defined( $expires = $c->_load_session_expires ) ) {
        return $c->extend_session_expires( $expires );
    } else {
        return 0;
    }
}

sub extend_session_expires {
    my ( $c, $expires ) = @_;
    $c->_extended_session_expires( my $updated = $c->calculate_extended_session_expires( $expires ) );
    $c->extend_session_id( $c->sessionid, $updated );
    return $updated;
}

sub calculate_initial_session_expires {
    my $c = shift;
    return ( time() + $c->config->{session}{expires} );
}

sub calculate_extended_session_expires {
    my ( $c, $prev ) = @_;
    $c->calculate_initial_session_expires;
}

sub reset_session_expires {
    my ( $c, $sid ) = @_;
    
    my $exp = $c->calculate_initial_session_expires;
    $c->_session_expires( $exp );
    $c->_extended_session_expires( $exp );
    $exp;
}

sub sessionid {
    my $c = shift;
    
    return $c->_sessionid || $c->_load_sessionid;
}

sub _load_sessionid {
    my $c = shift;
    return if $c->_tried_loading_session_id;
    $c->_tried_loading_session_id(1);

    if ( defined( my $sid = $c->get_session_id ) ) {
        if ( $c->validate_session_id($sid) ) {
            # temporarily set the inner key, so that validation will work
            $c->_sessionid($sid);
            return $sid;
        } else {
            my $err = "Tried to set invalid session ID '$sid'";
            $c->log->error($err);
            Catalyst::Exception->throw($err);
        }
    }

    return;
}

sub session_is_valid {
    my $c = shift;

    # force a check for expiry, but also __address, etc
    if ( $c->_load_session ) {
        return 1;
    } else {
        return;
    }
}

sub validate_session_id {
    my ( $c, $sid ) = @_;

    $sid and $sid =~ /^[a-f\d]+$/i;
}

sub session {
    my $c = shift;

    $c->_session || $c->_load_session || do {
        $c->create_session_id_if_needed;
        $c->initialize_session_data;
    };
}

sub keep_flash {
    my ( $c, @keys ) = @_;
    my $href = $c->_flash_keep_keys || $c->_flash_keep_keys({});
    (@{$href}{@keys}) = ((undef) x @keys);
}

sub _flash_data { 
    my $c = shift;
    $c->_flash || $c->_load_flash || do {
        $c->create_session_id_if_needed;
        $c->_flash( {} );
    };
}

sub _set_flash {
    my $c = shift;
    if (@_) {
        my $items = @_ > 1 ? {@_} : $_[0];
        croak('flash takes a hash or hashref') unless ref $items;
        @{ $c->_flash }{ keys %$items } = values %$items;
    }
}

sub flash {
    my $c = shift;
    $c->_flash_data;
    $c->_set_flash(@_);
    return $c->_flash;
}

sub clear_flash {
    my $c = shift;
    
    #$c->delete_session_data("flash:" . $c->sessionid); # should this be in here? or delayed till finalization?
    $c->_flash_key_hashes({});
    $c->_flash_keep_keys({});
    $c->_flash({});
}

sub session_expire_key {
    my ( $c, %keys ) = @_;

    my $now = time;
    @{ $c->session->{__expire_keys} }{ keys %keys } =
      map { $now + $_ } values %keys;
}

sub initialize_session_data {
    my $c = shift;

    my $now = time;

    return $c->_session(
        {
            __created => $now,
            __updated => $now,

            (
                $c->config->{session}{verify_address}
                ? ( __address => $c->request->address )
                : ()
            ),
        }
    );
}

sub generate_session_id {
    my $c = shift;

    my $digest = $c->_find_digest();
    $digest->add( $c->session_hash_seed() );
    return $digest->hexdigest;
}

sub create_session_id_if_needed {
    my $c = shift;
    $c->create_session_id unless $c->sessionid;
}

sub create_session_id {
    my $c = shift;
    
    my $sid = $c->generate_session_id;

    $c->log->debug(qq/Created session "$sid"/) if $c->debug;

    $c->_sessionid($sid);
    $c->reset_session_expires;
    $c->set_session_id($sid);

    return $sid;
}

my $counter;

sub session_hash_seed {
    my $c = shift;

    return join( "", ++$counter, time, rand, $$, {}, overload::StrVal($c), );
}

my $usable;

sub _find_digest () {
    unless ($usable) {
        foreach my $alg (qw/SHA-1 SHA-256 MD5/) {
            if ( eval { Digest->new($alg) } ) {
                $usable = $alg;
                last;
            }
        }
        Catalyst::Exception->throw(
                "Could not find a suitable Digest module. Please install "
              . "Digest::SHA1, Digest::SHA, or Digest::MD5" )
          unless $usable;
    }

    return Digest->new($usable);
}

sub dump_these {
    my $c = shift;

    (
        $c->maybe::next::method(),

        $c->sessionid
        ? ( [ "Session ID" => $c->sessionid ], [ Session => $c->session ], )
        : ()
    );
}


sub get_session_id { shift->maybe::next::method(@_) }
sub set_session_id { shift->maybe::next::method(@_) }
sub delete_session_id { shift->maybe::next::method(@_) }
sub extend_session_id { shift->maybe::next::method(@_) }

__PACKAGE__;

__END__

=pod

=head1 NAME

Catalyst::Plugin::Session - Generic Session plugin - ties together server side storage and client side state required to maintain session data.

=head1 SYNOPSIS

    # To get sessions to "just work", all you need to do is use these plugins:

    use Catalyst qw/
      Session
      Session::Store::FastMmap
      Session::State::Cookie
      /;

    # you can replace Store::FastMmap with Store::File - both have sensible
    # default configurations (see their docs for details)

    # more complicated backends are available for other scenarios (DBI storage,
    # etc)


    # after you've loaded the plugins you can save session data
    # For example, if you are writing a shopping cart, it could be implemented
    # like this:

    sub add_item : Local {
        my ( $self, $c ) = @_;

        my $item_id = $c->req->param("item");

        # $c->session is a hash ref, a bit like $c->stash
        # the difference is that it' preserved across requests

        push @{ $c->session->{items} }, $item_id;

        $c->forward("MyView");
    }

    sub display_items : Local {
        my ( $self, $c ) = @_;

        # values in $c->session are restored
        $c->stash->{items_to_display} =
          [ map { MyModel->retrieve($_) } @{ $c->session->{items} } ];

        $c->forward("MyView");
    }

=head1 DESCRIPTION

The Session plugin is the base of two related parts of functionality required
for session management in web applications.

The first part, the State, is getting the browser to repeat back a session key,
so that the web application can identify the client and logically string
several requests together into a session.

The second part, the Store, deals with the actual storage of information about
the client. This data is stored so that the it may be revived for every request
made by the same client.

This plugin links the two pieces together.

=head1 RECOMENDED BACKENDS

=over 4

=item Session::State::Cookie

The only really sane way to do state is using cookies.

=item Session::Store::File

A portable backend, based on Cache::File.

=item Session::Store::FastMmap

A fast and flexible backend, based on Cache::FastMmap.

=back

=head1 METHODS

=over 4

=item sessionid

An accessor for the session ID value.

=item session

Returns a hash reference that might contain unserialized values from previous
requests in the same session, and whose modified value will be saved for future
requests.

This method will automatically create a new session and session ID if none
exists.

=item session_expires

=item session_expires $reset

This method returns the time when the current session will expire, or 0 if
there is no current session. If there is a session and it already expired, it
will delete the session and return 0 as well.

If the C<$reset> parameter is true, and there is a session ID the expiry time
will be reset to the current time plus the time to live (see
L</CONFIGURATION>). This is used when creating a new session.

=item flash

This is like Ruby on Rails' flash data structure. Think of it as a stash that
lasts for longer than one request, letting you redirect instead of forward.

The flash data will be cleaned up only on requests on which actually use
$c->flash (thus allowing multiple redirections), and the policy is to delete
all the keys which haven't changed since the flash data was loaded at the end
of every request.

    sub moose : Local {
        my ( $self, $c ) = @_;

        $c->flash->{beans} = 10;
        $c->response->redirect( $c->uri_for("foo") );
    }

    sub foo : Local {
        my ( $self, $c ) = @_;

        my $value = $c->flash->{beans};

        # ...

        $c->response->redirect( $c->uri_for("bar") );
    }

    sub bar : Local {
        my ( $self, $c ) = @_;

        if ( exists $c->flash->{beans} ) { # false
        
        }
    }

=item clear_flash

Zap all the keys in the flash regardless of their current state.

=item keep_flash @keys

If you want to keep a flash key for the next request too, even if it hasn't
changed, call C<keep_flash> and pass in the keys as arguments.

=item delete_session REASON

This method is used to invalidate a session. It takes an optional parameter
which will be saved in C<session_delete_reason> if provided.

NOTE: This method will B<also> delete your flash data.

=item session_delete_reason

This accessor contains a string with the reason a session was deleted. Possible
values include:

=over 4

=item *

C<address mismatch>

=item *

C<session expired>

=back

=item session_expire_key $key, $ttl

Mark a key to expire at a certain time (only useful when shorter than the
expiry time for the whole session).

For example:

    __PACKAGE__->config->{session}{expires} = 1000000000000; # forever

    # later

    $c->session_expire_key( __user => 3600 );

Will make the session data survive, but the user will still be logged out after
an hour.

Note that these values are not auto extended.

=back

=head1 INTERNAL METHODS

=over 4

=item setup

This method is extended to also make calls to
C<check_session_plugin_requirements> and C<setup_session>.

=item check_session_plugin_requirements

This method ensures that a State and a Store plugin are also in use by the
application.

=item setup_session

This method populates C<< $c->config->{session} >> with the default values
listed in L</CONFIGURATION>.

=item prepare_action

This method is extended.

Its only effect is if the (off by default) C<flash_to_stash> configuration
parameter is on - then it will copy the contents of the flash to the stash at
prepare time.

=item finalize_headers

This method is extended and will extend the expiry time before sending
the response.

=item finalize_body

This method is extended and will call finalize_session before the other
finalize_body methods run.  Here we persist the session data if a session exists.

=item initialize_session_data

This method will initialize the internal structure of the session, and is
called by the C<session> method if appropriate.

=item create_session_id

Creates a new session ID using C<generate_session_id> if there is no session ID
yet.

=item validate_session_id SID

Make sure a session ID is of the right format.

This currently ensures that the session ID string is any amount of case
insensitive hexadecimal characters.

=item generate_session_id

This method will return a string that can be used as a session ID. It is
supposed to be a reasonably random string with enough bits to prevent
collision. It basically takes C<session_hash_seed> and hashes it using SHA-1,
MD5 or SHA-256, depending on the availability of these modules.

=item session_hash_seed

This method is actually rather internal to generate_session_id, but should be
overridable in case you want to provide more random data.

Currently it returns a concatenated string which contains:

=over 4

=item * A counter

=item * The current time

=item * One value from C<rand>.

=item * The stringified value of a newly allocated hash reference

=item * The stringified value of the Catalyst context object

=back

in the hopes that those combined values are entropic enough for most uses. If
this is not the case you can replace C<session_hash_seed> with e.g.

    sub session_hash_seed {
        open my $fh, "<", "/dev/random";
        read $fh, my $bytes, 20;
        close $fh;
        return $bytes;
    }

Or even more directly, replace C<generate_session_id>:

    sub generate_session_id {
        open my $fh, "<", "/dev/random";
        read $fh, my $bytes, 20;
        close $fh;
        return unpack("H*", $bytes);
    }

Also have a look at L<Crypt::Random> and the various openssl bindings - these
modules provide APIs for cryptographically secure random data.

=item finalize_session

Clean up the session during C<finalize>.

This clears the various accessors after saving to the store.

=item dump_these

See L<Catalyst/dump_these> - ammends the session data structure to the list of
dumped objects if session ID is defined.


=item calculate_extended_session_expires

=item calculate_initial_session_expires

=item create_session_id_if_needed

=item delete_session_id

=item extend_session_expires

=item extend_session_id

=item get_session_id

=item reset_session_expires

=item session_is_valid

=item set_session_id

=back

=head1 USING SESSIONS DURING PREPARE

The earliest point in time at which you may use the session data is after
L<Catalyst::Plugin::Session>'s C<prepare_action> has finished.

State plugins must set $c->session ID before C<prepare_action>, and during
C<prepare_action> L<Catalyst::Plugin::Session> will actually load the data from
the store.

    sub prepare_action {
        my $c = shift;

        # don't touch $c->session yet!

        $c->NEXT::prepare_action( @_ );

        $c->session;  # this is OK
        $c->sessionid; # this is also OK
    }

=head1 CONFIGURATION

    $c->config->{session} = {
        expires => 1234,
    };

All configuation parameters are provided in a hash reference under the
C<session> key in the configuration hash.

=over 4

=item expires

The time-to-live of each session, expressed in seconds. Defaults to 7200 (two
hours).

=item verify_address

When true, C<<$c->request->address>> will be checked at prepare time. If it is
not the same as the address that initiated the session, the session is deleted.

Defaults to false.

=item flash_to_stash

This option makes it easier to have actions behave the same whether they were
forwarded to or redirected to. On prepare time it copies the contents of
C<flash> (if any) to the stash.

=back

=head1 SPECIAL KEYS

The hash reference returned by C<< $c->session >> contains several keys which
are automatically set:

=over 4

=item __expires

This key no longer exists. Use C<session_expires> instead.

=item __updated

The last time a session was saved to the store.

=item __created

The time when the session was first created.

=item __address

The value of C<< $c->request->address >> at the time the session was created.
This value is only populated if C<verify_address> is true in the configuration.

=back

=head1 CAVEATS

=head2 Round the Robin Proxies

C<verify_address> could make your site inaccessible to users who are behind
load balanced proxies. Some ISPs may give a different IP to each request by the
same client due to this type of proxying. If addresses are verified these
users' sessions cannot persist.

To let these users access your site you can either disable address verification
as a whole, or provide a checkbox in the login dialog that tells the server
that it's OK for the address of the client to change. When the server sees that
this box is checked it should delete the C<__address> special key from the
session hash when the hash is first created.

=head2 Race Conditions

In this day and age where cleaning detergents and Dutch football (not the
American kind) teams roam the plains in great numbers, requests may happen
simultaneously. This means that there is some risk of session data being
overwritten, like this:

=over 4

=item 1.

request a starts, request b starts, with the same session ID

=item 2.

session data is loaded in request a

=item 3.

session data is loaded in request b

=item 4.

session data is changed in request a

=item 5.

request a finishes, session data is updated and written to store

=item 6.

request b finishes, session data is updated and written to store, overwriting
changes by request a

=back

If this is a concern in your application, a soon-to-be-developed locking
solution is the only safe way to go. This will have a bigger overhead.

For applications where any given user is only making one request at a time this
plugin should be safe enough.

=head1 AUTHORS

Andy Grundman

Christian Hansen

Yuval Kogman, C<nothingmuch@woobling.org>

Sebastian Riedel

Tomas Doran (t0m) C<bobtfish@bobtfish.net> (current maintainer)

Sergio Salvi

And countless other contributers from #catalyst. Thanks guys!

=head1 COPYRIGHT & LICENSE

    Copyright (c) 2005 the aforementioned authors. All rights
    reserved. This program is free software; you can redistribute
    it and/or modify it under the same terms as Perl itself.

=cut


