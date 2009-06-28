package Test::WWW::Mechanize::Catalyst;

use Moose;

use Carp qw/croak/;
require Catalyst::Test; # Do not call import
use Encode qw();
use HTML::Entities;
use Test::WWW::Mechanize;

extends 'Test::WWW::Mechanize', 'Moose::Object';

#use namespace::clean -execept => 'meta';

our $VERSION = '0.51';
our $APP_CLASS;
my $Test = Test::Builder->new();

has catalyst_app => (
  is => 'ro',
  predicate => 'has_catalyst_app',
);

has allow_external => (
  is => 'rw',
  isa => 'Bool',
  default => 0
);

has host => (
  is => 'rw',
  isa => 'Str',
  clearer => 'clear_host',
  predicate => 'has_host',
);

sub new {
  my $class = shift;

  my $args = ref $_[0] ? $_[0] : { @_ };
  
  # Dont let LWP complain about options for our attributes
  my %attr_options = map {
    my $n = $_->init_arg;
    defined $n && exists $args->{$n} 
        ? ( $n => delete $args->{$n} )
        : ( );
  } $class->meta->get_all_attributes;

  my $obj = $class->SUPER::new(%$args);
  my $self = $class->meta->new_object(
    __INSTANCE__ => $obj,
    ($APP_CLASS ? (catalyst_app => $APP_CLASS) : () ),
    %attr_options
  );

  $self->BUILDALL;


  return $self;
}

sub BUILD {
  my ($self) = @_;

  unless ($ENV{CATALYST_SERVER}) {
    croak "catalyst_app attribute is required unless CATALYST_SERVER env variable is set"
      unless $self->has_catalyst_app;
    Class::MOP::load_class($self->catalyst_app)
      unless (Class::MOP::is_class_loaded($self->catalyst_app));
  }
}

sub _make_request {
    my ( $self, $request ) = @_;

    my $response = $self->_do_catalyst_request($request);
    $response->header( 'Content-Base', $response->request->uri )
      unless $response->header('Content-Base');

    $self->cookie_jar->extract_cookies($response) if $self->cookie_jar;

    # fail tests under the Catalyst debug screen
    if (  !$self->{catalyst_debug}
        && $response->code == 500
        && $response->content =~ /on Catalyst \d+\.\d+/ )
    {
        my ($error)
            = ( $response->content =~ /<code class="error">(.*?)<\/code>/s );
        $error ||= "unknown error";
        decode_entities($error);
        $Test->diag("Catalyst error screen: $error");
        $response->content('');
        $response->content_type('');
    }

    # check if that was a redirect
    if (   $response->header('Location')
        && $response->is_redirect
        && $self->redirect_ok( $request, $response ) )
    {

        # remember the old response
        my $old_response = $response;

        # *where* do they want us to redirect to?
        my $location = $old_response->header('Location');

        # no-one *should* be returning non-absolute URLs, but if they
        # are then we'd better cope with it.  Let's create a new URI, using
        # our request as the base.
        my $uri = URI->new_abs( $location, $request->uri )->as_string;

        # make a new response, and save the old response in it
        $response = $self->_make_request( HTTP::Request->new( GET => $uri ) );
        my $end_of_chain = $response;
        while ( $end_of_chain->previous )    # keep going till the end
        {
            $end_of_chain = $end_of_chain->previous;
        }                                          #   of the chain...
        $end_of_chain->previous($old_response);    # ...and add us to it
    } else {
        $response->{_raw_content} = $response->content;
    }

    return $response;
}

sub _do_catalyst_request {
    my ($self, $request) = @_;

    my $uri = $request->uri;
    $uri->scheme('http') unless defined $uri->scheme;
    $uri->host('localhost') unless defined $uri->host;

    $request = $self->prepare_request($request);
    $self->cookie_jar->add_cookie_header($request) if $self->cookie_jar;

    # Woe betide anyone who unsets CATALYST_SERVER
    return $self->_do_remote_request($request)
      if $ENV{CATALYST_SERVER};

    # If there's no Host header, set one.
    unless ($request->header('Host')) {
      my $host = $self->has_host
               ? $self->host
               : $uri->host;

      $request->header('Host', $host);
    }
 
    my $res = $self->_check_external_request($request);
    return $res if $res;

    my @creds = $self->get_basic_credentials( "Basic", $uri );
    $request->authorization_basic( @creds ) if @creds;

    my $response =Catalyst::Test::local_request($self->{catalyst_app}, $request);

    # LWP would normally do this, but we dont get down that far.
    $response->request($request);

    return $response
}

sub _check_external_request {
    my ($self, $request) = @_;

    # If there's no host then definatley not an external request.
    $request->uri->can('host_port') or return;

    if ( $self->allow_external && $request->uri->host_port ne 'localhost:80' ) {
        return $self->SUPER::_make_request($request);
    }
    return undef;
}

sub _do_remote_request {
    my ($self, $request) = @_;

    my $res = $self->_check_external_request($request);
    return $res if $res;

    my $server  = URI->new( $ENV{CATALYST_SERVER} );

    if ( $server->path =~ m|^(.+)?/$| ) {
        my $path = $1;
        $server->path("$path") if $path;    # need to be quoted
    }

    # the request path needs to be sanitised if $server is using a
    # non-root path due to potential overlap between request path and
    # response path.
    if ($server->path) {
        # If request path is '/', we have to add a trailing slash to the
        # final request URI
        my $add_trailing = $request->uri->path eq '/';
        
        my @sp = split '/', $server->path;
        my @rp = split '/', $request->uri->path;
        shift @sp;shift @rp; # leading /
        if (@rp) {
            foreach my $sp (@sp) {
                $sp eq $rp[0] ? shift @rp : last
            }
        }
        $request->uri->path(join '/', @rp);
        
        if ( $add_trailing ) {
            $request->uri->path( $request->uri->path . '/' );
        }
    }

    $request->uri->scheme( $server->scheme );
    $request->uri->host( $server->host );
    $request->uri->port( $server->port );
    $request->uri->path( $server->path . $request->uri->path );
    return $self->SUPER::_make_request($request);
}

sub import {
  my ($class, $app) = @_;

  if (defined $app) {
    Class::MOP::load_class($app)
      unless (Class::MOP::is_class_loaded($app));
    $APP_CLASS = $app; 
  }

}


1;

__END__

=head1 NAME

Test::WWW::Mechanize::Catalyst - Test::WWW::Mechanize for Catalyst

=head1 SYNOPSIS

  # We're in a t/*.t test script...
  use Test::WWW::Mechanize::Catalyst;

  # To test a Catalyst application named 'Catty':
  my $mech = Test::WWW::Mechanize::Catalyst->new(catalyst_app => 'Catty');

  $mech->get_ok("/"); # no hostname needed
  is($mech->ct, "text/html");
  $mech->title_is("Root", "On the root page");
  $mech->content_contains("This is the root page", "Correct content");
  $mech->follow_link_ok({text => 'Hello'}, "Click on Hello");
  # ... and all other Test::WWW::Mechanize methods
  
  # White label site testing
  $mech->host("foo.com");
  $mech->get_ok("/");

=head1 DESCRIPTION

L<Catalyst> is an elegant MVC Web Application Framework.
L<Test::WWW::Mechanize> is a subclass of L<WWW::Mechanize> that incorporates
features for web application testing. The L<Test::WWW::Mechanize::Catalyst>
module meshes the two to allow easy testing of L<Catalyst> applications without
needing to starting up a web server.

Testing web applications has always been a bit tricky, normally
requiring starting a web server for your application and making real HTTP
requests to it. This module allows you to test L<Catalyst> web
applications but does not require a server or issue HTTP
requests. Instead, it passes the HTTP request object directly to
L<Catalyst>. Thus you do not need to use a real hostname:
"http://localhost/" will do. However, this is optional. The following
two lines of code do exactly the same thing:

  $mech->get_ok('/action');
  $mech->get_ok('http://localhost/action');

Links which do not begin with / or are not for localhost can be handled
as normal Web requests - this is handy if you have an external 
single sign-on system. You must set allow_external to true for this:

  $mech->allow_external(1);

You can also test a remote server by setting the environment variable
CATALYST_SERVER; for example:

  $ CATALYST_SERVER=http://example.com/myapp prove -l t

will run the same tests on the application running at
http://example.com/myapp regardless of whether or not you specify
http:://localhost for Test::WWW::Mechanize::Catalyst.    

Furthermore, if you set CATALYST_SERVER, the server will be regarded 
as a remote server even if your links point to localhost. Thus, you
can use Test::WWW::Mechanize::Catalyst to test your live webserver
running on your local machine, if you need to test aspects of your
deployment environment (for example, configuration options in an
http.conf file) instead of just the Catalyst request handling.
    
This makes testing fast and easy. L<Test::WWW::Mechanize> provides
functions for common web testing scenarios. For example:

  $mech->get_ok( $page );
  $mech->title_is( "Invoice Status", "Make sure we're on the invoice page" );
  $mech->content_contains( "Andy Lester", "My name somewhere" );
  $mech->content_like( qr/(cpan|perl)\.org/, "Link to perl.org or CPAN" );

This module supports cookies automatically.

To use this module you must pass it the name of the application. See
the SYNOPSIS above.

Note that Catalyst has a special developing feature: the debug
screen. By default this module will treat responses which are the
debug screen as failures. If you actually want to test debug screens,
please use:

  $mmech->{catalyst_debug} = 1;

An alternative to this module is L<Catalyst::Test>.

=head1 CONSTRUCTOR

=head2 new

Behaves like, and calls, L<WWW::Mechanize>'s C<new> method.  Any params
passed in get passed to WWW::Mechanize's constructor. Note that we
need to pass the name of the Catalyst application to the "use":

  use Test::WWW::Mechanize::Catalyst 'Catty';
  my $mech = Test::WWW::Mechanize::Catalyst->new;

=head1 METHODS

=head2 allow_external

Links which do not begin with / or are not for localhost can be handled
as normal Web requests - this is handy if you have an external 
single sign-on system. You must set allow_external to true for this:

  $m->allow_external(1);

head2 catalyst_app

The name of the Catalyst app which we are testing against. Read-only.

=head2 host

The host value to set the "Host:" HTTP header to, if none is present already in
the request. If not set (default) then Catalyst::Test will set this to
localhost:80

=head2 clear_host

Unset the host attribute.

=head2 has_host

Do we have a value set for the host attribute

=head2 $mech->get_ok($url, [ \%LWP_options ,] $desc)

A wrapper around WWW::Mechanize's get(), with similar options, except the
second argument needs to be a hash reference, not a hash. Returns true or 
false.

=head2 $mech->title_is( $str [, $desc ] )

Tells if the title of the page is the given string.

    $mech->title_is( "Invoice Summary" );

=head2 $mech->title_like( $regex [, $desc ] )

Tells if the title of the page matches the given regex.

    $mech->title_like( qr/Invoices for (.+)/

=head2 $mech->title_unlike( $regex [, $desc ] )

Tells if the title of the page does NOT match the given regex.

    $mech->title_unlike( qr/Invoices for (.+)/

=head2 $mech->content_is( $str [, $desc ] )

Tells if the content of the page matches the given string

=head2 $mech->content_contains( $str [, $desc ] )

Tells if the content of the page contains I<$str>.

=head2 $mech->content_lacks( $str [, $desc ] )

Tells if the content of the page lacks I<$str>.

=head2 $mech->content_like( $regex [, $desc ] )

Tells if the content of the page matches I<$regex>.

=head2 $mech->content_unlike( $regex [, $desc ] )

Tells if the content of the page does NOT match I<$regex>.

=head2 $mech->page_links_ok( [ $desc ] )

Follow all links on the current page and test for HTTP status 200

    $mech->page_links_ok('Check all links');

=head2 $mech->page_links_content_like( $regex,[ $desc ] )

Follow all links on the current page and test their contents for I<$regex>.

    $mech->page_links_content_like( qr/foo/,
      'Check all links contain "foo"' );

=head2 $mech->page_links_content_unlike( $regex,[ $desc ] )

Follow all links on the current page and test their contents do not
contain the specified regex.

    $mech->page_links_content_unlike(qr/Restricted/,
      'Check all links do not contain Restricted');

=head2 $mech->links_ok( $links [, $desc ] )

Check the current page for specified links and test for HTTP status
200.  The links may be specified as a reference to an array containing
L<WWW::Mechanize::Link> objects, an array of URLs, or a scalar URL
name.

    my @links = $mech->find_all_links( url_regex => qr/cnn\.com$/ );
    $mech->links_ok( \@links, 'Check all links for cnn.com' );

    my @links = qw( index.html search.html about.html );
    $mech->links_ok( \@links, 'Check main links' );

    $mech->links_ok( 'index.html', 'Check link to index' );

=head2 $mech->link_status_is( $links, $status [, $desc ] )

Check the current page for specified links and test for HTTP status
passed.  The links may be specified as a reference to an array
containing L<WWW::Mechanize::Link> objects, an array of URLs, or a
scalar URL name.

    my @links = $mech->links();
    $mech->link_status_is( \@links, 403,
      'Check all links are restricted' );

=head2 $mech->link_status_isnt( $links, $status [, $desc ] )

Check the current page for specified links and test for HTTP status
passed.  The links may be specified as a reference to an array
containing L<WWW::Mechanize::Link> objects, an array of URLs, or a
scalar URL name.

    my @links = $mech->links();
    $mech->link_status_isnt( \@links, 404,
      'Check all links are not 404' );

=head2 $mech->link_content_like( $links, $regex [, $desc ] )

Check the current page for specified links and test the content of
each against I<$regex>.  The links may be specified as a reference to
an array containing L<WWW::Mechanize::Link> objects, an array of URLs,
or a scalar URL name.

    my @links = $mech->links();
    $mech->link_content_like( \@links, qr/Restricted/,
        'Check all links are restricted' );

=head2 $mech->link_content_unlike( $links, $regex [, $desc ] )

Check the current page for specified links and test the content of each
does not match I<$regex>.  The links may be specified as a reference to
an array containing L<WWW::Mechanize::Link> objects, an array of URLs,
or a scalar URL name.

    my @links = $mech->links();
    $mech->link_content_like( \@links, qr/Restricted/,
      'Check all links are restricted' );

=head2 follow_link_ok( \%parms [, $comment] )

Makes a C<follow_link()> call and executes tests on the results.
The link must be found, and then followed successfully.  Otherwise,
this test fails.

I<%parms> is a hashref containing the params to pass to C<follow_link()>.
Note that the params to C<follow_link()> are a hash whereas the parms to
this function are a hashref.  You have to call this function like:

    $agent->follow_like_ok( {n=>3}, "looking for 3rd link" );

As with other test functions, C<$comment> is optional.  If it is supplied
then it will display when running the test harness in verbose mode.

Returns true value if the specified link was found and followed
successfully.  The HTTP::Response object returned by follow_link()
is not available.

=head1 CAVEATS

=head2 External Redirects and allow_external

If you use non-fully qualified urls in your test scripts (i.e. anything without
a host, such as C<< ->get_ok( "/foo") >> ) and your app redirects to an
external URL, expect to be bitten once you come back to your application's urls
(it will try to request them on the remote server.) This is due to a limitation
in WWW::Mechanize.

One workaround for this is that if you are expecting to redirect to an external
site, clone the TWMC obeject and use the cloned object for the external
redirect.


=head1 SEE ALSO

Related modules which may be of interest: L<Catalyst>,
L<Test::WWW::Mechanize>, L<WWW::Mechanize>.

=head1 AUTHOR

Ash Berlin C<< <ash@cpan.org> >> (current maintiner)

Original Author: Leon Brocard, C<< <acme@astray.com> >>

=head1 COPYRIGHT

Copyright (C) 2005-8, Leon Brocard

=head1 LICENSE

This module is free software; you can redistribute it or modify it
under the same terms as Perl itself.

