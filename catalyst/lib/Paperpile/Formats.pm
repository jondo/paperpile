# Copyright 2009, 2010 Paperpile
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


package Paperpile::Formats;
use Moose;
use Moose::Util::TypeConstraints;
use Data::Dumper;
use File::Temp qw(tempfile);
use DBI;

use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Paperpile::Exceptions;
use Paperpile::Formats::Rss;
use Paperpile::Formats::Ris;

enum Format => qw(PAPERPILE BIBTEX CITEKEYS CITATIONS EMAIL RIS RSS ZOTERO MENDELEY HTML XMP);

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
      BIBTEX => qr/\@\w+\{/i,
      RIS    => qr/^\s*TY\s+-\s+/i,
      RSS    => qr/xml.*rss/is,
    );

    # In RSS feed xml tag and rss tag may be in different lines,
    # so we have to screen several lines at once
    foreach my $i ( 0 .. $#lines ) {
      my $inc_prev_lines = $lines[$i];
      for my $j ( 1 .. 5 ) {
        last if ( $i - $j ) < 0;
        $inc_prev_lines = $lines[ $i - $j ] . $inc_prev_lines;
      }
      foreach my $format ( keys %patterns ) {
        my $pattern = $patterns{$format};
        if ( $lines[$i] =~ $pattern ) {
          $format = lc($format);
          $format = ucfirst($format);
          my $module = "Paperpile::Formats::$format";
          return eval("use $module; $module->new(file=>'$file')");
        }
        if ( $inc_prev_lines =~ $pattern ) {
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

      # get a DBI connection to the SQLite file
      my $dbh = DBI->connect( "dbi:SQLite:$file", '', '', { AutoCommit => 1, RaiseError => 1 } );

      my $zotero_flag    = 0;
      my $mendeley_flag  = 0;
      my $paperpile_flag = 0;

      my $sth = $dbh->prepare("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;");
      $sth->execute();
      while ( my @tmp = $sth->fetchrow_array ) {
        $zotero_flag    = 1   if ( $tmp[0] eq 'zoteroDummyTable' );
        $mendeley_flag  = 0.5 if ( $tmp[0] eq 'DocumentContributors' );
        $mendeley_flag  = 1   if ( $tmp[0] eq 'RunsSinceLastCleanup' and $mendeley_flag == 0.5 );
        $paperpile_flag = 0.5 if ( $tmp[0] eq 'Fulltext_citation' );
        $paperpile_flag = 1   if ( $tmp[0] eq 'Fulltext_full' and $paperpile_flag == 0.5 );
      }

      #print STDERR "$zotero_flag $mendeley_flag $paperpile_flag\n";

      if ( $zotero_flag == 1 and $mendeley_flag == 0 and $paperpile_flag == 0 ) {
        my $module = "Paperpile::Formats::Zotero";
        return eval("use $module; $module->new(file=>'$file')");
      }
      if ( $zotero_flag == 0 and $mendeley_flag == 1 and $paperpile_flag == 0 ) {
        my $module = "Paperpile::Formats::Mendeley";
        return eval("use $module; $module->new(file=>'$file')");
      }
      if ( $zotero_flag == 0 and $mendeley_flag == 0 and $paperpile_flag == 1 ) {
        my $module = "Paperpile::Formats::Paperpile";
        return eval("use $module; $module->new(file=>'$file')");
      }
    }
  }

  FileFormatError->throw( error => "Could not open file (unknown format)" );

}

# Reads the data from $self->file and returns list of publication
# objects.

sub read {

  # Override in sub-class;

  die("You need to override 'read' in your 'Formats' class");

}

# Writes $self->data to $self->file;

sub write {

  # Override in sub-class;

  die("You need to override 'write' in your 'Formats' class");

}

# Wrapper around "read" that reads data from a string

sub read_string {

  my ( $self, $string ) = @_;

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


1;
