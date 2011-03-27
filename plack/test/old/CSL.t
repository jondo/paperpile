#!/usr/bin/perl -w

use lib "../lib";
use strict;
use Test::More 'no_plan';
use Bibutils;
use Paperpile::Library::Publication;
use Data::Dumper;


BEGIN { use_ok 'Paperpile::CSL' }


my $bu = Bibutils->new(
  in_file    => 'data/test2.bib',
  out_file   => '',
  in_format  => Bibutils::BIBTEXIN,
  out_format => Bibutils::BIBTEXOUT,
);

$bu->read;

my @data = ();

foreach my $entry ( @{ $bu->get_data } ) {
  my $pub = Paperpile::Library::Publication->new;
  $pub->_build_from_bibutils($entry);
  push @data, $pub;
}

#print STDERR Dumper(\@data);

my $csl=Paperpile::CSL->new(data => [@data]);

$csl->format_bibliography;
