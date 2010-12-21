use strict;
use warnings;
use Data::Dumper;
use Data::TreeDumper;
use Tree::Simple;
use LWP::UserAgent;
use HTTP::Request;
use XML::Simple;
use Encode;
use Test::More 'no_plan';
use Bibutils;

use lib "../../lib";

use Paperpile::Utils;
use Paperpile::Plugins::Export::DB;

BEGIN { use_ok 'Paperpile::Controller::Api::Wp' }

my $api = 'http://localhost:3000/api/wp';

my $ua = LWP::UserAgent->new;

#
# /api/wp/ping
#

my $response = $ua->get("$api/ping");
test_response( $response, 'ping' );

my $data = XMLin( $response->content );
ok( exists( $data->{version} ), "ping: content" );

#
# /api/wp/list_styles
#

$response = $ua->get("$api/list_styles");
test_response( $response, 'list_styles' );

$data = XMLin( decode( 'utf-8', $response->content ) );
ok( exists( $data->{style} ), "list_styles: content" );

#
# /api/wp/open
#

my $xml = <<"END";
<xml>
    <documentID>AGTAD234OEX12D45</documentID>
    <documentLibrary></documentLibrary>
</xml>
END

my $request = HTTP::Request->new( POST => "$api/open" );
$request->content_type('text/xml');
$request->content($xml);
$response = $ua->request($request);
test_response( $response, 'open' );

ok( -e "../../tmp/wp/AGTAD234OEX12D45.db", 'open: creating temporary database file (empty).' );

my $documentLibrary = create_test_library();

$xml = <<"END";
<xml>
    <documentID>AGTAD234OEX12D45</documentID>
    <documentLibrary>$documentLibrary</documentLibrary>
</xml>
END

$request = HTTP::Request->new( POST => "$api/open" );
$request->content_type('text/xml');
$request->content($xml);
$response = $ua->request($request);

ok( -e "../../tmp/wp/AGTAD234OEX12D45.db",
  'open: creating temporary database file (from document data).' );

#
# /api/wp/search
#

$response =
  $ua->get("$api/search?query=&limit=10&documentID=AGTAD234OEX12D45"); # empty query gets everything
test_response( $response, 'search' );

$data = XMLin( decode( 'utf-8', $response->content ), KeyAttr => [] );
ok( exists( $data->{result} ), "search: content" );

# Get three ids from paperpile database and 'document library'
# There must be at least 3 items in the database for the test to work
my @ids;
foreach my $result ( @{ $data->{result} } ) {
  push @ids, $result->{id};
}
my ( $id1, $id2, $id3 ) = @ids;                                        # ids from 'document library'
my ( $id4, $id5, $id6 ) = reverse @ids;                                # ids from paperpile database

#
# /api/wp/format_citations
#

$xml = <<"END";
<xml>
    <documentID>AGTAD234OEX12D45</documentID>
    <style>Nature</style>
    <citations>
      <citation><item>$id1</item> <item>$id2</item></citation>
      <citation><item>$id3</item></citation>
      <citation><item>$id4</item> <item>$id5</item></citation>
      <citation><item>$id6</item></citation>
    </citations>
</xml>
END

$request = HTTP::Request->new( POST => "$api/format_citations" );
$request->content_type('text/xml');
$request->content($xml);
$response = $ua->request($request);
test_response( $response, 'format_citations' );

$data = XMLin( decode( 'utf-8', $response->content ), ForceArray => ['item'] );

ok( exists( $data->{citations} ),             "format: exists citations" );
ok( exists( $data->{ids} ),                   "format: exists ids" );
ok( exists( $data->{bibliography} ),          "format: exists bibliography" );
ok( exists( $data->{documentLibraryString} ), "format: exists documentLibraryString" );

is( @{ $data->{citations}->{citation} }, 4, "format: correct number of citations" );
is( @{ $data->{ids}->{citation} },       4, "format: correct number of items for ids" );

is_deeply(
  $data->{ids}->{citation}->[0]->{item},
  [ $id1, $id2 ],
  "format: ids returned and correclty grouped (1)"
);
is_deeply( $data->{ids}->{citation}->[1]->{item},
  [$id3], "format: ids returned and correclty grouped (2)" );

unlink('../data/tmp.db');
unlink '../../tmp/wp/AGTAD234OEX12D45.db';


sub test_response {

  my ( $response, $name ) = @_;

  is( $response->content_type,     "text/xml", "$name: content type" );
  is( $response->content_encoding, "utf-8",    "$name: content encoding" );
  is( $response->status_line,      "200 OK",   "$name: content status" );

}

sub create_test_library {

  my $bu = Bibutils->new(
    in_file    => '../data/test.mods',
    out_file   => '',
    in_format  => Bibutils::MODSIN,
    out_format => Bibutils::MODSOUT,
  );

  $bu->read;

  my @data = ();

  foreach my $entry ( @{ $bu->get_data } ) {
    my $pub = Paperpile::Library::Publication->new;
    $pub->_build_from_bibutils($entry);
    push @data, $pub;
  }

  my $dbfile   = '../data/tmp.db';
  my $settings = { export_file => $dbfile };
  my $export   = Paperpile::Plugins::Export::DB->new(
    data     => [@data],
    settings => $settings
  );
  $export->write;

  my $encoded = Paperpile::Utils->encode_db('../data/tmp.db');

  return $encoded;

}

