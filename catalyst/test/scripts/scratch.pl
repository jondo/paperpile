#!../../perl5/linux64/bin/paperperl -w

## Add code to generate test data or ad-hoc tests here.

BEGIN {$ENV{CATALYST_DEBUG}=0}

use strict;
use lib "../../lib";

use Paperpile;
use Paperpile::Model::Library;
use Paperpile::Utils;

use Data::Dumper;
use YAML;
use Time::HiRes qw( gettimeofday tv_interval);


my $start = [gettimeofday];

foreach my $i (0..10){

  my $model = Paperpile::Utils->get_library_model;
  my $count = $model->fulltext_count("RNA", 0);
  my $data = $model->fulltext_search("RNA", 0, 25,"CREATED DESC", 0, 1);

}

my $elapsed = tv_interval ( $start );

print STDERR "$elapsed\n";


