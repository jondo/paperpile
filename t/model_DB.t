use strict;
use warnings;
use Data::Dumper;

#use DBICx::TestDatabase;

use Test::More 'no_plan';

use lib "../lib";

use PaperPile::Library;

BEGIN { use_ok 'PaperPile::Model::DB' }

my $author1 =
  PaperPile::Library::Author->new( last_name => 'Stadler', initials => 'PF' );

my $author2 =
  PaperPile::Library::Author->new( last_name => 'Hofacker', initials => 'IL' );

my $author3 =
  PaperPile::Library::Author->new( last_name => 'Gruber', initials => 'AR' );

my $editor1 =
  PaperPile::Library::Author->new( last_name => 'Eisenhaber', initials => 'F' );

my $journal1 = PaperPile::Library::Journal->new(
  id    => 'Unknown_J',
  short => 'Unknown J',
  name  => 'Unknown Journal'
);

my $journal2 = PaperPile::Library::Journal->new(
  id    => 'Nature',
  short => 'Nature',
  name  => 'Nature'
);

my $data1 = {
  pubtype      => 'JOUR',
  title        => 'Title',
  authors_flat => 'Stadler PF, Hofacker IL, Gruber AJ',
  editors_flat => 'Eisenhaber F, Darwin C',
  volume       => 123,
  issue        => 3,
  pages        => "4 - 5",
  publisher    => 'Nature Press',
  city         => 'New York',
  address      => '',
  date         => '',
  year         => 2008,
  month        => 'Jan',
  day          => '',
  issn         => '12345-123',
  pmid         => 123456,
  doi          => '',
  url          => 'www.google.com',
  abstract     => 'This is the abstract.',
  notes        => 'These are my notes',
  tags_flat    => 'important cool awesome',
  pdf          => 'some/folder/to/pdfs/stadler08.pdf',
  fulltext     => 'This is the full text',
  authors      => [$author1],
  editors      => [$editor1],
  journal      => $journal1
};

my $data2 = {
  pubtype  => 'JOUR',
  title    => 'Another exciting paper',
  volume   => 64,
  issue    => 4,
  pages    => "40-45",
  year     => 2008,
  abstract => 'This is the abstract.',
  authors  => [ $author1, $author2, $author3 ],
  journal  => $journal2
};

my $pub   = PaperPile::Library::Publication->new($data1);
my $lib   = PaperPile::Library->new( entries => [$pub] );
my $model = PaperPile::Model::DB->new;

is_deeply(
  $model->import_lib($lib),
  [ $pub->{id} ],
  'Inserting test entry 1 into database'
);

$pub = PaperPile::Library::Publication->new($data2);
$lib = PaperPile::Library->new( entries => [$pub] );

is_deeply(
  $model->import_lib($lib),
  [ $pub->{id} ],
  'Inserting test entry 2 into database'
);

print Dumper($model->search( { id => $pub->{id} } ));

