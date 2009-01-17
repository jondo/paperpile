use strict;
use warnings;
use Test::More 'no_plan';

use Data::Dumper;
use lib "../lib";
use PaperPile::Library::Publication;
use PaperPile::Model::DummyC;

BEGIN { use_ok 'PaperPile::Model::DBI' }

# use a dummy $c object, otherwise we can't test
# here DBI::Model
my $c = PaperPile::Model::DummyC->new();

my %journal_data = (
  pubtype => 'JOUR',
  title =>
'Strategies for measuring evolutionary conservation of RNA secondary structures',
  journal => 'BMC Bioinformatics',
  authors => 'Gruber, AR and Bernhart, SH and  Hofacker, I.L. and Washietl, S.',
  volume  => '9',
  pages   => '122',
  year    => '2008',
  month   => 'Feb',
  day     => '26',
  issn    => '1471-2105',
  pmid    => '18302738',
  doi     => '10.1186/1471-2105-9-122',
  url     => 'http://www.biomedcentral.com/1471-2105/9/122',
  abstract =>
    'BACKGROUND: Evolutionary conservation of RNA secondary structure..',
  notes => 'These are my notes',
  tags  => 'RNA important cool awesome',
  pdf   => 'some/folder/to/pdfs/gruber2008.pdf',
);

my %book_data = (
  pubtype   => 'INBOOK',
  title     => 'Fundamental Algorithms',
  title2    => 'The Art of Computer Programming',
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

my $model   = PaperPile::Model::DBI->new($c);
my $book    = PaperPile::Library::Publication->new( {%book_data} );
my $journal = PaperPile::Library::Publication->new( {%journal_data} );

is ( $model->reset_db,1, 'Reset database by "reset_db"' );

is( $model->create_pub($journal), 1, 'Insert entry by "create_pub"' );

$model->exists_pub( [ $journal, $book ]);

is( $journal->_imported, 1, 'Check for existing entry by "exists_pub"');
is( $book->_imported, 0, 'Check for non-existing entry by "exists_pub"');

$model->create_pub($book);
$book->_imported(1);
$book->_rowid(2);
$journal->_imported(1);
$journal->_rowid(1);
is_deeply($model->fulltext_search('',0,10),[$journal,$book], 'Retrieving by full text search');

$book->authors("Knuth, D.E. and Gruber, AR");

is ($model->update_pub($book), 2, "Running update on entry");

is_deeply($model->fulltext_search('Knuth',0,10),[$book], 'checking updated data');

is ($model->delete_pubs([1,2]),1,"Deleting entries");




