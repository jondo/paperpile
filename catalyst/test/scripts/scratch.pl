#!../../perl5/linux64/bin/paperperl -w

## Add code to generate test data or ad-hoc tests here.

use strict;
use lib "../../lib";

use Paperpile;
use Paperpile::Formats::Bibtex;
use Data::Dumper;
use YAML;

### Format data in YAML

my $r = Paperpile::Formats::Bibtex->new(file=>"/home/wash/examples/diss.bib");

my $data = $r->read;

foreach my $pub (@$data){

  ## Don't show helper fields starting with underscore and empty
  ## fields
  foreach my $key (keys %$pub){
    if ($key=~/^_/ || $pub->{$key} eq ''){
      delete($pub->{$key});
    }
  }
  print Dump($pub);
}
