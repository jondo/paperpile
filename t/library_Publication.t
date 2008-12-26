#!/usr/bin/perl -w

use lib "../lib/";

use PaperPile::Library;
use PaperPile::Library::Publication;
use PaperPile::Schema::Publication;
use Data::Dumper;
use Digest::SHA1;
use Test::More 'no_plan';

my $pub = PaperPile::Library::Publication->new;

my $author1 =
  PaperPile::Library::Author->new( last_name => 'Stadler', initials => 'PF' );
my $author2 =
  PaperPile::Library::Author->new( last_name => 'Gruber', initials => 'AR' );
my $editor1 =
  PaperPile::Library::Author->new( last_name => 'Eisenhaber', initials => 'F' );
my $editor2 =
  PaperPile::Library::Author->new( last_name => 'Carugo', initials => 'M' );


my %data = (
  pubtype       => 'JOUR',
  title         => 'The title of the paper',
  journal_flat => 'Nature',
  authors_flat  => '',
  editors_flat  => '',
  volume        => 123,
  issue         => 3,
  pages         => 4 - 5,
  publisher     => 'Nature Press',
  city          => 'New York',
  address       => '',
  date          => '',
  year          => 2008,
  month         => 'Jan',
  day           => '',
  issn          => '12345-123',
  pmid          => 123456,
  doi           => '',
  url           => 'www.google.com',
  abstract      => 'This is the abstract.',
  notes         => 'These are my notes',
  tags_flat     => 'important cool awesome',
  pdf           => 'some/folder/to/pdfs/stadler08.pdf',
  fulltext      => 'This is the full text',
  authors=> [$author1, $author2, $editor1, $editor2],
  editors=> [$editor1, $editor2],
);

foreach my $key ( keys %data ) {
  $pub->$key( $data{$key} );
  is( $pub->$key, $data{$key}, "Get/Set on field $key" );
}

$pub = PaperPile::Library::Publication->new( {%data} );

my $authors_flat='Stadler PF, Gruber AR, Eisenhaber F, Carugo M';
my $editors_flat='Eisenhaber F, Carugo M';

is( $pub->authors_flat, $authors_flat, "Transform author objects in flat string." );
is( $pub->editors_flat, $editors_flat, "Transform editor objects in flat string." );

my $ctx = Digest::SHA1->new;
$ctx->add($authors_flat);
$ctx->add('The title of the paper');
my $sha1 = substr($ctx->hexdigest,0,15);

my $pub2 = PaperPile::Library::Publication->new( {%data} );

is( $pub2->sha1, $sha1, "Autogenerate sha1 identity" );

$ctx = Digest::SHA1->new;
$ctx->add($authors_flat);
$ctx->add('New Title');
$sha1 = substr($ctx->hexdigest,0,15);

$pub2->title('New Title');

is( $pub2->sha1, $sha1, "Re-calculate sha1 identity after change" );

$pub2->title('The title of the paper');

is ($pub2->format('[firstauthor]'), 'Stadler', '[firstauthor]');
is ($pub2->format('[firstauthor:Uc]'), 'Stadler', '[firstauthor:Uc]');
is ($pub2->format('[firstauthor:lc]'), 'stadler','[firstauthor:lc]' );
is ($pub2->format('[firstauthor:UC]'), 'STADLER','[firstauthor:UC]');
is ($pub2->format('[firstauthor_abbr3]'), 'Sta','[firstauthor_abbr3]');
is ($pub2->format('[lastauthor]'), 'Carugo', '[lastauthor]');
is ($pub2->format('[authors]'), 'Stadler_Gruber_Eisenhaber_Carugo', '[authors]');
is ($pub2->format('[authors2]'), 'Stadler_Gruber_et_al', '[authors2]');
is ($pub2->format('[authors3_abbr4]'), 'Stad_Grub_Eise_et_al', '[authors3_abbr4]');
is ($pub2->format('[title]'), 'The_title_of_the_paper', '[title]');
is ($pub2->format('[title3]'), 'The_title_of', '[title3]');
is ($pub2->format('[title3_abbr3]'), 'The_tit_of', '[title3_abbr3]');
is ($pub2->format('[YY]'), '08', '[YY]');
is ($pub2->format('[YYYY]'), '2008', '[YYYY]');
is ($pub2->format('[journal]'), 'Nature', '[journal]');
is ($pub2->format('[firstauthor:UC]_[journal]:[YYYY]'), 'STADLER_Nature:2008', '[firstauthor:UC]_[journal]:[YYYY]');
