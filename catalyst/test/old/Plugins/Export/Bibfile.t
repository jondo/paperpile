use strict;
use warnings;
use Data::Dumper;
use Test::More 'no_plan';
use Bibutils;
use lib "../../../lib";

BEGIN { use_ok 'Paperpile::Plugins::Export::Bibfile' }

my $bu = Bibutils->new(
  in_file    => '../../data/test.bib',
  out_file   => '',
  in_format  => Bibutils::BIBTEXIN,
  out_format => Bibutils::BIBTEXOUT,
);

$bu->read;

my @data = ();

foreach my $entry ( @{ $bu->get_data } ) {
  my $pub = Paperpile::Library::Publication->new;
  $pub->_build_from_bibutils($entry);
  push @data, $pub;
}

### Writing to file

my $settings={ out_file => '../../data/export.bib',
               out_format => 'BIBTEX',
             };

my $export = Paperpile::Plugins::Export::Bibfile->new( data => [@data],
                                                       settings=> $settings);
$export->write;

open(INFILE,"<../../data/export.bib") or die('No file was created.');
my $content='';
$content.=$_ foreach (<INFILE>);
(my $count)=($content=~tr/@/@/);

is($count, scalar @data, "Exporting file.");

### Settings

$settings={ out_file => '../../data/export.bib',
            out_format => 'BIBTEX',
            bibout_whitespace=>1,
            bibout_brackets=>1,
          };

$export = Paperpile::Plugins::Export::Bibfile->new( data => [@data],
                                                    settings=> $settings);

$export->write;

open(INFILE,"<../../data/export.bib") or die('No file was created during settings test.');
$content='';
$content.=$_ foreach (<INFILE>);

# Check if whitespace is included in input
ok($content=~/^\s+author =/m,"Settings");

unlink("../../data/export.bib");
