use strict;
use lib '../lib';

use Devel::Cover (-db=>"coverage",-silent=>1, -ignore=>"Test" );
use Test::Paperpile;
use Test::Paperpile::Formats;
use Test::Paperpile::Formats::Bibtex;


Test::Class->runtests;

