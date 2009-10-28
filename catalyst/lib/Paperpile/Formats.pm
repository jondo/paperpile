package Paperpile::Formats;
use Moose;
use Moose::Util::TypeConstraints;
use Data::Dumper;
use File::Temp qw(tempfile);
use Bibutils;

use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Paperpile::Library::Journal;
use Paperpile::Exceptions;
use Paperpile::Formats::Rss;

enum Format => qw(PAPERPILE BIBTEX MODS ISI ENDNOTE ENDNOTEXML RIS MEDLINE RSS);

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
      RSS     => qr/rss/i, # add here proper signature for RSS
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
    my $sample;
    read( FILE, $sample, 6 );
    if ( $sample ne 'SQLite' ) {
      FileFormatError->throw( error => "Could not open file (unknown format)" );
    } else {
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

  print STDERR "==============> Start Bibutils\n";
  print STDERR scalar localtime, "\n";

  my $bu = Bibutils->new(
    in_file    => $self->file,
    out_file   => '',
    in_format  => eval( 'Bibutils::' . $self->format . 'IN' ),
    out_format => Bibutils::BIBTEXOUT,
  );

  $bu->read;

  print STDERR "==============> End reading Bibutils read\n";
  print STDERR scalar localtime, "\n";

  if ( $bu->error ) {
    FileFormatError->throw( error => "Could not read " . $self->file . ". Error during parsing." );
  }

  my $data = $bu->get_data;

  print STDERR "==============> End reading Bibutils get_data\n";
  print STDERR scalar localtime, "\n";

  my @output = ();

  foreach my $entry (@$data) {
    my $pub = Paperpile::Library::Publication->new;
    $pub->_build_from_bibutils($entry);
    push @output, $pub;
  }

  print STDERR "==============> End converting from Bibutils\n";
  print STDERR scalar localtime, "\n";

  return [];

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
