#!/usr/bin/perl

package Catalyst::Plugin::Session::Test::Store;

use strict;
use warnings;

use utf8;

use Test::More;
use File::Temp;
use File::Spec;

use Catalyst ();

sub import {
    shift;
    my %args = @_;

    plan tests => 19 + ($args{extra_tests} || 0);

    my $backend = $args{backend};
    my $cfg     = $args{config};

    my $p = "Session::Store::$backend";
    use_ok( my $m = "Catalyst::Plugin::$p" );

    isa_ok( bless( {}, $m ), "Catalyst::Plugin::Session::Store" );

    {
        package # Hide from PAUSE
            Catalyst::Plugin::SessionStateTest;
        use base qw/Catalyst::Plugin::Session::State/;

        no strict 'refs';

        sub get_session_id {
            my $c = shift;
            ${ ref($c) . "::session_id" };
        }

        sub set_session_id {
            my ( $c, $sid ) = @_;
            ${ ref($c) . "::session_id" } = $sid;
        }

        sub delete_session_id {
            my $c = shift;
            undef ${ ref($c) . "::session_id" };
        }
    }

    {

        package # Hide from PAUSE
            SessionStoreTest;
        use Catalyst qw/Session SessionStateTest/;
        push our (@ISA), $m;

        use strict;
        use warnings;

        use Test::More;

        sub create_session : Global {
            my ( $self, $c ) = @_;
            ok( !$c->session_is_valid, "no session id yet" );
            ok( $c->session,           "session created" );
            ok( $c->session_is_valid,  "with a session id" );

            $c->session->{magic} = "møøse";
        }

        sub recover_session : Global {
            my ( $self, $c ) = @_;
            ok( $c->session_is_valid, "session id exists" );
            is( $c->sessionid, our $session_id,
                "and is the one we saved in the last action" );
            ok( $c->session, "a session exists" );
            is( $c->session->{magic},
                "møøse",
                "and it contains what we put in on the last attempt" );
            $c->delete_session("user logout");
        }

        sub after_session : Global {
            my ( $self, $c ) = @_;
            ok( !$c->session_is_valid,      "no session id" );
            ok( !$c->session->{magic},      "session data not restored" );
            ok( !$c->session_delete_reason, "no reason for deletion" );
        }

        @{ __PACKAGE__->config->{'Plugin::Session'} }{ keys %$cfg } = values %$cfg;

        { __PACKAGE__->setup; }; # INSANE HACK 
    }

    {

        package # Hide from PAUSE
            SessionStoreTest2;
        use Catalyst qw/Session SessionStateTest/;
        push our (@ISA), $m;

        our $VERSION = "123";

        use Test::More;

        sub create_session : Global {
            my ( $self, $c ) = @_;

            $c->session->{magic} = "møøse";
        }

        sub recover_session : Global {
            my ( $self, $c ) = @_;

            ok( !$c->session_is_valid, "session is gone" );

            is(
                $c->session_delete_reason,
                "session expired",
                "reason is that the session expired"
            );

            ok( !$c->session->{magic}, "no saved data" );
        }

        __PACKAGE__->config->{'Plugin::Session'}{expires} = 0;

        @{ __PACKAGE__->config->{'Plugin::Session'} }{ keys %$cfg } = values %$cfg;

        { __PACKAGE__->setup; }; # INSANE HACK
    }

    use Test::More;

    can_ok( $m, "get_session_data" );
    can_ok( $m, "store_session_data" );
    can_ok( $m, "delete_session_data" );
    can_ok( $m, "delete_expired_sessions" );

    {

        package # Hide from PAUSE
            t1;
        use Catalyst::Test "SessionStoreTest";

        # idiotic void context warning workaround
        
        my $x = get("/create_session");
        $x = get("/recover_session");
        $x = get("/after_session");
    }

    {

        package # Hide fram PAUSE
            t2;
        use Catalyst::Test "SessionStoreTest2";

        my $x = get("/create_session");
        sleep 1;    # let the session expire
        $x = get("/recover_session");
    }
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Catalyst::Plugin::Session::Test::Store - Reusable sanity for session storage
engines.

=head1 SYNOPSIS

    #!/usr/bin/perl

    use Catalyst::Plugin::Session::Test::Store (
        backend => "FastMmap",
        config => {
            storage => "/tmp/foo",
        },
    );

=head1 DESCRIPTION

=cut


