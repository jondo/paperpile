use strict;
use warnings;
use Data::Dumper;
#use DBICx::TestDatabase;

#use Test::More 'no_plan';

use lib "../lib";

use PaperPile::Library;
use PaperPile::Library::Publication;

use PaperPile::Schema;
use PaperPile::Model::DB;

#BEGIN { use_ok 'PaperPile::Model::DB' }

my $author1 =
  PaperPile::Library::Author->new( last_name => 'Stadler', initials => 'PF' );

my $editor1 =
  PaperPile::Library::Author->new( last_name => 'Eisenhaber', initials => 'F' );

my $journal =
  PaperPile::Library::Journal->new( id => 'Nature', name => 'Nature' );

my $data = {
  pubtype       => 'JOUR',
  title         => 'Title',
  journal_short => 'Nature',
  authors_flat  => 'Stadler PF, Hofacker IL, Gruber AJ',
  editors_flat  => 'Eisenhaber F, Darwin C',
  volume        => 123,
  issue         => 3,
  pages         => "4 - 5",
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
  authors       => [$author1],
  editors       => [$editor1],
  journal       => $journal
};

my $pub = PaperPile::Library::Publication->new($data);
my $lib = PaperPile::Library->new( entries => [$pub] );

my $model = PaperPile::Model::DB->new;
$model->import_lib($lib);


