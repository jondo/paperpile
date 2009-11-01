package Paperpile::Plugins::Import::DB;

use Carp;
use Data::Page;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;
use Paperpile::Utils;
use Paperpile::Model::Library;
use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Paperpile::Library::Journal;

extends 'Paperpile::Plugins::Import';

has 'query' => ( is => 'rw' );
has 'mode' => ( is => 'rw', default => 'FULLTEXT', isa => 'Str' );
has 'file' => ( is => 'rw' );
has 'search_pdf' => (is => 'rw', default => 1);
has 'order' => (is => 'rw', default => 'created DESC');
has '_db_file' => ( is => 'rw' );


sub BUILD {
  my $self = shift;
  $self->plugin_name('DB');
}

sub get_model {

  my $self=shift;
  my $model = Paperpile::Model::Library->new();
  $model->set_dsn("dbi:SQLite:".$self->_db_file);

  $model->light_objects($self->light_objects);

  return $model;

}


sub connect {
  my $self = shift;

  $self->_db_file($self->file);


  return $self->update_count();
}


sub page {
  ( my $self, my $offset, my $limit ) = @_;

  my $model=$self->get_model;

  my $page;

  if ( $self->mode eq 'FULLTEXT' ) {
    $page = $model->fulltext_search( $self->query, $offset, $limit, $self->order, $self->search_pdf );
  } else {
    $page = $model->standard_search( $self->query, $offset, $limit, $self->search_pdf );
  }

  $self->_save_page_to_hash($page);

  return $page;

}

sub all {

  ( my $self ) = @_;


  my $model=$self->get_model;

  return $model->all();

}

sub update_count {
  ( my $self) =@_;
  my $model=$self->get_model;

  if ( $self->mode eq 'FULLTEXT' ) {
    $self->total_entries( $model->fulltext_count( $self->query, $self->search_pdf ) );
  } else {
    $self->total_entries( $model->standard_count( $self->query, $self->search_pdf ) );
  }

  return $self->total_entries;

}

1;
