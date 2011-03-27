use strict;
use warnings;
use Data::Dumper;
use Test::More 'no_plan';
use lib "../../../lib";

BEGIN { use_ok 'Paperpile::Plugins::Import::GoogleScholar' }

binmode STDOUT, ":utf8";    # avoid unicode errors when printing to STDOUT

my $plugin = Paperpile::Plugins::Import::GoogleScholar->new( query => 'Washietl' );

$plugin->connect;

like( $plugin->total_entries, qr/\d+/, 'Connect and retrieve number of hits.' );

my $page = $plugin->page( 0, 10 );

# Assumes that 'Washietl' is an author in the first search result,
# which is likely but not guaranteed.
like( $page->[0]->_authors_display, qr/Washietl/, 'Get results page.' );

is( $plugin->find_sha1( $page->[0]->sha1 ), $page->[0], 'find_sha1' );

my $pub=$page->[0];
$pub = $plugin->complete_details($pub);
like( $pub->authors, qr/Washietl/, 'Complete details' );
is( $plugin->find_sha1( $pub->sha1 ), $pub, 'find_sha1 with updated entries' );



