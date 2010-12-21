#!/usr/bin/perl -w

use lib "../lib/";
use strict;

use Test::More 'no_plan';

use Data::Dumper;

BEGIN { use_ok 'Paperpile::Formats';
        use_ok 'Paperpile::Formats::Bibtex';
}


binmode STDOUT, ":utf8";    # avoid unicode errors when printing to STDOUT

my %files = (
  BIBTEX  => 'test.bib',
  MODS    => 'test.mods',
  ISI     => 'test.isi',
  ENDNOTE => 'test.end',
  RIS     => 'test.ris',
  MEDLINE => 'test.med'
);

my $file = "data/formats/test.bib";

my $formatter=Paperpile::Formats->guess_format($file);

my $data = $formatter->read();

print STDERR Dumper($data);

open(TMP, "<data/formats/test.bib");
my $string='';
$string.=$_ foreach (<TMP>);


$formatter=Paperpile::Formats::Bibtex->new();
$data=$formatter->read_string($string);
print STDERR Dumper($data);

$formatter=Paperpile::Formats::Bibtex->new(file=>'tmp.dat', data=>$data);

print STDERR $formatter->write_string();
