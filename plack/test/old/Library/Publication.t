#!/usr/bin/perl -w

use lib "../../lib/";
use strict;

use Paperpile::Library::Publication;
use Data::Dumper;
use Digest::SHA1;
use Encode qw(encode_utf8);
use Test::More 'no_plan';
use Test::Deep;
use 5.010;

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

$pub = Paperpile::Library::Publication->new;

foreach my $key ( keys %book ) {
  $pub->$key( $book{$key} );
  is( $pub->$key, $book{$key}, "Get/Set on field $key (book example)" );
}

$pub = Paperpile::Library::Publication->new;

foreach my $key ( keys %journal ) {
  $pub->$key( $journal{$key} );
  is( $pub->$key, $journal{$key}, "Get/Set on field $key (journal example)" );
}

$pub = Paperpile::Library::Publication->new( {%book} );

my $ctx = Digest::SHA1->new;
$ctx->add( encode_utf8('Knuth, D.E.') );
$ctx->add( encode_utf8('Fundamental Algorithms') );
my $sha1 = substr( $ctx->hexdigest, 0, 15 );

is( $pub->sha1, $sha1, "Autogenerate sha1 identity" );

$ctx = Digest::SHA1->new;
$ctx->add( encode_utf8('Knuth, D.E.') );
$ctx->add( encode_utf8('New Title') );
$sha1 = substr( $ctx->hexdigest, 0, 15 );

$pub->title('New Title');

is( $pub->sha1, $sha1, "Re-calculate sha1 identity after change" );

my $pub2 = Paperpile::Library::Publication->new( {%journal} );

is( $pub2->format_pattern('[firstauthor]'), 'gruber', '[firstauthor]' );
is( $pub2->format_pattern('[Firstauthor]'), 'Gruber', '[Firstauthor]' );
is( $pub2->format_pattern('[FIRSTAUTHOR]'), 'GRUBER', '[FIRSTAUTHOR]' );

is( $pub2->format_pattern('[Firstauthor:3]'), 'Gru', '[Firstauthor:3]' );

is( $pub2->format_pattern('[lastauthor]'), 'washietl', '[lastauthor]' );
is( $pub2->format_pattern('[Lastauthor]'), 'Washietl', '[Lastauthor]' );
is( $pub2->format_pattern('[LASTAUTHOR]'), 'WASHIETL', '[LASTAUTHOR]' );

is( $pub2->format_pattern('[Authors]'), 'Gruber_Bernhart_Hofacker_Washietl', '[Authors]' );
is( $pub2->format_pattern('[AUTHORS]'), 'GRUBER_BERNHART_HOFACKER_WASHIETL', '[AUTHORS]' );

is( $pub2->format_pattern('[Authors2]'),   'Gruber_Bernhart_et_al', '[Authors2]' );
is( $pub2->format_pattern('[authors3:4]'), 'grub_bern_hofa_et_al',  '[authors3:4]' );


is( $pub2->format_pattern('[Title]'),
  'Strategies_for_measuring_evolutionary_conservation_of_RNA_secondary_structures', '[Title]' );
is( $pub2->format_pattern('[title]'),
  'strategies_for_measuring_evolutionary_conservation_of_rna_secondary_structures', '[title]' );
is( $pub2->format_pattern('[TITLE]'),
  'STRATEGIES_FOR_MEASURING_EVOLUTIONARY_CONSERVATION_OF_RNA_SECONDARY_STRUCTURES', '[TITLE]' );


is( $pub2->format_pattern('[Title3]'),       'Strategies_for_measuring', '[Title3]' );
is( $pub2->format_pattern('[Title3:3]'), 'Str_for_mea',              '[Title3:3]' );

is( $pub2->format_pattern('[YY]'),           '08',                       '[YY]' );
is( $pub2->format_pattern('[YYYY]'),         '2008',                     '[YYYY]' );
is( $pub2->format_pattern('[journal]'),      'BMC_Bioinformatics',       '[journal]' );
is( $pub2->format_pattern( '[key]', { key => 'Test' } ), 'Test', 'Custom substitution [key]' );

