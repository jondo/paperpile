package Catalyst::Engine::HTTP::Prefork;

use strict;
use base 'Net::Server::PreFork';

use Catalyst::Engine::HTTP::Prefork::Handler;

use Data::Dump qw(dump);
use HTTP::Response;
use HTTP::Status qw(status_message);
use IO::Select;
use IO::Socket qw(:crlf);
use HTTP::HeaderParser::XS;
use Socket;

use constant DEBUG        => $ENV{CATALYST_PREFORK_DEBUG} || 0;
use constant CHUNKSIZE    => 64 * 1024;
use constant READ_TIMEOUT => 5;

our $VERSION = '0.50';

sub run {
    my ( $self, $class, $port, $host, $options ) = @_;
    
    $self->{appclass} = $class;
    $self->{options}  = $options || {};
    $self->{env}      = \%ENV;
    
    # Change the Catalyst Engine class to our engine handler
    my $engine = Catalyst::Engine::HTTP::Prefork::Handler->new( $self->{server} );
    $self->{appclass}->engine( $engine );
    
    # Restore ARGV since Getopt has eaten it and Net::Server needs it
    # for proper restart support
    @ARGV = @{ $options->{argv} };
    
    $self->SUPER::run(
        port                       => $port || 3000,
        host                       => $host || '*',
        serialize                  => 'flock',
        log_level                  => DEBUG ? 4 : 1,
        min_servers                => $options->{min_servers}       || 5,
        min_spare_servers          => $options->{min_spare_servers} || 2,
        max_spare_servers          => $options->{max_spare_servers} || 10,
        max_servers                => $options->{max_servers}       || 50,
        max_requests               => $options->{max_requests}      || 1000,
        leave_children_open_on_hup => $options->{restart_graceful}  || 0,
    );
}

sub pre_loop_hook {
    my $self = shift;
    
    # Init watcher process if necessary
    if ( $self->{options}->{restart} ) {
        require Catalyst::Engine::HTTP::Prefork::Restarter;
        Catalyst::Engine::HTTP::Prefork::Restarter->init( $self->{options} );
    }
    
    my $host = $self->{server}->{host}->[0];
    my $port = $self->{server}->{port}->[0];
    
    my $addr = $host ne '*' ? inet_aton($host) : INADDR_ANY;
    if ( $addr eq INADDR_ANY ) {
        require Sys::Hostname;
        $host = lc Sys::Hostname::hostname();
    }
    else {
        $host = gethostbyaddr( $addr, AF_INET ) || inet_ntoa($addr);
    }
    
    my $url = "http://$host";
    $url .= ":$port" unless $port == 80;

    print "You can connect to your server at $url\n";
}

# The below methods run in the child process

sub post_accept_hook {
    my $self = shift;
    
    $self->{client} = {
        headerbuf => '',
        inputbuf  => '',
        keepalive => 1,
    };
}

sub process_request {
    my $self = shift;
    my $conn = $self->{server}->{client};

    while ( $self->{client}->{keepalive} ) {
        last if !$conn->connected;
        
        # Read until we see all headers
        last if !$self->_read_headers;
    
        # Parse headers
        my $h = HTTP::HeaderParser::XS->new( \delete $self->{client}->{headerbuf} );
    
        if ( !$h ) {
            # Bad request
            DEBUG && warn "[$$] Bad request\n";
            $self->_http_error(400);
            last;
        }
    
        # Initialize CGI environment
        my $uri = $h->request_uri();
        my ( $path, $query_string ) = split /\?/, $uri, 2;
    
        my $version = $h->version_number();
        my $proto   = sprintf( "HTTP/%d.%d", int( $version / 1000 ), $version % 1000 );
  
        local %ENV = (
            PATH_INFO       => $path         || '',
            QUERY_STRING    => $query_string || '',
            REMOTE_ADDR     => $self->{server}->{peeraddr},
            REMOTE_HOST     => $self->{server}->{peerhost} || $self->{server}->{peeraddr},
            REQUEST_METHOD  => $h->request_method() || '',
            SERVER_NAME     => $self->{server}->{sockaddr}, # XXX: needs to be resolved?
            SERVER_PORT     => $self->{server}->{port}->[0],
            SERVER_PROTOCOL => $proto,
            %{ $self->{env} },
        );
    
        # Add headers
        my $headers = $h->getHeaders();
        $self->{client}->{headers} = $headers;
        
        # prepare_connection and prepare_path need a few headers in %ENV
        $ENV{HTTP_X_FORWARDED_FOR}  = $headers->{'X-Forwarded-For'} 
            if $headers->{'X-Forwarded-For'};
        $ENV{HTTP_X_FORWARDED_HOST} = $headers->{'X-Forwarded-Host'} 
            if $headers->{'X-Forwarded-Host'};
    
        # Determine whether we will keep the connection open after the request
        my $connection = $headers->{Connection};
        if ( $proto && $proto eq 'HTTP/1.0' ) {
            if ( $connection && $connection =~ /^keep-alive$/i ) {
                # Keep-alive only with explicit header in HTTP/1.0
                $self->{client}->{keepalive} = 1;
            }
            else {
                $self->{client}->{keepalive} = 0;
            }
        }
        elsif ( $proto && $proto eq 'HTTP/1.1' ) {
            if ( $connection && $connection =~ /^close$/i ) {
                $self->{client}->{keepalive} = 0;
            }
            else {
                # Keep-alive assumed in HTTP/1.1
                $self->{client}->{keepalive} = 1;
            }
            
            # Do we need to send 100 Continue?
            if ( $headers->{Expect} ) {
                if ( $headers->{Expect} eq '100-continue' ) {
                    syswrite STDOUT, 'HTTP/1.1 100 Continue' . $CRLF . $CRLF;
                    DEBUG && warn "[$$] Sent 100 Continue response\n";
                }
                else {
                    DEBUG && warn "[$$] Invalid Expect header, returning 417\n";
                    $self->_http_error( 417, 'HTTP/1.1' );
                    last;
                }
            }
            
            # Check for an absolute request and determine the proper Host value
            if ( $ENV{PATH_INFO} =~ /^http/i ) {
                my ($host, $path) = $ENV{PATH_INFO} =~ m{^http://([^/]+)(/.+)}i;
                $ENV{HTTP_HOST} = $host;
                $ENV{PATH_INFO} = $path;
                DEBUG && warn "[$$] Absolute path request, host: $host, path: $path\n";
            }
            elsif ( $headers->{Host} ) {
                $ENV{HTTP_HOST} = $headers->{Host};
            }
            else {
                # No host, bad request
                DEBUG && warn "[$$] Bad request, HTTP/1.1 without Host header\n";
                $self->_http_error( 400, 'HTTP/1.1' );
                last;
            }
        }
    
        # Pass flow control to Catalyst
        $self->{appclass}->handle_request( $self->{client} );
    
        DEBUG && warn "[$$] Request done\n";
    
        if ( $self->{client}->{keepalive} ) {
            # If we still have data in the input buffer it may be a pipelined request
            if ( $self->{client}->{inputbuf} ) {
                if ( $self->{client}->{inputbuf} =~ /^(?:GET|HEAD)/ ) {
                    if ( DEBUG ) {
                        warn "Pipelined GET/HEAD request in input buffer: " 
                            . dump( $self->{client}->{inputbuf} ) . "\n";
                    }
                
                    # Continue processing the input buffer
                    next;
                }
                else {
                    # Input buffer just has junk, clear it
                    if ( DEBUG ) {
                        warn "Clearing junk from input buffer: "
                            . dump( $self->{client}->{inputbuf} ) . "\n";
                    }
                    
                    $self->{client}->{inputbuf} = '';
                }
            }
            
            DEBUG && warn "[$$] Waiting on previous connection for keep-alive request...\n";
            
            my $sel = IO::Select->new($conn);
            last unless $sel->can_read(1);
        }
    }
    
    DEBUG && warn "[$$] Closing connection\n";
}

sub _read_headers {
    my $self = shift;
    
    eval {
        local $SIG{ALRM} = sub { die "Timed out\n"; };
        
        alarm( READ_TIMEOUT );
        
        while (1) {
            # Do we have a full header in the buffer?
            # This is before sysread so we don't read if we have a pipelined request
            # waiting in the buffer
            last if $self->{client}->{inputbuf} =~ /$CRLF$CRLF/s;
            
            # If not, read some data
            my $read = sysread STDIN, my $buf, CHUNKSIZE;
    
            if ( !defined $read || $read == 0 ) {
                die "Read error: $!\n";
            }
    
            if ( DEBUG ) {
                warn "[$$] Read $read bytes: " . dump($buf) . "\n";
            }
            
            $self->{client}->{inputbuf} .= $buf;
        }
    };
    
    alarm(0);
    
    if ( $@ ) {
        if ( $@ =~ /Timed out/ ) {
            DEBUG && warn "[$$] Client connection timed out\n";
            return;
        }
    
        if ( $@ =~ /Read error/ ) {
            DEBUG && warn "[$$] Read error: $!\n";
            return;
        }
    }
    
    # Pull out the complete header into a new buffer
    $self->{client}->{headerbuf} = $self->{client}->{inputbuf};
    
    # Save any left-over data, possibly body data or pipelined requests
    $self->{client}->{inputbuf} =~ s/.*?$CRLF$CRLF//s;
    
    return 1;
}

sub _http_error {
    my ( $self, $code, $protocol, $reason ) = @_;
    
    my $status   = $code || 500;
    my $message  = status_message($status);
    my $response = HTTP::Response->new( $status => $message );
    $response->protocol( $protocol || 'HTTP/1.0' );
    $response->content_type( 'text/plain' );
    $response->header( Connection => 'close' );
    $response->date( time() );

    if ( !$reason ) {
        $reason = $message;
    }
    
    my $msg = "$status $reason";

    $response->content_length( length($msg) );
    $response->content( $msg );

    syswrite STDOUT, $response->as_string($CRLF);
}

1;
__END__

=head1 NAME

Catalyst::Engine::HTTP::Prefork - High-performance pre-forking Catalyst engine

=head1 SYNOPIS

    CATALYST_ENGINE='HTTP::Prefork' script/yourapp_server.pl

=head1 DESCRIPTION

This engine is designed to run as a standalone Catalyst server, without
requiring the use of another web server.  It's goals are high-performance,
HTTP/1.1 compliance, and robustness.  It is also suitable for use as a
faster development server with support for automatic restarting.

This engine is designed to replace the L<Catalyst::Engine::HTTP::POE> engine,
which is now deprecated.

=head1 RESTART SUPPORT

This engine supports the same restart options as L<Catalyst::Engine::HTTP>.
The server may also be restarted by sending it a HUP signal.

=head1 HTTP/1.1 support

This engine fully supports the following HTTP/1.1 features:

=head2 Chunked Requests

Chunked body data is handled transparently by L<HTTP::Body>.

=head2 Chunked Responses

By setting the Transfer-Encoding header to 'chunked', you can indicate you
would like the response to be sent to the client as a chunked response.  Also,
any responses without a content-length will be sent chunked.

=head2 Pipelined Requests

Browsers sending any number of pipelined requests will be handled properly.

=head2 Keep-Alive

Keep-alive is supported for both HTTP/1.1 (by default) and HTTP/1.0 (if a
Connection: keep-alive header is present in the request).

=head1 CUSTOMIZATION

Additional options may be passed to the engine by modifying
yourapp_server.pl to send additional items to the run() method.

=head2 min_servers

The minimum number of servers to keep running.  Defaults to 5.

=head2 min_spare_servers

The minimum number of servers to have waiting for requests. Minimum and
maximum numbers should not be set too close to each other or the server will
fork and kill children too often.  Defaults to 2.

=head2 max_spare_servers

The maximum number of servers to have waiting for requests.  Defaults to 10.

=head2 max_servers

The maximum number of child servers to start.  Defaults to 50.

=head2 max_requests

Restart a child after it has served this many requests.  Defaults to 1000.
Note that setting this value to 0 will not cause the child to serve unlimited
requests.  This is a limitation of Net::Server and may be fixed in a future
version.

=head2 restart_graceful

This enables Net::Server's leave_children_open_on_hup option.  If set, the parent
will not attempt to close child processes if the parent receives a SIGHUP.  Each
child will exit as soon as possible after processing the current request if any.

=head1 AUTHOR

Andy Grundman, <andy@hybridized.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
