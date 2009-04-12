use strict;
use warnings;
use Data::Dumper;
use Data::TreeDumper;
use Tree::Simple;
use LWP::UserAgent;
use XML::Simple;
use Encode;
use Test::More 'no_plan';

use lib "../../lib";

BEGIN { use_ok 'Paperpile::Controller::Api::Wp' }

my $api = 'http://localhost:3000/api/wp';

my $ua = LWP::UserAgent->new;

#### /api/wp/ping

my $response = $ua->get("$api/ping");
test_response( $response, 'ping' );

my $data=XMLin($response->content);
ok(exists($data->{version}), "ping: content");

#### /api/wp/list_styles

$response = $ua->get("$api/list_styles");
test_response( $response, 'list_styles' );

$data=XMLin(decode('utf-8',$response->content));
ok(exists($data->{style}), "list_styles: content");

#### /api/wp/search

$response = $ua->get("$api/search?query=&limit=10"); # empty query gets everything
test_response( $response, 'search' );

$data=XMLin(decode('utf-8',$response->content));
ok(exists($data->{result}), "search: content");


sub test_response {

  my ( $response, $name ) = @_;

  is( $response->content_type,     "text/xml", "$name: content type" );
  is( $response->content_encoding, "utf-8",    "$name: content encoding" );
  is( $response->status_line,      "200 OK",   "$name: content status" );

}

