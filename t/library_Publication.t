#!/usr/bin/perl -w

use lib "../lib/";
use strict;

use PaperPile::Library::Publication;
use Bibutils;
use Data::Dumper;
use Digest::SHA1;
use Test::More 'no_plan';

my %book = (
  pubtype   => 'INBOOK',
  title     => 'Fundamental Algorithms',
  booktitle => 'The Art of Computer Programming',
  authors   => 'Knuth, D.E.',
  volume    => '1',
  pages     => '10-119',
  publisher => 'Addison-Wesley',
  city      => 'Reading',
  address   => "Massachusetts",
  year      => '2007',
  month     => 'Jan',
  isbn      => '0-201-03803-X',
  notes     => 'These are my notes',
  tags      => 'programming, algorithms',
);

my %journal = (
  pubtype  => 'JOUR',
  title    => 'Strategies for measuring evolutionary conservation of RNA secondary structures',
  journal  => 'BMC Bioinformatics',
  authors  => 'Gruber, AR and Bernhart, SH and  Hofacker, I.L. and Washietl, S.',
  volume   => '9',
  pages    => '122',
  year     => '2008',
  month    => 'Feb',
  day      => '26',
  issn     => '1471-2105',
  pmid     => '18302738',
  doi      => '10.1186/1471-2105-9-122',
  url      => 'http://www.biomedcentral.com/1471-2105/9/122',
  abstract => 'BACKGROUND: Evolutionary conservation of RNA secondary structure..',
  notes    => 'These are my notes',
  tags     => 'RNA important cool awesome',
  pdf      => 'some/folder/to/pdfs/gruber2008.pdf',
);

my $pub;

$pub = PaperPile::Library::Publication->new;

foreach my $key ( keys %book ) {
  $pub->$key( $book{$key} );
  is( $pub->$key, $book{$key}, "Get/Set on field $key (book example)" );
}

$pub = PaperPile::Library::Publication->new;

foreach my $key ( keys %journal ) {
  $pub->$key( $journal{$key} );
  is( $pub->$key, $journal{$key}, "Get/Set on field $key (journal example)" );
}

$pub = PaperPile::Library::Publication->new( {%book} );

my $ctx = Digest::SHA1->new;
$ctx->add('Knuth DE');
$ctx->add('Fundamental Algorithms');
my $sha1 = substr( $ctx->hexdigest, 0, 15 );

is( $pub->sha1, $sha1, "Autogenerate sha1 identity" );

$ctx = Digest::SHA1->new;
$ctx->add('Knuth DE');
$ctx->add('New Title');
$sha1 = substr( $ctx->hexdigest, 0, 15 );

$pub->title('New Title');

is( $pub->sha1, $sha1, "Re-calculate sha1 identity after change" );

my $pub2 = PaperPile::Library::Publication->new( {%journal} );

is( $pub2->format('[firstauthor]'),       'Gruber',   '[firstauthor]' );
is( $pub2->format('[firstauthor:Uc]'),    'Gruber',   '[firstauthor:Uc]' );
is( $pub2->format('[firstauthor:lc]'),    'gruber',   '[firstauthor:lc]' );
is( $pub2->format('[firstauthor:UC]'),    'GRUBER',   '[firstauthor:UC]' );
is( $pub2->format('[firstauthor_abbr3]'), 'Gru',      '[firstauthor_abbr3]' );
is( $pub2->format('[lastauthor]'),        'Washietl', '[lastauthor]' );
is( $pub2->format('[authors]'),        'Gruber_Bernhart_Hofacker_Washietl', '[authors]' );
is( $pub2->format('[authors2]'),       'Gruber_Bernhart_et_al',             '[authors2]' );
is( $pub2->format('[authors3_abbr4]'), 'Grub_Bern_Hofa_et_al',              '[authors3_abbr4]' );
is( $pub2->format('[title]'),
  'Strategies_for_measuring_evolutionary_conservation_of_RNA_secondary_structures', '[title]' );
is( $pub2->format('[title3]'),       'Strategies_for_measuring', '[title3]' );
is( $pub2->format('[title3_abbr3]'), 'Str_for_mea',              '[title3_abbr3]' );
is( $pub2->format('[YY]'),           '08',                       '[YY]' );
is( $pub2->format('[YYYY]'),         '2008',                     '[YYYY]' );
is( $pub2->format('[journal]'),      'BMC_Bioinformatics',       '[journal]' );

#is( $pub2->format('[firstauthor:UC]_[journal]:[YYYY]'),
#  'STADLER_Nature:2008', '[firstauthor:UC]_[journal]:[YYYY]' );

my $bu = Bibutils->new(
  in_file => 'data/test.bib',

  #in_file => 'data/test1.ris',
  out_file  => 'data/new.bib',
  in_format => Bibutils::BIBTEXIN,

  #in_format => Bibutils::RISIN,
  out_format => Bibutils::BIBTEXOUT,
);

#my $bu=Bibutils->new(in_file => 'data/test1.ris',
#                     out_file => 'data/new.bib',
#                     in_format => Bibutils::RISIN,
#                     out_format => Bibutils::BIBTEXOUT,
#                    );

$bu->read;

my @data = @{ $bu->get_data };

$pub = PaperPile::Library::Publication->new;

my @expected_types = qw/ARTICLE ARTICLE INBOOK INBOOK BOOK BOOK BOOK BOOKLET BOOKLET INCOLLECTION
  INCOLLECTION BOOK MANUAL MANUAL MASTERSTHESIS MASTERSTHESIS MISC MISC INPROCEEDINGS
  INPROCEEDINGS INPROCEEDINGS PROCEEDINGS PROCEEDINGS PROCEEDINGS PHDTHESIS PHDTHESIS
  TECHREPORT TECHREPORT UNPUBLISHED UNPUBLISHED/;

foreach my $i ( 0 .. $#data ) {

  next if $expected_types[$i] eq 'BOOKLET';    # not currently handled
  my $type = $pub->_get_type_from_bibutils( $data[$i] );
  is( $type, $expected_types[$i],
    "Get publication type from bibutils data (" . $expected_types[$i] . ")" );

}

foreach my $i ( 0 .. $#data ) {

  $pub->build_from_bibutils($data[$i]);

}

#$pub->prepare_bibutils_fields;
