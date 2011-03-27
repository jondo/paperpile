package Catalyst::Engine::HTTP::Prefork::Handler;

use strict;
use base 'Catalyst::Engine::CGI';

use Cookie::XS;
use Data::Dump qw(dump);
use HTTP::Body;
use HTTP::Date qw(time2str);
use HTTP::Headers;
use HTTP::Status qw(status_message);
use IO::Socket qw(:crlf);

use constant DEBUG     => $ENV{CATALYST_PREFORK_DEBUG} || 0;
use constant CHUNKSIZE => 64 * 1024;

sub new {
    my ( $class, $server ) = @_;
    
    bless {
        client => {},
        server => $server,
    }, $class;
}

sub prepare_request {
    my ( $self, $c, $client ) = @_;
    
    $self->{client} = $client;
}

sub prepare_headers {
    my ( $self, $c ) = @_;
    
    # Save time by not bothering to stuff headers in %ENV
    $c->req->headers(
        HTTP::Headers->new( %{ $self->{client}->{headers} } )
    );
}

sub prepare_cookies {
    my ( $self, $c ) = @_;

    if ( my $header = $c->request->header('Cookie') ) {
        # This method is around 8x faster than letting
        # CGI::Simple::Cookie do the parsing in pure perl
        my $cookies = Cookie::XS->parse( $header );
        my $cookie_objs = { 
            map {
                $_ => bless {
                    name  => $_,
                    path  => '/',
                    value => $cookies->{ $_ },
                }, 'CGI::Simple::Cookie';
            } keys %{ $cookies }
        };
        
        $c->req->cookies( $cookie_objs );
    }
}

# We need to override prepare_body for chunked request support.
# This should probably move to Catalyst at some point.
sub prepare_body {
    my ( $self, $c ) = @_;
    
    my $te = $c->request->header('Transfer-Encoding');
    
    if ( $te && $te =~ /^chunked$/i ) {
        DEBUG && warn "[$$] Body data is chunked\n";
        $self->{_chunked_req} = 1;
    }
    else {
        # We can use the normal prepare_body method for a non-chunked body
        return $self->SUPER::prepare_body( $c );
    }
    
    unless ( $c->request->{_body} ) {
        my $type = $c->request->header('Content-Type');
        # with no length, HTTP::Body 1.00+ will treat the content
        # as chunked
        $c->request->{_body} = HTTP::Body->new( $type );
        $c->request->{_body}->{tmpdir} = $c->config->{uploadtmp}
            if exists $c->config->{uploadtmp};
    }
    
    while ( my $buffer = $self->read($c) ) {
        $c->prepare_body_chunk($buffer);
    }
    
    $self->finalize_read($c);
}

sub read {
    my ( $self, $c, $maxlength ) = @_;
    
    # If the request is not chunked, we can use the normal read method
    if ( !$self->{_chunked_req} ) {
        return $self->SUPER::read( $c, $maxlength );
    }
    
    # If HTTP::Body says we're done, don't read
    if ( $c->request->{_body}->state eq 'done' ) {
        return;
    }
    
    my $rc = $self->read_chunk( $c, my $buffer, CHUNKSIZE );
    if ( defined $rc ) {
        return $buffer;
    }
    else {
        Catalyst::Exception->throw(
            message => "Unknown error reading input: $!" );
    }
}    

sub read_chunk {
    my $self = shift;
    my $c    = shift;
    
    my $read;
    
    # If we have any remaining data in the input buffer, send it back first
    if ( $_[0] = $self->{client}->{inputbuf} ) {
        $read = length( $_[0] );
        $self->{client}->{inputbuf} = '';
        
        # XXX: Data::Dump segfaults on 5.8.8 when dumping long strings...
        DEBUG && warn "[$$] read_chunk: Read $read bytes from previous input buffer\n"; # . dump($_[0]) . "\n";
    }
    else {
        $read = $self->SUPER::read_chunk( $c, @_ );
        DEBUG && warn "[$$] read_chunk: Read $read bytes from STDIN\n"; # . dump($_[0]) . "\n";
    }
    
    return $read;
}

sub finalize_read {
    my ( $self, $c ) = @_;
    
    delete $self->{_chunked_req};
    
    return $self->SUPER::finalize_read( $c );
}

sub finalize_headers {
    my ( $self, $c ) = @_;
    
    my $protocol = $c->request->protocol;
    my $status   = $c->response->status;
    my $message  = status_message($status);
    
    my @headers;
    push @headers, "$protocol $status $message";
    
    # Switch on Transfer-Encoding: chunked if we don't know Content-Length.
    if ( $protocol eq 'HTTP/1.1' ) {
        if ( !$c->response->content_length ) {
            if ( $c->response->status !~ /^1\d\d|[23]04$/ ) {
                DEBUG && warn "[$$] Using chunked transfer-encoding to send unknown length body\n";
                $c->response->header( 'Transfer-Encoding' => 'chunked' );
                $self->{_chunked_res} = 1;
            }
        }
        elsif ( my $te = $c->response->header('Transfer-Encoding') ) {
            if ( $te eq 'chunked' ) {
                DEBUG && warn "[$$] Chunked transfer-encoding set for response\n";
                $self->{_chunked_res} = 1;
            }
        }
    }
    
    if ( !$c->response->header('Date') ) {
        $c->response->header( Date => time2str( time() ) );
    }
    
    $c->response->header( Status => $c->response->status );
    
    # Should we keep the connection open?
    if ( $self->{client}->{keepalive} ) {
        $c->response->headers->header( Connection => 'keep-alive' );
    }
    else {
        $c->response->headers->header( Connection => 'close' );
    }
    
    push @headers, $c->response->headers->as_string($CRLF);
    
    # Buffer the headers so they are sent with the first write() call
    # This reduces the number of TCP packets we are sending
    $self->{_header_buf} = join( $CRLF, @headers, '' );
}

sub finalize_body {
    my ( $self, $c ) = @_;
    
    $self->SUPER::finalize_body( $c );
    
    if ( $self->{_chunked_res} ) {
        if ( !$self->{_chunked_done} ) {
            # Write the final '0' chunk
            syswrite STDOUT, "0$CRLF";
        }
        
        delete $self->{_chunked_res};
        delete $self->{_chunked_done};
    } 
}

sub write {
    my ( $self, $c, $buffer ) = @_;

    if ( $self->{_chunked_res} ) {
        my $len = length($buffer);
        
        $buffer = sprintf( "%x", $len ) . $CRLF . $buffer . $CRLF;
        
        # Flag if we wrote an empty chunk
        if ( !$len ) {
            $self->{_chunked_done} = 1;
        }
    }
    
    DEBUG && warn "[$$] Wrote " . length($buffer) . " bytes\n";
    
    $self->SUPER::write( $c, $buffer );
}

1;