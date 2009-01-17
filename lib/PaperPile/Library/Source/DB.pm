package PaperPile::Library::Source::DB;

use Carp;
use Data::Page;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;
use PaperPile::Model::DB;
use PaperPile::Model::DummyC;
use PaperPile::Library::Publication;
use PaperPile::Library::Author;
use PaperPile::Library::Journal;

extends 'PaperPile::Library::Source';

has 'query' => ( is => 'rw' );

sub connect {
  my $self = shift;

  my $model=PaperPile::Model::DBI->new(PaperPile::Model::DummyC->new());

  $self->total_entries($model->fulltext_count($self->query));

  return $self->total_entries;
}


sub page {
  ( my $self, my $offset, my $limit ) = @_;

  my $model=PaperPile::Model::DBI->new(PaperPile::Model::DummyC->new());

  my $page = $model->fulltext_search($self->query, $offset, $limit);

  $self->_save_page_to_hash($page);

  return $page;

}


1;
