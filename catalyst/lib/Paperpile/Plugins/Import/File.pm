package Paperpile::Plugins::Import::File;

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
use Paperpile::Library::Journal;
use Paperpile::Utils;

extends 'Paperpile::Plugins::Import::DB';

enum Format => qw(PAPERPILE BIBTEX MODS ISI ENDNOTE ENDNOTEXML RIS MEDLINE);

has format  => ( is => 'rw', isa => 'Format' );
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

    $self->guess_format if not $self->format;

    if ( $self->format eq 'PAPERPILE' ) {

      copy( $self->file, $self->_db_file )
        || FileWriteError->throw(
        error => "Could not open " . $self->file . " (failed to create temporary database representation)." );

      my $model = $self->get_model();
      $model->dbh->do("UPDATE Publications SET citekey=''");

    } else {

      my $bu = Bibutils->new(
        in_file    => $self->file,
        out_file   => '',
        in_format  => eval( 'Bibutils::' . $self->format . 'IN' ),
        out_format => Bibutils::BIBTEXOUT,
      );

      $bu->read;

      if ( $bu->error ) {
        FileFormatError->throw(
          error => "Could not read " . $self->file . ". Error during parsing." );
      }

      my $data = $bu->get_data;

      # Collect pubs in hash to avoid entries with duplicate sha1 which
      # causes problems when converting to database. Maybe this is too
      # simplistic to deal with duplicates at this stage but it works...
      my %all = ();

      foreach my $entry (@$data) {
        my $pub = Paperpile::Library::Publication->new;
        $pub->_build_from_bibutils($entry);
        $pub->citekey('');
	if (defined $pub->sha1) {
          $all{ $pub->sha1 } = $pub;
	}
      }


      my $empty_db = Paperpile::Utils->path_to('db/library.db')->stringify;
      copy( $empty_db, $self->_db_file ) or die "Could not initialize empty db ($!)";

      my $model = $self->get_model();

      $model->insert_pubs( [ values %all ] );

    }
  }

  my $model = $self->get_model();

  $self->total_entries( $model->fulltext_count( $self->query, $self->search_pdf ) );
  return $self->total_entries;

}

sub cleanup {

  my $self=shift;

  unlink $self->_db_file;

}

sub _tmp_file_name {

  my ($self, $bibfile) = @_;

  my $path=Paperpile::Utils->path_to("tmp/import")->stringify;
  mkpath($path);

  $bibfile=~s/\//_/g;
  $bibfile=~s/\./_/g;
  $bibfile.='.ppl';

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
      FileFormatError->throw( error => "Could not open file (unknown format)");
    } else {
      # Todo check if right version of Paperpile
      $self->format('PAPERPILE');
      return 'PAPERPILE';
    }
  }

  FileFormatError->throw( error => "Could not open file (unknown format)");

}


1;
