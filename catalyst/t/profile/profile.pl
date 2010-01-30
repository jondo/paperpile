#!/home/wash/play/paperpile/catalyst/perl5/linux64/bin/perl -d:NYTProf -w

##!/home/wash/play/paperpile/catalyst/perl5/linux64/bin/perl -w


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

my $pub1 = Paperpile::Library::Publication->new( doi => "10.1186/1471-2105-9-248" );

my $q = Paperpile::Queue->new();

$q->clear;
$q->save;

my @jobs = ();

foreach my $i ( 0 .. 10 ) {

  my $job = Paperpile::Job->new(
    type  => 'PDF_SEARCH',
    pub   => $pub1,
    queue => $q
  );

  push @jobs, $job;

}

$q->submit(\@jobs);

#$q->save;

#$q->run;

