# Copyright 2009-2011 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public License for more details.  You should have
# received a copy of the GNU Affero General Public License along with
# Paperpile.  If not, see http://www.gnu.org/licenses.


package Paperpile::Plugins::Import::Feed;

use Mouse;
use Data::Dumper;
use File::Copy;
use File::Path;
use File::Temp qw(tempfile);
use URI::Escape;

use Paperpile;
use Paperpile::Utils;
use Paperpile::Formats;
use Paperpile::Library::Publication;
use Paperpile::Library::Author;

extends 'Paperpile::Plugins::Import::DB';

has 'id'    => ( is => 'rw', isa => 'Str' );
has 'url'   => ( is => 'rw', isa => 'Str' ); # URI escaped url
has 'file'  => ( is => 'rw', isa => 'Str' );
has '_data' => ( is => 'rw', isa => 'ArrayRef' );
has 'title' => ( is => 'rw', isa => 'Str', default => 'New Feed' );

# If reload is set the Feed is downloaded and a new database file is
# created. Otherwise we just read from the database as in a normal DB
# Plugin.
has 'reload' => ( is => 'rw', isa => 'Str' );

sub BUILD {
  my $self = shift;
  $self->plugin_name('Feed');
}

sub connect {
  my $self = shift;

  $self->file( File::Spec->catfile( $self->_rss_dir, 'feed.rss' ) );
  $self->_db_file( File::Spec->catfile( $self->_rss_dir, 'feed.ppl' ) );

  if ( !-e $self->file or !-e $self->_db_file or $self->reload ) {
    $self->update_feed;

    my $reader;

    $reader = Paperpile::Formats->guess_format( $self->file );

    my $data = $reader->read();

    if ( $reader->format eq 'RSS' ) {
      if ( $reader->title ) {
        $self->title( $reader->title );
      }
    }

    foreach my $pub (@$data) {
      $pub->citekey('');
      $pub->_needs_details_lookup(1); # Initialize each pub to want a details lookup.
    }

    Paperpile::Utils->uniquify_pubs($data);

    my $empty_db = Paperpile->path_to('db','library.db');
    copy( $empty_db, $self->_db_file ) or die "Could not initialize empty db ($!)";

    my $model = $self->get_model();

    $model->insert_pubs( $data, 0 );

  }

  my $model = $self->get_model();

  $self->total_entries( $model->fulltext_count( $self->query, 0 ) );
  return $self->total_entries;

}

sub page {
  ( my $self, my $offset, my $limit ) = @_;

  my $page = $self->SUPER::page($offset, $limit);

  foreach my $pub (@$page) {
    $pub->_needs_details_lookup(1);
  }

  return $page;
}

sub cleanup {

  my $self = shift;

  rmtree( $self->_rss_dir ) or die("Could not clean up RSS feed.");

}

sub update_feed {

  my $self = shift;

  my $browser = Paperpile::Utils->get_browser;

  my $response = $browser->get( uri_unescape($self->url) );

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

sub complete_details {

  ( my $self, my $pub ) = @_;

  my $URL_plugin = Paperpile::Plugins::Import::URL->new(jobid=>$self->jobid);

  # Copied from GoogleScholar.pm, we try to use the linkout to match against the
  # publisher's URL.
  my $full_pub = undef;
  eval { $full_pub = $URL_plugin->match($pub) };
  if ($full_pub) {

    if ( $full_pub->title() ) {
      $full_pub->citekey('');

      # Update plugin _hash with new data
      $full_pub->guid( $pub->guid );
      $self->_hash->{ $pub->guid } = $full_pub;

      # refresh fields
      $full_pub->_light(0);
      $full_pub->refresh_fields();
      $full_pub->refresh_authors();
      $full_pub->_needs_details_lookup(0);

      return $full_pub;
    }
  }

  # If that didn't work, just use the standard match approach.
  my $plugin_list = [ split( /,/, Paperpile::Utils->get_model("Library")->get_setting('search_seq') ) ];
  $pub->auto_complete($plugin_list);
  $pub->_needs_details_lookup(0);
  return $pub;
}

sub needs_completing {
  ( my $self, my $pub ) = @_;

  return 1 if ( $pub->{_needs_details_lookup} );
  return 0;
}

sub needs_match_before_import {
  ( my $self, my $pub ) = @_;

  # Since our complete_details method is called before importing anyway
  # (see CRUD->_complete_pubs) we never need a full match before import.
  return 0;
}

sub _rss_dir {

  my ( $self, $bibfile ) = @_;

  my $path = File::Spec->catfile( Paperpile->tmp_dir, 'rss', $self->id );

  mkpath($path);

  return $path;

}

1;
