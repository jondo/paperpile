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

my $map = { '91035A4871BC11DFA6B0E0AC40B6B6F9' => '/home/wash/sync.bib' };

my $fs = Paperpile::FileSync->new( map => $map);

$fs->sync_collection('91035A4871BC11DFA6B0E0AC40B6B6F9');
