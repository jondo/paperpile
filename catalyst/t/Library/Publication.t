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
$ctx->add(encode_utf8('Knuth, D.E.'));
$ctx->add(encode_utf8('Fundamental Algorithms'));
my $sha1 = substr( $ctx->hexdigest, 0, 15 );

is( $pub->sha1, $sha1, "Autogenerate sha1 identity" );

$ctx = Digest::SHA1->new;
$ctx->add(encode_utf8('Knuth, D.E.'));
$ctx->add(encode_utf8('New Title'));
$sha1 = substr( $ctx->hexdigest, 0, 15 );

$pub->title('New Title');

is( $pub->sha1, $sha1, "Re-calculate sha1 identity after change" );

my $pub2 = Paperpile::Library::Publication->new( {%journal} );

is( $pub2->format_pattern('[firstauthor]'),       'Gruber',   '[firstauthor]' );
is( $pub2->format_pattern('[firstauthor:Uc]'),    'Gruber',   '[firstauthor:Uc]' );
is( $pub2->format_pattern('[firstauthor:lc]'),    'gruber',   '[firstauthor:lc]' );
is( $pub2->format_pattern('[firstauthor:UC]'),    'GRUBER',   '[firstauthor:UC]' );
is( $pub2->format_pattern('[firstauthor_abbr3]'), 'Gru',      '[firstauthor_abbr3]' );
is( $pub2->format_pattern('[lastauthor]'),        'Washietl', '[lastauthor]' );
is( $pub2->format_pattern('[authors]'),        'Gruber_Bernhart_Hofacker_Washietl', '[authors]' );
is( $pub2->format_pattern('[authors2]'),       'Gruber_Bernhart_et_al',             '[authors2]' );
is( $pub2->format_pattern('[authors3_abbr4]'), 'Grub_Bern_Hofa_et_al',              '[authors3_abbr4]' );
is( $pub2->format_pattern('[title]'),
  'Strategies_for_measuring_evolutionary_conservation_of_RNA_secondary_structures', '[title]' );
is( $pub2->format_pattern('[title3]'),       'Strategies_for_measuring', '[title3]' );
is( $pub2->format_pattern('[title3_abbr3]'), 'Str_for_mea',              '[title3_abbr3]' );
is( $pub2->format_pattern('[YY]'),           '08',                       '[YY]' );
is( $pub2->format_pattern('[YYYY]'),         '2008',                     '[YYYY]' );
is( $pub2->format_pattern('[journal]'),      'BMC_Bioinformatics',       '[journal]' );
is( $pub2->format_pattern('[key]', {key=>'Test'}),      'Test',       'Custom substitution [key]' );

