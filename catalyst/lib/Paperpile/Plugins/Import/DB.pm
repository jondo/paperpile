package Paperpile::Plugins::Import::DB;

use Carp;
use Data::Page;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;
use Paperpile::Utils;
use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Paperpile::Library::Journal;

extends 'Paperpile::Plugins::Import';

has 'query' => ( is => 'rw' );
has 'mode' => ( is => 'rw', default => 'FULLTEXT', isa => 'Str' );
has 'file' => ( is => 'rw' );


sub BUILD {
  my $self = shift;
  $self->plugin_name('DB');
}

sub get_model {

  my $self=shift;
  my $model = Paperpile::Model::User->new();
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
