#!/Users/wash/play/paperpile/catalyst/perl5/osx/bin/perl -w


BEGIN {
  $ENV{CATALYST_DEBUG} = 0;
}

use strict;
use Data::Dumper;
use lib '../../lib';
use Paperpile;
use Paperpile::Utils;
use Paperpile::Job;
use Paperpile::Queue;
use Paperpile::Library::Publication;


my $model = Paperpile::Model::Library->new();
$model->set_dsn( "dbi:SQLite:" . "/Users/wash/.paperdev/paperpile.ppl" );

$model->fulltext_search('Test', 0, 10);
