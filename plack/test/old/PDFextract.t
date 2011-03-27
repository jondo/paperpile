#!/usr/bin/perl -w

use lib "../lib/";
use strict;

use Test::More 'no_plan';

BEGIN { use_ok 'Paperpile::Library::PDFextract' }

my $pe =
  Paperpile::Library::PDFextract->new(
  title => 'RNAalifold: improved consensus structure prediction for RNA alignments' );

$pe->match_pubmed;
