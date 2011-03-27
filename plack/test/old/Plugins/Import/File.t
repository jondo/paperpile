use strict;
use warnings;
use Data::Dumper;
use Test::More 'no_plan';
use lib "../../../lib";
use Exception::Class;

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

my $import;

#$import=Paperpile::Plugins::Import::File->new( file => "/home/wash/play/scripts/out.bib" );

#$import->connect();
#$import->guess_format;
#$import->all;
#exit;


#eval {
$import=Paperpile::Plugins::Import::File->new( file => "../../data/formats/test.bib" );
#$import=Paperpile::Plugins::Import::File->new( file => "/home/wash/logo.png" );
$import->connect();
#};

#my $e;
#if ( $e = Exception::Class->caught('ImportException') ){
#  print STDERR "OK. caught\n";
#} else {
#  $e = Exception::Class->caught();
#  ref $e ? $e->rethrow : die $e;
#}

$import->guess_format;

#$import->connect;


#foreach my $format (keys %files){
#  my $import = Paperpile::Plugins::Import::File->new( file => "../../data/formats/".$files{$format} );
#  $import->guess_format;
#  is($import->format, $format, "Guessing format $format");
#}

#my $import = Paperpile::Plugins::Import::File->new( file => "../../data/test2.bib");
#is ($import->connect, 42, 'Reading test.bib');

#my $page=$import->all;
#is (@$page, 28, 'Reading all entries with "all"');

#my $page=$import->page(0,10);
#is (@$page, 10, 'Reading 10 entries with "page"');

#my $page=$import->page(27,10);
#is (@$page, 1, 'Reading entry with "page" from the end with limit longer than list.');



