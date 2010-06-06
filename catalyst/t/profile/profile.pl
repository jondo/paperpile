#!/home/wash/play/paperpile/catalyst/perl5/linux64/bin/perl -w

##!/home/wash/play/paperpile/catalyst/perl5/linux64/bin/perl -d:NYTProf -w


BEGIN {
  $ENV{CATALYST_DEBUG} = 0;
}

use strict;
use Data::Dumper;
use lib '../../lib';

use Paperpile;
use Paperpile::FileSync;


