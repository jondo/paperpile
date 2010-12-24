#!../perl5/linux64/bin/paperperl

use strict;
use lib '../lib';

use Test::Paperpile;
use Test::Paperpile::Formats;
use Test::Paperpile::Formats::Bibtex;

Test::Class->runtests;
