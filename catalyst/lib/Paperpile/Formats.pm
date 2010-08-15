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

package Paperpile::Formats;
use Moose;
use Moose::Util::TypeConstraints;
use Data::Dumper;
use File::Temp qw(tempfile);
use Bibutils;

use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Paperpile::Exceptions;
use Paperpile::Formats::Rss;

enum Format => qw(PAPERPILE BIBTEX CITEKEYS CITATIONS EMAIL MODS ISI ENDNOTE ENDNOTEXML RIS WORD2007 MEDLINE RSS ZOTERO HTML);

has 'data' => ( is => 'rw', isa => 'ArrayRef[Paperpile::Library::Publication]' );
has format => ( is => 'rw', isa => 'Format' );
has 'file' => ( is => 'rw', isa => 'Str' );
has 'settings' => (
  is      => 'rw',
  isa     => 'HashRef',
  default => sub { return {} }
);

has 'readable' => ( is => 'rw', default => 0 );
has 'writable' => ( is => 'rw', default => 0 );

# Takes a file name and returns a subclass of Paperpile::Formats
# corresponding to the right format.

sub guess_format {

  my ( $self, $file ) = @_;

  open( FILE, "<$file" )
    || FileReadError->throw( error => "Could not open file $file" );

  # Text file
  if ( -T $file ) {

    # Read only first 500 lines. Should be enough to identify file-type
    my $line;
    my @lines = ();
    while ( @lines < 500 and $line = <FILE> ) {
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
      RSS     => qr/rss/i,               # add here proper signature for RSS
    );

    foreach my $line (@lines) {
      foreach my $format ( keys %patterns ) {
        my $pattern = $patterns{$format};
        if ( $line =~ $pattern ) {
          $format = lc($format);
          $format = ucfirst($format);
          my $module = "Paperpile::Formats::$format";
          return eval("use $module; $module->new(file=>'$file')");
        }
      }
    }
  }

  # File is binary
  else {
    # Check if it is a sqlite database
    my $sample;
    read( FILE, $sample, 6 );
    if ( $sample ne 'SQLite' ) {
      FileFormatError->throw( error => "Could not open file (unknown format)" );
    } else {
      # TODO: Here we need to check what kind of supported sqlite3
      # database it is:
      # * Zotero
      # * Mendeley
      # * Paperpile
      # If possible we also should check the version and throw an
      # error if we don't support it.

      return Paperpile::Formats::Paperpile->new( file => $file );
    }
  }

  FileFormatError->throw( error => "Could not open file (unknown format)" );

}

# Reads the data from $self->file; Defaults to using
# Bibutils. Override this function to read other formats or
# postprocess data read from bibutils

sub read {

  my $self = shift;

  return $self->read_bibutils;

}

# Writes $self->data to $self->file; Defaults to using
# Bibutils. Override this function to write other formats or
# preprocess data before writing.

sub write {

  my $self = shift;

  return $self->write_bibutils;

}

# Wrapper around "read" that reads data from a string

sub read_string {

  my ( $self, $string ) = @_;

  my $in_format = eval( 'Bibutils::' . $self->format . 'IN' );

  my ( $fh, $file_name ) = tempfile();

  print $fh $string;
  close($fh);

  $self->file($file_name);

  my $data = $self->read();

  unlink($file_name);

  return $data;

}

# Wrapper around "write" that writes data from a string

sub write_string {

  my $self = shift;

  my ( $fh, $file_name ) = tempfile();
  close($fh);

  $self->file($file_name);

  $self->write();

  my $string = '';
  open( TMP, "<$file_name" );
  $string .= $_ foreach (<TMP>);

  return $string;

}

sub read_bibutils {

  my $self = shift;

  my $bu = Bibutils->new(
    in_file    => $self->file,
    out_file   => '',
    in_format  => eval( 'Bibutils::' . $self->format . 'IN' ),
    out_format => Bibutils::BIBTEXOUT,
  );

  $bu->read;

  if ( $bu->error ) {
    FileFormatError->throw( error => "Could not read " . $self->file . ". Error during parsing." );
  }

  my $data = $bu->get_data;

  my @output = ();

  foreach my $entry (@$data) {
    my $pub = Paperpile::Library::Publication->new;
    $pub->_build_from_bibutils($entry);
    push @output, $pub;
  }

  return [@output];

}

sub write_bibutils {

  my ($self) = @_;

  my %s = %{ $self->settings };

  my @bibutils = ();

  foreach my $pub ( @{ $self->data } ) {
    push @bibutils, $pub->_format_bibutils;
  }

  my %formats = (
    MODS     => Bibutils::MODSOUT,
    BIBTEX   => Bibutils::BIBTEXOUT,
    RIS      => Bibutils::RISOUT,
    ENDNOTE  => Bibutils::ENDNOTEOUT,
    ISI      => Bibutils::ISIOUT,
    WORD2007 => Bibutils::WORD2007OUT,
  );

  my $bu = Bibutils->new(
    in_file    => '',
    out_file   => $self->file,
    in_format  => Bibutils::BIBTEXIN,
    out_format => $formats{ $self->format },
  );

  $bu->set_data( [@bibutils] );

  $bu->write( {%s} );

  my $error = $bu->error;

  if ( $error != 0 ) {

    #my $msg = "Data could not be exported. ";
    #if ( $error == Bibutils::ERR_CANTOPEN ) {
    #  $msg .= "Could not open file.";
    #}
    #if ( $error == Bibutils::ERR_MEMERR ) {
    #  $msg .= "Not enough memory.";
    #}

    FileWriteError->throw( error => "Could not write " . $self->settings->{out_file} );

  }
}

1;
