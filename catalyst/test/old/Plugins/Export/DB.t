use strict;
use warnings;
use Data::Dumper;
use Test::More 'no_plan';
use Bibutils;
use lib "../../../lib";

BEGIN { use_ok 'Paperpile::Plugins::Export::DB' }

### Read example data from MODS file

my $bu = Bibutils->new(
  in_file    => '../../data/test.mods',
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

## Export to database file

my $dbfile   = '../../data/export.db';
my $settings = { export_file => $dbfile };
my $export   = Paperpile::Plugins::Export::DB->new(
  data     => [@data],
  settings => $settings
);
$export->write;

ok( -e $dbfile, "Writing output file." );

## Re-import and check content

my $import = Paperpile::Plugins::Import::DB->new( file => $dbfile );
$import->connect();
my $imported = $import->page( 0, 1000 );

my @original_sha1 = ();
push @original_sha1, $_->sha1 foreach @data;
@original_sha1 = sort @original_sha1;

my @new_sha1 = ();
push @new_sha1, $_->sha1 foreach @$imported;
@new_sha1 = sort @new_sha1;

is_deeply( \@original_sha1, \@new_sha1, 'Checking content.' );

unlink $dbfile;
