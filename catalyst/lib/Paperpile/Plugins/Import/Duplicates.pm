package Paperpile::Plugins::Import::Duplicates;

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

has '_db_file' => ( is => 'rw' );
has 'file' => ( is => 'rw' );

sub BUILD {
  my $self = shift;
  $self->plugin_name('Duplicates');
}

sub get_model {

  my $self=shift;
  my $model = Paperpile::Model::Library->new();
  $model->set_dsn("dbi:SQLite:".$self->_db_file);
  return $model;

}

sub connect {
  my $self = shift;

  $self->_db_file($self->file);

  my $model=$self->get_model;

  $self->total_entries( $model->fulltext_count("") );

  return $self->total_entries;
}

sub page {
  ( my $self, my $offset, my $limit ) = @_;

  my $model=$self->get_model;

  my $page;

  $page = $model->fulltext_search( "", $offset, $limit);

  $self->_save_page_to_hash($page);

  return $page;

}

1;
