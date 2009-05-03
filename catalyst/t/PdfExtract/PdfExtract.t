#!/usr/bin/perl -w

use lib "../../lib";
use strict;
use Data::Dumper;
use Paperpile::Library::Author;
use Paperpile::PdfExtract;
use Test::More 'no_plan';

BEGIN { use_ok 'Paperpile::PdfExtract' }

my $bin="../../bin/linux64/pdftoxml";

my $extract = Paperpile::PdfExtract->new( file => "../data/nature.pdf", pdftoxml => $bin );

my ( $title, $authors, $doi, $level ) = $extract->parsePDF;

is ($doi, '10.1038/nature06341', "Extracting doi");


