package HTTP::HeaderParser::XS;

use 5.008;
use strict;
use warnings;
use Carp;

require Exporter;
use AutoLoader;

our @ISA = qw( Exporter );

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use HTTPHeaders ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	H_REQUEST
	H_RESPONSE
	M_DELETE
	M_GET
	M_OPTIONS
	M_POST
	M_PUT
    M_HEAD
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	H_REQUEST
	H_RESPONSE
	M_DELETE
	M_GET
	M_OPTIONS
	M_POST
	M_PUT
    M_HEAD
);

our $VERSION = '0.20';

our $HTTPCode = {
    200 => 'OK',
    204 => 'No Content',
    206 => 'Partial Content',
    304 => 'Not Modified',
    400 => 'Bad request',
    403 => 'Forbidden',
    404 => 'Not Found',
    416 => 'Request range not satisfiable',
    500 => 'Internal Server Error',
    501 => 'Not Implemented',
    503 => 'Service Unavailable',
};

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&HTTP::HeaderParser::XS::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    if ($error) { croak $error; }
    {
	no strict 'refs';
	# Fixed between 5.005_53 and 5.005_61
#XXX	if ($] >= 5.00561) {
#XXX	    *$AUTOLOAD = sub () { $val };
#XXX	}
#XXX	else {
	    *$AUTOLOAD = sub { $val };
#XXX	}
    }
    goto &$AUTOLOAD;
}

require XSLoader;
XSLoader::load('HTTP::HeaderParser::XS', $VERSION);

# create a very bare response to send to a user (mostly used internally)
sub new_response {
    my $code = $_[1];

    my $msg = $HTTPCode->{$code} || "";
    my $hdr = HTTP::HeaderParser::XS->new(\"HTTP/1.0 $code $msg\r\n\r\n");
    return $hdr;
}

# do some magic to determine content length
sub content_length {
    my HTTP::HeaderParser::XS $self = $_[0];

    if ($self->isRequest()) {
        return 0 if $self->getMethod() == M_HEAD();
    } else {
        my $code = $self->getStatusCode();
        if ($code == 304 || $code == 204 || ($code >= 100 && $code <= 199)) {
            return 0;
        }
    }

    if (defined (my $clen = $self->getHeader('Content-length'))) {
        return $clen+0;
    }

    return undef;
}

sub set_version {
    my HTTP::HeaderParser::XS $self = $_[0];
    my $ver = $_[1];

    die "Bogus version" unless $ver =~ /^(\d+)\.(\d+)$/;

    my ($ver_ma, $ver_mi) = ($1, $2);
    $self->setVersionNumber($ver_ma * 1000 + $ver_mi);

    return $self;
}

sub clone {
    return HTTP::HeaderParser::XS->new( $_[0]->to_string_ref );
}

sub code {
    my HTTP::HeaderParser::XS $self = shift;

    my ($code, $msg) = @_;
    $msg ||= $self->http_code_english($code);
    $self->setCodeText($code, $msg);
}

sub http_code_english {
    my HTTP::HeaderParser::XS $self = shift;
    if (@_) {
        return $HTTPCode->{shift()} || "";
    } else {
        return "" unless $self->response_code;
        return $HTTPCode->{$self->response_code} || "";
    }
}

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

=head1 NAME

HTTP::HeaderParser::XS - an XS extension for processing HTTP headers.

=head1 SYNOPSIS

  use HTTP::HeaderParser::XS;

  my $hdr = HTTP::HeaderParser::XS->new( \"GET / HTTP/1.0\r\nConnection: keep-alive\r\nHost: www.bar.com\r\n\r\n" );

  if ( $hdr->isResponse ) {
    # this is not a response in this simple demo, but it could be
    print "Response code: " . $hdr->getStatusCode . "\n";
    print "Connection header: " . $hdr->getHeader( 'Connection' ) . "\n";

  } else {
    # see if it's a GET request
    if ( $hdr->getMethod == M_GET ) {
      print "GET: " . $hdr->getURI() . "\n";

      # now let's rewrite the host header and rewrite the header :-)
      print "Host header was: " . $hdr->getHeader( 'Host' ) . "\n";
      $hdr->setHeader( 'Host', 'www.foo.com' );

      # show new headers, now that we changed something
      print "New headers:\n";
      print $hdr->getReconstructed . "\n";
      
    } else {
      print "Not a GET request!\n";
    }
  }

=head1 DESCRIPTION

This module parses HTTP headers using a C++ state machine.  (Hence this
being an XS module.)  The goal is to be fast, not necessarily to do everything
you could ever want.

Headers are not static, you can parse them, munge them, or even build them
using this module.  See the SYNOPSIS for more information on how to use this
module.

=head1 KNOWN BUGS

There are no known bugs at this time.  Please report any you find!

=head1 SEE ALSO

There is no place designated for support of this module.  If you would like to
contact the author, please see the email address below.  Or, find him on the
Perl IRC network as 'xb95', usually in various channels.

=head1 AUTHOR

Mark Smith, E<lt>mark@xb95.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004-2008 by Mark Smith.

Copyright (C) 2004 by Danga Interactive, Inc.

Copyright (C) 2005-2007 by Six Apart, Ltd.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
