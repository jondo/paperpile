use strict;
use warnings;
use Data::Dumper;

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

#my $editor1 =
#  PaperPile::Library::Author->new( last_name => 'Eisenhaber', initials => 'F' );

my $journal1 = PaperPile::Library::Journal->new(
  id    => 'UNKNOWN_J',
  short => 'Unknown J',
  name  => 'Unknown Journal'
);

my $journal2 = PaperPile::Library::Journal->new(
  id    => 'NATURE',
  short => 'Nature',
  name  => 'Nature'
);

my $data1 = {
  pubtype      => 'JOUR',
  title        => 'Title',
  authors_flat => 'Stadler PF, Hofacker IL, Gruber AJ',

  #editors_flat => 'Eisenhaber F, Darwin C',
  volume    => 123,
  issue     => 3,
  pages     => "4 - 5",
  publisher => 'Nature Press',
  city      => 'New York',
  address   => 'Central Park',
  date      => 'Fall',
  year      => 2008,
  month     => 'Jan',
  day       => '10',
  issn      => '12345-123',
  pmid      => 123456,
  doi       => '10.123434/123123312',
  url       => 'www.google.com',
  abstract  => 'This is the abstract.',
  notes     => 'These are my notes',
  tags_flat => 'important cool awesome',
  pdf       => 'some/folder/to/pdfs/stadler08.pdf',
  fulltext  => 'This is the full text',
  authors   => [$author1],

  #editors      => [$editor1],
  journal    => $journal1,
  journal_id => $journal1->id,
};

my $data2 = {
  pubtype    => 'JOUR',
  title      => 'Another exciting paper',
  volume     => 64,
  issue      => 4,
  pages      => "40-45",
  year       => 2008,
  abstract   => 'This is the abstract.',
  authors    => [ $author1, $author2, $author3 ],
  journal    => $journal2,
  journal_id => $journal2->id,
};

my $pub1 = PaperPile::Library::Publication->new($data1);
my $id1  = $pub1->{sha1};

my $pub2 = PaperPile::Library::Publication->new($data2);
my $id2  = $pub2->{sha1};

my $model = PaperPile::Model::DB->new;

my $rowid1 = $model->create_pub($pub1);
my $rowid2 = $model->create_pub($pub2);

$pub1->rowid($rowid1);
$pub2->rowid($rowid2);

like( $rowid1, qr/\d+/, 'Inserting test entry 1 into database' );

like( $rowid2, qr/\d+/, 'Inserting test entry 2 into database' );

is_deeply(
  $model->search( { sha1 => [ $pub1->{sha1}, $pub2->{sha1} ] } ),
  [ $pub1, $pub2 ],
  'Retrieving data from database.'
);

$pub2->title('This is the updated title');

$rowid2=$model->update_pub($pub2);
$pub2->rowid($rowid2);

is ($model->search( { sha1 => [ $pub2->{sha1}]})->[0]->title,'This is the updated title','Updating entry');


$model->delete_pubs( [ $pub1->rowid, $pub2->rowid ] );

is( @{ $model->search( { sha1 => [ $pub1->{sha1}, $pub2->{sha1} ] } ) },
  0, 'Deleting entries' );
