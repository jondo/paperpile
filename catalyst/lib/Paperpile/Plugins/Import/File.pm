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


package Paperpile::Plugins::Import::File;

use Mouse;
use Data::Dumper;
use File::Copy;
use File::Path;
use File::Temp qw(tempfile);

use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Paperpile::Utils;
use Paperpile::Formats;

extends 'Paperpile::Plugins::Import::DB';

has format  => ( is => 'rw', isa => 'Str' );
has 'file'  => ( is => 'rw', isa => 'Str' );
has '_data' => ( is => 'rw', isa => 'ArrayRef' );

sub BUILD {
  my $self = shift;
  $self->plugin_name('File');
}

sub connect {
  my $self = shift;

  if ( !-e $self->file ) {
    FileReadError->throw( error => "Could not find file " . $self->file );
  }

  if ( !-r $self->file ) {
    FileReadError->throw( error => "File " . $self->file . " is not readable." );
  }

  $self->_db_file( $self->_tmp_file_name( $self->file ) );

  if ( !-e $self->_db_file ) {

    my $reader = '';

    if ( $self->format ) {

      # not in use and untested
      $reader =
        eval( "Paperpile::Formats::" . $self->format . "->new(file=>'" . $self->file . "')" );
    } else {
      $reader = Paperpile::Formats->guess_format( $self->file );
    }

    if ( $reader->format eq 'PAPERPILE' ) {

      copy( $self->file, $self->_db_file )
        || FileWriteError->throw( error => "Could not open "
          . $self->file
          . " (failed to create temporary database representation)." );

      my $model = $self->get_model();
      $model->dbh->do("UPDATE Publications SET citekey=''");

    } else {

      my $data = $reader->read();

      foreach my $pub (@$data) {
        $pub->citekey('');
      }

      Paperpile::Utils->uniquify_pubs($data);

      my $empty_db = Paperpile::App->path_to('db','library.db');
      copy( $empty_db, $self->_db_file ) or die "Could not initialize empty db ($!)";

      my $model = $self->get_model();

      $model->insert_pubs( $data, 0 );

    }
  }

  my $model = $self->get_model();

  $self->total_entries( $model->fulltext_count( $self->query, 0 ) );
  return $self->total_entries;

}

sub cleanup {

  my $self = shift;

  unlink $self->_db_file;

}

sub _tmp_file_name {

  my ( $self, $bibfile ) = @_;

  my $path = File::Spec->catfile( Paperpile::Utils->get_tmp_dir, 'import' );

  mkpath($path);

  $bibfile =~ s/\//_/g;
  $bibfile =~ s/\./_/g;
  $bibfile .= '.ppl';

  return File::Spec->catfile( $path, $bibfile );

}

sub guess_format {

  my $self = shift;

  open( FILE, "<" . $self->file )
    || FileReadError->throw( error => "Could not open file " . $self->file );

  # Text file
  if ( -T $self->file ) {

    # Read only first 100 lines. Should be enough to identify file-type
    my $line;
    my @lines = ();
    while ( @lines < 100 and $line = <FILE> ) {
      next if $line =~ /^$/;
      push @lines, $line;
    }
    close(FILE);

    # Very simplistic. Probably need to get more specific/sensitive
    # patterns for real life data sometime
    my %patterns = (
      MODS    => qr/<\s*mods\s*/i,
      MEDLINE => qr/<PubmedArticle>/i,
      BIBTEX  => qr/\@\w+\{/i,
      ISI     => qr/^\s*AU /i,
      ENDNOTE => qr/^\s*%0 /i,
      RIS     => qr/^\s*TY\s+-\s+/i,
    );

    foreach my $line (@lines) {
      foreach my $format ( keys %patterns ) {
        my $pattern = $patterns{$format};
        if ( $line =~ $pattern ) {
          $self->format($format);
          return $format;
        }
      }
    }
  }

  # File is binary
  else {
    my $sample;
    read( FILE, $sample, 6 );
    if ( $sample ne 'SQLite' ) {
      FileFormatError->throw( error => "Could not open file (unknown format)" );
    } else {

      # Todo check if right version of Paperpile
      $self->format('PAPERPILE');
      return 'PAPERPILE';
    }
  }

  FileFormatError->throw( error => "Could not open file (unknown format)" );

}

1;
