#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Data::Dumper;
use lib "../blib/lib/";

use Biblio::CSL;

my $usage = << "JUS";
  usage: perl $0 -m mods.xml.file -c csl.file -t type
  
  options: 
        -m      MODS input xml file.
		[REQUIRED]

        -c      CSL input style file.
                [REQUIRED]

        -t      Output format, e.g. txt, html, bibtex
                [REQUIRED]

  purpose:
	Read in a MODS xml file, parse it, and transform it 
	to a given output format using the CSL style file.

  results:
	at STDOUT
JUS

my ( $opt_m, $opt_c, $opt_f ) = ( "", "", "" );

GetOptions(
  "m=s" => \$opt_m,
  "c=s" => \$opt_c,
  "f=s" => \$opt_f
);

if ( !$opt_m || !$opt_c || !$opt_f ) {
  print STDERR $usage;
  exit;
}

my $o = XML::CSL->new(
  mods   => $opt_m,
  csl    => $opt_c,
  format => $opt_f
);

$o->version();
print "\n--- Beispiel: txt ---\n\n";

$o->transform();

