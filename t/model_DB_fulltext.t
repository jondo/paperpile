use strict;
use warnings;
use Data::Dumper;
use Test::More 'no_plan';
use lib "../lib";
use PaperPile::Library;
use PaperPile::Model::DB;
use PaperPile::Library::Source::File;

my $model = PaperPile::Model::DB->new;

# Load data into database

my $source = PaperPile::Library::Source::File->new( file => 'data/test2.ris' );

$source->connect;

while ( my $pub = $source->next ) {
  $model->create_pub($pub);
}

$model->index_all;

my $rs=$model->get_fulltext_rs('telomerase',100);

print Dumper($rs->page(1)->pager);

foreach my $pub (@{$model->fulltext_search($rs,1)}){

  #$model->complete_related($pub);

  #print Dumper($pub->journal);

}


