#!/usr/bin/perl -w

use lib "../lib";
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

#my $pub1 = Paperpile::Library::Publication->new( doi => "asdfas" );
my $pub2 = Paperpile::Library::Publication->new( doi => "10.1016/j.tig.2008.09.003" );

my $q = Paperpile::Queue->new();

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

$q->add_job($job1);
#$q->add_job($job2);

$q->save;

#$q->restore;
#$job1->run;

my $q2 = Paperpile::Queue->new();

#$q->_dump;
$q2->_dump;


