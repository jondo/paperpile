#!/usr/bin/perl -w

use lib "../../lib";
use strict;
use Data::Dumper;
use Paperpile::Library::Publication;
use Paperpile::PdfExtract;
use Paperpile::Utils;
use Test::More 'no_plan';

BEGIN {
  use_ok 'Paperpile::Job';
  use_ok 'Paperpile::Queue';
}

my $pub1 = Paperpile::Library::Publication->new( doi => "10.1186/1471-2105-9-248" );
my $pub2 = Paperpile::Library::Publication->new( doi => "10.1016/j.tig.2008.09.003" );

my $q = Paperpile::Queue->new();

$q->clear;
$q->save;
unlink('log');

my $job1 = Paperpile::Job->new(
  type  => 'PDF_SEARCH',
  pub   => $pub1,
  queue => $q
);

my $job2 = Paperpile::Job->new(
  type  => 'PDF_SEARCH',
  pub   => $pub2,
  queue => $q
);

my $job3 = Paperpile::Job->new(
  type  => 'PDF_SEARCH',
  pub   => $pub2,
  queue => $q
);

my $job4 = Paperpile::Job->new(
  type  => 'PDF_SEARCH',
  pub   => $pub2,
  queue => $q
);


$q->submit($job1);
$q->submit($job2);
$q->submit($job3);
$q->submit($job4);

$q->update_stats;

print STDERR Dumper($q);

$q->run;

#$q->_dump;



#$job1->save;
#$my $job2 = Paperpile::Job->new({id=>$job1->id});
#$job2->run;
#print Dumper($job2);
#$job4->status_update('RUNNING');
#$q->save;
#$q->run;
#$q->_dump;
#$job1->run;
#my $q2 = Paperpile::Queue->new();
#$q2->restore;
#$q2->_dump;




