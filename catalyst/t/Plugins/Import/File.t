use strict;
use warnings;
use Data::Dumper;
use Test::More 'no_plan';
use lib "../../../lib";

BEGIN { use_ok 'Paperpile::Plugins::Import::File' }

binmode STDOUT, ":utf8";    # avoid unicode errors when printing to STDOUT

my %files = (
  BIBTEX  => 'test.bib',
  MODS    => 'test.mods',
  ISI     => 'test.isi',
  ENDNOTE => 'test.end',
  RIS     => 'test.ris',
  MEDLINE => 'test.med'
);

foreach my $format (keys %files){
  my $import = Paperpile::Plugins::Import::File->new( file => "../../data/formats/".$files{$format} );
  $import->guess_format;
  is($import->format, $format, "Guessing format $format");
}

my $import = Paperpile::Plugins::Import::File->new( file => "../../data/test2.bib");
is ($import->connect, 42, 'Reading test.bib');

#my $page=$import->all;
#is (@$page, 28, 'Reading all entries with "all"');

#my $page=$import->page(0,10);
#is (@$page, 10, 'Reading 10 entries with "page"');

#my $page=$import->page(27,10);
#is (@$page, 1, 'Reading entry with "page" from the end with limit longer than list.');



