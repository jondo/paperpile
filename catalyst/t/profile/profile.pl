#!/home/wash/play/paperpile/catalyst/perl5/linux64/bin/perl -w
##!/home/wash/play/paperpile/catalyst/perl5/linux64/bin/perl -d:NYTProf -w



use strict;
use Data::Dumper;
use lib '../../lib';
use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Bibutils;

use Paperpile::Model::Library;

#`cp ~/.paperpile/paperpile.ppl ./test.db`;

`cp ~/.paperpile/settings.db ./test.db`;

my $model = Paperpile::Model::User->new();
$model->set_dsn("dbi:SQLite:test.db");

my $dbh = $model->dbh;

for my $x (0..100){
  $dbh->do("UPDATE Settings SET value='asdfasdf' WHERE key='proxy' ");
}


#my $model = Paperpile::Model::Library->new();
#$model->set_dsn("dbi:SQLite:test.db");
#$model->light_objects(0);
##`cp ../../db/library.db  ./test.db`;
#foreach my $i (1..500){
#  my $result = $model->fulltext_search('Hofacker IL',  0, 25);
#}



