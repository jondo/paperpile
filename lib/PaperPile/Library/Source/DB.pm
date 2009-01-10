package PaperPile::Library::Source::DB;

use Carp;
use Data::Page;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;
use PaperPile::Model::DB;
use PaperPile::Library::Publication;
use PaperPile::Library::Author;
use PaperPile::Library::Journal;


extends 'PaperPile::Library::Source';

has 'query' => ( is => 'rw' );

sub connect {
  my $self = shift;

  my $model=PaperPile::Model::DB->new;

  my $rs=$model->get_fulltext_rs($self->query,$self->entries_per_page);

  $self->_pager($rs->page(1)->pager);

  $self->total_entries($self->_pager->total_entries);

  return $self->total_entries;
}



sub _get_data_for_page {
  my $self = shift;

  my $model=PaperPile::Model::DB->new;

  my $rs=$model->get_fulltext_rs($self->query,$self->entries_per_page);

  return $model->fulltext_search($rs,$self->_pager->current_page);


}

1;
