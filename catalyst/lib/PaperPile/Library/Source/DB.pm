package PaperPile::Library::Source::DB;

use Carp;
use Data::Page;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;
use PaperPile::Utils;
use PaperPile::Library::Publication;
use PaperPile::Library::Author;
use PaperPile::Library::Journal;

extends 'PaperPile::Library::Source';

has 'query' => ( is => 'rw' );
has 'mode' => ( is => 'rw', default => 'FULLTEXT', isa => 'Str' );
has 'file' => ( is => 'rw' );

sub get_model {

  my $self=shift;
  my $model = PaperPile::Model::User->new();
  $model->set_dsn("dbi:SQLite:".$self->file);
  return $model;

}


sub connect {
  my $self = shift;

  my $model=$self->get_model;

  if ( $self->mode eq 'FULLTEXT' ) {

    $self->total_entries( $model->fulltext_count( $self->query ) );
  } else {
    $self->total_entries( $model->standard_count( $self->query ) );
  }

  return $self->total_entries;
}

sub page {
  ( my $self, my $offset, my $limit ) = @_;

  my $model=$self->get_model;

  my $page;

  if ( $self->mode eq 'FULLTEXT' ) {
    $page = $model->fulltext_search( $self->query, $offset, $limit );
  } else {
    $page = $model->standard_search( $self->query, $offset, $limit );
  }

  $self->_save_page_to_hash($page);

  return $page;

}

1;
