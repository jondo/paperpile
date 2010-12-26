#!/usr/bin/perl -w

use lib "../lib";
use strict;
use FindBin;
use Data::Dumper;
use Paperpile::Utils;
use File::Spec::Functions;
use Test::More 'no_plan';

use Bibutils;
use Paperpile::Plugins::Export::DB;

### User agent

my $browser  = Paperpile::Utils->get_browser;
my $response = $browser->get('http://google.com');
my $content  = $response->content;

ok( $browser->isa('LWP::UserAgent'), 'Requesting user agent object.' );
like( $content, qr/google/, "Fetching google homepage using user agent" );

### Paths

my $current_script = $FindBin::Bin;
my $home           = Paperpile::Utils->home;

is( catfile( $home, 't' ), $current_script, "home()" );
is( Paperpile::Utils->path_to('t'), $current_script, "path_to" );

### Config file

my $config = Paperpile::Utils->get_config;

is( $config->{name}, 'Paperpile', "get_config" );

### Database encoding/decoding

my $bu = Bibutils->new(
  in_file    => 'data/test.mods',
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

my $dbfile   = 'data/export.db';
my $settings = { export_file => $dbfile };
my $export   = Paperpile::Plugins::Export::DB->new(
  data     => [@data],
  settings => $settings
);
$export->write;

open( FILE, "<data/export.db" ) || die("Could not read data/export.db ($!)");
binmode(FILE);

$content = '';
my $buff;

while ( read( FILE, $buff, 8 * 2**10 ) ) {
  $content .= $buff;
}

my $encoded = undef;
$encoded = Paperpile::Utils->encode_db('data/export.db');

ok( $encoded, 'Encoding db' );

my $decoded = Paperpile::Utils->decode_db($encoded);

is( $decoded, $content, 'Decoding db' );

