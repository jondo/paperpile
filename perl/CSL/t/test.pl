#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Data::Dumper;
use lib "../blib/lib/";

use Biblio::CSL;

my $usage = << "JUS";
  usage: perl $0 -m mods.xml.file -c csl.file -i ID-string -t type -l int
  
  options: 
        -m      MODS input xml file.
                [REQUIRED]

        -c      CSL input style file.
                [REQUIRED]
                
        -i      ID-string, list of list of IDs needed to build the citations.
                Citations of a single cite statement (\cite{a,b,c}) must be separated by comma 
                and several cite statements are seperated by space.
                Format: "a,b,c d e f,g"                
                [OPTIONAL]

        -f      Output format, e.g. txt, html, bibtex
                [OPTIONAL, default: txt]

  purpose:
	Read in a MODS xml file, parse it, and transform it 
	to a given output format using the CSL style file.

  results:
	at STDOUT
JUS

my ($opt_m, $opt_c, $opt_i, $opt_f) = ("", "", "", "txt");

GetOptions(
  "m=s" => \$opt_m,
  "c=s" => \$opt_c,
  "f=s" => \$opt_f,
  "i=s" => \$opt_i
);

if ( !$opt_m || !$opt_c ) {
  print STDERR $usage;
  exit;
}

my $o = Biblio::CSL->new(
  mods => $opt_m,
  csl => $opt_c,
  format => $opt_f,
  IDs => $opt_i
);


#$o->version();
#print "\n--- Beispiel: txt ---\n";

$o->transform();

if($o->getCitationsSize()>0) {
  #print "\nCitations (".$o->getCitationsSize()."):\n";
  #print $o->citationsToString();
}

#print "\nBibliography (".$o->getBiblioSize()."):\n";
print $o->biblioToString();
#print Dumper $o->{biblio}
