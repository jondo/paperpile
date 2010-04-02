package HTML::Mason::CGIHandler;

use strict;
use warnings;

use HTML::Mason;
use HTML::Mason::Utils;
use CGI;
use File::Spec;
use Params::Validate qw(:all);
use HTML::Mason::Exceptions;
use HTML::Mason::FakeApache;

use Class::Container;
use base qw(Class::Container);

use HTML::Mason::MethodMaker
    ( read_write => [ qw( interp ) ] );

use vars qw($VERSION);

# Why do we have a version?  I'm glad you asked.  See, dummy me
# stupidly referenced it in the Subclassing docs _and_ the book.  It's
# needed in order to dynamically have a request subclass change its
# parent properly to work with CGIHandler or ApacheHandler.  It
# doesn't really matter what the version is, as long as it's a true
# value.  - dave
$VERSION = '1.00';


__PACKAGE__->valid_params
    (
     interp => { isa => 'HTML::Mason::Interp' },
    );

__PACKAGE__->contained_objects
    (
     interp => 'HTML::Mason::Interp',
     cgi_request => { class   => 'HTML::Mason::FakeApache', # $r
                      delayed => 1 },
    );


sub new {
    my $package = shift;

    my %p = @_;
    my $self = $package->SUPER::new(comp_root => $ENV{DOCUMENT_ROOT},
                                    request_class => 'HTML::Mason::Request::CGI',
                                    error_mode => 'output',
                                    error_format => 'html',
                                    %p);

    $self->{has_custom_out_method} = $p{out_method} ? 1 : 0;

    $self->interp->compiler->add_allowed_globals('$r');
    
    return $self;
}

sub handle_request {
    my $self = shift;
    $self->_handler( { comp => $ENV{PATH_INFO} }, @_ );
}

sub handle_comp {
    my ($self, $comp) = (shift, shift);
    $self->_handler( { comp => $comp }, @_ );
}

sub handle_cgi_object {
    my ($self, $cgi) = (shift, shift);
    $self->_handler( { comp => $cgi->path_info,
                       cgi       => $cgi },
                     @_);
}

sub _handler {
    my ($self, $p) = (shift, shift);

    my $r = $self->create_delayed_object('cgi_request', cgi => $p->{cgi});
    $self->interp->set_global('$r', $r);

    # hack for testing
    if (@_) {
        $self->{output} = '';
        $self->interp->out_method( \$self->{output} );
    } elsif (! $self->{has_custom_out_method}) {
        my $sent_headers = 0;

        my $out_method = sub {
            # Send headers if they have not been sent by us or by user.
            # We use instance here because if we store $request we get a
            # circular reference and a big memory leak.
            if (!$sent_headers and HTML::Mason::Request->instance->auto_send_headers) {
                $r->send_http_header();
                $sent_headers = 1;
            }

            # We could perhaps install a new, faster out_method here that
            # wouldn't have to keep checking whether headers have been
            # sent and what the $r->method is.  That would require
            # additions to the Request interface, though.

            print STDOUT grep {defined} @_;
        };

        $self->interp->out_method($out_method);
    }

    $self->interp->delayed_object_params('request', cgi_request => $r);

    my %args = $self->request_args($r);

    my @result;
    if (wantarray) {
        @result = eval { $self->interp->exec($p->{comp}, %args) };
    } elsif ( defined wantarray ) {
        $result[0] = eval { $self->interp->exec($p->{comp}, %args) };
    } else {
        eval { $self->interp->exec($p->{comp}, %args) };
    }

    if (my $err = $@) {
        my $retval = isa_mason_exception($err, 'Abort')   ? $err->aborted_value  :
                     isa_mason_exception($err, 'Decline') ? $err->declined_value :
                     rethrow_exception $err;

        # Unlike under mod_perl, we cannot simply return a 301 or 302
        # status and let Apache send headers, we need to explicitly
        # send this header ourself.
        $r->send_http_header if $retval && grep { $retval eq $_ } ( 200, 301, 302 );

        return $retval;
    }

    if (@_) {
        # This is a secret feature, and should stay secret (or go
        # away) because it's just a hack for the test suite.
        $_[0] .= $r->http_header . $self->{output};
    }

    return wantarray ? @result : defined wantarray ? $result[0] : undef;
}

# This is broken out in order to make subclassing easier.
sub request_args {
    my ($self, $r) = @_;

    return $r->params;
}


###########################################################
package HTML::Mason::Request::CGI;
# Subclass for HTML::Mason::Request object $m

use HTML::Mason::Exceptions;
use HTML::Mason::Request;
use base qw(HTML::Mason::Request);

use Params::Validate qw(BOOLEAN);
Params::Validate::validation_options( on_fail => sub { param_error( join '', @_ ) } );

__PACKAGE__->valid_params
    ( cgi_request => { isa => 'HTML::Mason::FakeApache' },

      auto_send_headers => { parse => 'boolean', type => BOOLEAN, default => 1,
                             descr => "Whether HTTP headers should be auto-generated" },
    );

use HTML::Mason::MethodMaker
    ( read_only  => [ 'cgi_request' ],
      read_write => [ 'auto_send_headers' ] );

sub cgi_object {
    my $self = shift;
    return $self->{cgi_request}->query(@_);
}

#
# Override this method to send HTTP headers if necessary.
#
sub exec
{
    my $self = shift;
    my $r = $self->cgi_request;
    my $retval;

    eval { $retval = $self->SUPER::exec(@_) };

    if (my $err = $@)
    {
	$retval = isa_mason_exception($err, 'Abort')   ? $err->aborted_value  :
                  isa_mason_exception($err, 'Decline') ? $err->declined_value :
                  rethrow_exception $err;
    }

    # On a success code, send headers if they have not been sent and
    # if we are the top-level request. Since the out_method sends
    # headers, this will typically only apply after $m->abort.
    if (!$self->is_subrequest
        and $self->auto_send_headers
        and !$r->http_header_sent
        and (!$retval or $retval==200)) {
        $r->send_http_header();
    }

    return $retval;
}

sub redirect {
    my $self = shift;
    my $url = shift;
    my $status = shift || 302;

    $self->clear_buffer;

    $self->{cgi_request}->header_out( Location => $url );
    $self->{cgi_request}->header_out( Status => $status );

    $self->abort;
}

1;
__END__

=head1 NAME

HTML::Mason::CGIHandler - Use Mason in a CGI environment

=head1 SYNOPSIS

In httpd.conf or .htaccess:

    <LocationMatch "\.html$">
        Action html-mason /cgi-bin/mason_handler.cgi
        AddHandler html-mason .html
    </LocationMatch>
    <LocationMatch "^/cgi-bin/">
        RemoveHandler .html
    </LocationMatch>
    <FilesMatch "(autohandler|dhandler)$">
        Order allow,deny
        Deny from all
    </FilesMatch>

A script at /cgi-bin/mason_handler.pl :

   #!/usr/bin/perl
   use HTML::Mason::CGIHandler;

   my $h = HTML::Mason::CGIHandler->new
    (
     data_dir  => '/home/jethro/code/mason_data',
     allow_globals => [qw(%session $u)],
    );

   $h->handle_request;

A .html component somewhere in the web server's document root:

   <%args>
    $mood => 'satisfied'
   </%args>
   % $r->err_header_out(Location => "http://blahblahblah.com/moodring/$mood.html");
   ...

=head1 DESCRIPTION

This module lets you execute Mason components in a CGI environment.
It lets you keep your top-level components in the web server's
document root, using regular component syntax and without worrying
about the particular details of invoking Mason on each request.

If you want to use Mason components from I<within> a regular CGI
script (or any other Perl program, for that matter), then you don't
need this module.  You can simply follow the directions in
the L<Using Mason from a standalone script|HTML::Mason::Admin/Using Mason from a standalone script> section of the administrator's manual.

This module also provides an C<$r> request object for use inside
components, similar to the Apache request object under
C<HTML::Mason::ApacheHandler>, but limited in functionality.  Please
note that we aim to replicate the C<mod_perl> functionality as closely
as possible - if you find differences, do I<not> depend on them to
stay different.  We may fix them in a future release.  Also, if you
need some missing functionality in C<$r>, let us know, we might be
able to provide it.

Finally, this module alters the C<HTML::Mason::Request> object C<$m> to
provide direct access to the CGI query, should such access be necessary.

=head2 C<HTML::Mason::CGIHandler> Methods

=over 4

=item * new()

Creates a new handler.  Accepts any parameter that the Interpreter
accepts.

If no C<comp_root> parameter is passed to C<new()>, the component root
will be C<$ENV{DOCUMENT_ROOT}>.

=item * handle_request()

Handles the current request, reading input from C<$ENV{QUERY_STRING}>
or C<STDIN> and sending headers and component output to C<STDOUT>.
This method doesn't accept any parameters.  The initial component
will be the one specified in C<$ENV{PATH_INFO}>.

=item * handle_comp()

Like C<handle_request()>, but the first (only) parameter is a
component path or component object.  This is useful within a
traditional CGI environment, in which you're essentially using Mason
as a templating language but not an application server.

C<handle_component()> will create a CGI query object, parse the query
parameters, and send the HTTP header and component output to STDOUT.
If you want to handle those parts yourself, see
the L<Using Mason from a standalone script|HTML::Mason::Admin/Using Mason from a standalone script> section of the administrator's manual.

=item * handle_cgi_object()

Also like C<handle_request()>, but this method takes only a CGI object
as its parameter.  This can be quite useful if you want to use this
module with CGI::Fast.

The component path will be the value of the CGI object's
C<path_info()> method.

=item * request_args()

Given an C<HTML::Mason::FakeApache> object, this method is expected to
return a hash containing the arguments to be passed to the component.
It is a separate method in order to make it easily overrideable in a
subclass.

=item * interp()

Returns the Mason Interpreter associated with this handler.  The
Interpreter lasts for the entire lifetime of the handler.

=back

=head2 $r Methods

=over 4

=item * headers_in()

This works much like the C<Apache> method of the same name. In an array
context, it will return a C<%hash> of response headers. In a scalar context,
it will return a reference to the case-insensitive hash blessed into the
C<HTML::Mason::FakeTable> class. The values initially populated in this hash are
extracted from the CGI environment variables as best as possible. The pattern
is to merely reverse the conversion from HTTP headers to CGI variables as
documented here: L<http://cgi-spec.golux.com/draft-coar-cgi-v11-03-clean.html#6.1>.

=item * header_in()

This works much like the C<Apache> method of the same name. When passed the
name of a header, returns the value of the given incoming header. When passed
a name and a value, sets the value of the header. Setting the header to
C<undef> will actually I<unset> the header (instead of setting its value to
C<undef>), removing it from the table of headers returned from future calls to
C<headers_in()> or C<header_in()>.

=item * headers_out()

This works much like the C<Apache> method of the same name. In an array
context, it will return a C<%hash> of response headers. In a scalar context,
it will return a reference to the case-insensitive hash blessed into the
C<HTML::Mason::FakeTable> class. Changes made to this hash will be made to the
headers that will eventually be passed to the C<CGI> module's C<header()>
method.

=item * header_out()

This works much like the C<Apache> method of the same name.  When
passed the name of a header, returns the value of the given outgoing
header.  When passed a name and a value, sets the value of the header.
Setting the header to C<undef> will actually I<unset> the header
(instead of setting its value to C<undef>), removing it from the table
of headers that will be sent to the client.

The headers are eventually passed to the C<CGI> module's C<header()>
method.

=item * err_headers_out()

This works much like the C<Apache> method of the same name. In an array
context, it will return a C<%hash> of error response headers. In a scalar
context, it will return a reference to the case-insensitive hash blessed into
the C<HTML::Mason::FakeTable> class. Changes made to this hash will be made to
the error headers that will eventually be passed to the C<CGI> module's
C<header()> method.

=item * err_header_out()

This works much like the C<Apache> method of the same name. When passed the
name of a header, returns the value of the given outgoing error header. When
passed a name and a value, sets the value of the error header. Setting the
header to C<undef> will actually I<unset> the header (instead of setting its
value to C<undef>), removing it from the table of headers that will be sent to
the client.

The headers are eventually passed to the C<CGI> module's C<header()> method.

One header currently gets special treatment - if you set a C<Location>
header, you'll cause the C<CGI> module's C<redirect()> method to be
used instead of the C<header()> method.  This means that in order to
do a redirect, all you need to do is:

 $r->err_header_out(Location => 'http://redirect.to/here');

You may be happier using the C<< $m->redirect >> method, though,
because it hides most of the complexities of sending headers and
getting the status code right.

=item * content_type()

When passed an argument, sets the content type of the current request
to the value of the argument.  Use this method instead of setting a
C<Content-Type> header directly with C<header_out()>.  Like
C<header_out()>, setting the content type to C<undef> will remove any
content type set previously.

When called without arguments, returns the value set by a previous
call to C<content_type()>.  The behavior when C<content_type()> hasn't
already been set is undefined - currently it returns C<undef>.

If no content type is set during the request, the default MIME type
C<text/html> will be used.

=item * method()

Returns the request method used for the current request, e.g., "GET", "POST",
etc.

=item * http_header()

This method returns the outgoing headers as a string, suitable for
sending to the client.

=item * send_http_header()

Sends the outgoing headers to the client.

=item * notes()

This works much like the C<Apache> method of the same name. When passed
a C<$key> argument, it returns the value of the note for that key. When
passed a C<$value> argument, it stores that value under the key. Keys are
case-insensitive, and both the key and the value must be strings. When
called in a scalar context with no C<$key> argument, it returns a hash
reference blessed into the C<HTML::Mason::FakeTable> class.

=item * pnotes()

Like C<notes()>, but takes any scalar as an value, and stores the
values in a case-sensitive hash.

=item * subprocess_env()

Works like the C<Apache> method of the same name, but is simply populated with
the current values of the environment. Still, it's useful, because values can
be changed and then seen by later components, but the environment itself
remains unchanged. Like the C<Apache> method, it will reset all of its values
to the current environment again if it's called without a C<$key> argument.

=item * params()

This method returns a hash containing the parameters sent by the
client.  Multiple parameters of the same name are represented by array
references.  If both POST and query string arguments were submitted,
these will be merged together.

=back

=head2 Added C<$m> methods

The C<$m> object provided in components has all the functionality of
the regular C<HTML::Mason::Request> object C<$m>, and the following:

=over 4

=item * cgi_object()

Returns the current C<CGI> request object.  This is handy for
processing cookies or perhaps even doing HTML generation (but is that
I<really> what you want to do?).  If you pass an argument to this
method, you can set the request object to the argument passed.  Use
this with care, as it may affect components called after the current
one (they may check the content length of the request, for example).

Note that the ApacheHandler class (for using Mason under mod_perl)
also provides a C<cgi_object()> method that does the same thing as
this one.  This makes it easier to write components that function
equally well under CGIHandler and ApacheHandler.

=item * cgi_request()

Returns the object that is used to emulate Apache's request object.
In other words, this is the object that C<$r> is set to when you use
this class.

=back

=head2 C<HTML::Mason::FakeTable> Methods

This class emulates the behavior of the C<Apache::Table> class, and is
used to store manage the tables of values for the following attributes
of <$r>:

=over 4

=item headers_in

=item headers_out

=item err_headers_out

=item notes

=item subprocess_env

=back

C<HTML::Mason::FakeTable> is designed to behave exactly like C<Apache::Table>,
and differs in only one respect. When a given key has multiple values in an
C<Apache::Table> object, one can fetch each of the values for that key using
Perl's C<each> operator:

  while (my ($k, $v) = each %{$r->headers_out}) {
      push @cookies, $v if lc $k eq 'set-cookie';
  }

If anyone knows how Apache::Table does this, let us know! In the meantime, use
C<get()> or C<do()> to get at all of the values for a given key (C<get()> is
much more efficient, anyway).

Since the methods named for these attributes return an
C<HTML::Mason::FakeTable> object hash in a scalar reference, it seemed only
fair to document its interface.

=over 4

=item * new()

Returns a new C<HTML::Mason::FakeTable> object. Any parameters passed
to C<new()> will be added to the table as initial values.

=item * add()

Adds a new value to the table. If the value did not previously exist under the
given key, it will be created. Otherwise, it will be added as a new value to
the key.

=item * clear()

Clears the table of all values.

=item * do()

Pass a code reference to this method to have it iterate over all of the
key/value pairs in the table. Keys will multiple values will trigger the
execution of the code reference multiple times for each value. The code
reference should expect two arguments: a key and a value. Iteration terminates
when the code reference returns false, to be sure to have it return a true
value if you wan it to iterate over every value in the table.

=item * get()

Gets the value stored for a given key in the table. If a key has multiple
values, all will be returned when C<get()> is called in an array context, and
only the first value when it is called in a scalar context.

=item * merge()

Merges a new value with an existing value by concatenating the new value onto
the existing. The result is a comma-separated list of all of the values merged
for a given key.

=item * set()

Takes key and value arguments and sets the value for that key. Previous values
for that key will be discarded. The value must be a string, or C<set()> will
turn it into one. A value of C<undef> will have the same behavior as
C<unset()>.

=item * unset()

Takes a single key argument and deletes that key from the table, so that none
of its values will be in the table any longer.

=back

=head1 SEE ALSO

L<HTML::Mason|HTML::Mason>,
L<HTML::Mason::Admin|HTML::Mason::Admin>,
L<HTML::Mason::ApacheHandler|HTML::Mason::ApacheHandler>

=cut
