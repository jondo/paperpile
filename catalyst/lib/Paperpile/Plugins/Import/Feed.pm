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

package Paperpile::Plugins::Import::Feed;

use Carp;
use Data::Page;
use Moose;
use Moose::Util::TypeConstraints;
use Data::Dumper;
use File::Copy;
use File::Path;
use File::Temp qw(tempfile);
use Bibutils;

use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Paperpile::Utils;
use Paperpile::Formats;

extends 'Paperpile::Plugins::Import::DB';

has 'id'    => ( is => 'rw', isa => 'Str' );
has 'url'   => ( is => 'rw', isa => 'Str' );
has 'file'  => ( is => 'rw', isa => 'Str' );
has '_data' => ( is => 'rw', isa => 'ArrayRef' );
has 'title' => ( is => 'rw', isa => 'Str', default => 'New Feed' );

# If reload is set the Feed is downloaded and a new database file is
# created. Otherwise we just read from the database as in a normal DB
# Plugin.
has 'reload'  => ( is => 'rw', isa => 'Str' );

sub BUILD {
  my $self = shift;
  $self->plugin_name('Feed');
}

sub connect {
  my $self = shift;

  $self->file( File::Spec->catfile( $self->_rss_dir, 'feed.rss' ) );
  $self->_db_file( File::Spec->catfile( $self->_rss_dir, 'feed.ppl' ) );

  if ( !-e $self->file or !-e $self->_db_file or $self->reload) {
    $self->update_feed;

    my $reader;

    $reader = Paperpile::Formats->guess_format( $self->file );

    my $data = $reader->read();

    if ( $reader->format eq 'RSS' ) {
      if ( $reader->title ) {
        $self->title( $reader->title );
      }
    }

    my %all = ();

    foreach my $pub (@$data) {
      $pub->citekey('');
      if ( defined $pub->sha1 ) {
        $all{ $pub->sha1 } = $pub;
      }
    }

    my $empty_db = Paperpile::Utils->path_to('db/library.db')->stringify;
    copy( $empty_db, $self->_db_file ) or die "Could not initialize empty db ($!)";

    my $model = $self->get_model();

    $model->insert_pubs( [ values %all ], 0 );

  }

  my $model = $self->get_model();

  $self->total_entries( $model->fulltext_count( $self->query, 0 ) );
  return $self->total_entries;

}

sub cleanup {

  my $self = shift;

  rmtree( $self->_rss_dir ) or die("Could not clean up RSS feed.");

}

sub update_feed {

  my $self = shift;

  my $browser = Paperpile::Utils->get_browser;

  my $response = $browser->get( $self->url );

  if ( $response->is_error ) {
    NetGetError->throw(
      error => 'Could not load feed (' . $response->message . ')',
      code  => $response->code
    );
  }

  open( FEED, ">" . $self->file )
    or FileWriteError->throw( error => "Could not write file" . $self->file );
  print FEED $response->content;
  close(FEED);

}

sub _rss_dir {

  my ( $self, $bibfile ) = @_;

  my $path = File::Spec->catfile( Paperpile::Utils->get_tmp_dir, 'rss', $self->id );

  mkpath($path);

  return $path;

}

1;
