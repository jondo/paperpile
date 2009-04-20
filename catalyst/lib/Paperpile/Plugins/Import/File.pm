package Paperpile::Plugins::Import::File;

use Carp;
use Data::Page;
use Moose;
use Moose::Util::TypeConstraints;
use Data::Dumper;
use Bibutils;

use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Paperpile::Library::Journal;

extends 'Paperpile::Plugins::Import';

enum Format => qw(BIBTEX MODS ISI ENDNOTE ENDNOTEXML RIS MEDLINE);

has format  => ( is => 'rw', isa => 'Format' );
has 'file'  => ( is => 'rw', isa => 'Str' );
has '_data' => ( is => 'rw', isa => 'ArrayRef' );

sub connect {
  my $self = shift;

  $self->guess_format if not $self->format;

  my $bu = Bibutils->new(
  in_file    => $self->file,
  out_file   => '',
  in_format  => eval('Bibutils::'.$self->format.'IN'),
  out_format => Bibutils::BIBTEXOUT,
  );

  $bu->read;

  my $data = $bu->get_data;

  $self->_data([]);

  foreach my $entry (@$data){
    my $pub = Paperpile::Library::Publication->new;
    $pub->_build_from_bibutils($entry);
    push @{$self->_data}, $pub;
  }

  $self->total_entries( scalar( @{ $self->_data } ) );

  return $self->total_entries;

}

sub page {

  ( my $self, my $offset, my $limit ) = @_;

  my @page = ();

  for my $i ( 0 .. $limit - 1 ) {
    last if ($offset + $i == $self->total_entries );
    push @page, $self->_data->[ $offset + $i ];
  }

  $self->_save_page_to_hash(\@page);

  return \@page;

}

sub guess_format {

  my $self = shift;

  open( FILE, "<" . $self->file ) || die "Could not open file " . $self->file . " ($!)";

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

  return undef;
}


1;
