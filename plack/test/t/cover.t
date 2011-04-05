use strict;
use lib '../lib';

use Devel::Cover (-db=>"coverage",-silent=>1, -ignore=>".*/perl5/.*" );
use Test::Paperpile;
use Test::Paperpile::Formats;
use Test::Paperpile::Formats::Bibtex;
use Test::Paperpile::Formats::Ris;
use Test::Paperpile::Formats::Mendeley;
use Test::Paperpile::Formats::Zotero;


Test::Class->runtests;

