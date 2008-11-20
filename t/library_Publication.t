#!/usr/bin/perl -w

use lib "../lib/";

use PaperPile::Library;
use PaperPile::Library::Publication;
use PaperPile::Schema::Publication;
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
  journal_short => 'Nature',
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
  authors=> [$author1, $author2],
  editors=> [$editor1, $editor2],
);

foreach my $key ( keys %data ) {
  $pub->$key( $data{$key} );
  is( $pub->$key, $data{$key}, "Get/Set on field $key" );
}

$pub = PaperPile::Library::Publication->new( {%data} );

my $authors_flat='PF Stadler,AR Gruber';
my $editors_flat='F Eisenhaber,M Carugo';

is( $pub->authors_flat, $authors_flat, "Transform author objects in flat string." );
is( $pub->editors_flat, $editors_flat, "Transform editor objects in flat string." );

my $ctx = Digest::SHA1->new;
$ctx->add($authors_flat);
$ctx->add('The title of the paper');
my $sha1 = substr($ctx->hexdigest,0,15);

my $pub2 = PaperPile::Library::Publication->new( {%data} );

#print $pub2->dump;
is( $pub2->id, $sha1, "Autogenerate sha1 identity" );

