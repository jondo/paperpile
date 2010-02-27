# Copyright 2009, 2010 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.  You should have received a
# copy of the GNU General Public License along with Paperpile.  If
# not, see http://www.gnu.org/licenses.

package Paperpile::Plugins::Import::Trash;

use Carp;
use Data::Page;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;
use Paperpile::Utils;
use Paperpile::Model::Library;
use Paperpile::Library::Publication;
use Paperpile::Library::Author;

extends 'Paperpile::Plugins::Import';

has 'query' => ( is => 'rw' );
has 'mode'  => ( is => 'rw', default => 'FULLTEXT', isa => 'Str' );
has 'file'  => ( is => 'rw' );
has 'search_pdf' => ( is => 'rw', default => 1 );
has 'order'      => ( is => 'rw', default => 'created DESC' );
has '_db_file'   => ( is => 'rw' );

sub BUILD {
  my $self = shift;
  $self->plugin_name('Trash');
}

sub get_model {

  my $self  = shift;
  my $model = Paperpile::Model::Library->new();
  $model->set_dsn( "dbi:SQLite:" . $self->_db_file );
  return $model;

}

sub connect {
  my $self = shift;

  $self->_db_file( $self->file );

  return $self->update_count();
}

sub page {
  ( my $self, my $offset, my $limit ) = @_;

  my $model = $self->get_model;

  my $page;

  $page =
    $model->fulltext_search( $self->query, $offset, $limit, $self->order, $self->search_pdf, 1 );

  $self->_save_page_to_hash($page);

  return $page;

}

sub update_count {
  ( my $self ) = @_;
  my $model = $self->get_model;

  $self->total_entries( $model->fulltext_count( $self->query, $self->search_pdf, 1 ) );

  return $self->total_entries;

}

1;
