package PaperPile::Library;
use PaperPile::Library::Publication;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;

has 'entries' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] }
);

enum 'PublicationType' => (
  'ABST',      # Abstract
  'ADVS',      # Audiovisual material
  'ART',       # Art Work
  'BILL',      # Bill/Resolution
  'BOOK',      # Book, Whole
  'CASE',      # Case
  'CHAP',      # Book chapter
  'COMP',      # Computer program
  'CONF',      # Conference proceeding
  'CTLG',      # Catalog
  'DATA',      # Data file
  'ELEC',      # Electronic Citation
  'GEN',       # Generic
  'HEAR',      # Hearing
  'ICOMM',     # Internet Communication
  'INPR',      # In Press
  'JFULL',     # Journal (full)
  'JOUR',      # Journal
  'MAP',       # Map
  'MGZN',      # Magazine article
  'MPCT',      # Motion picture
  'MUSIC',     # Music score
  'NEWS',      # Newspaper
  'PAMP',      # Pamphlet
  'PAT',       # Patent
  'PCOMM',     # Personal communication
  'RPRT',      # Report
  'SER',       # Serial (Book, Monograph)
  'SLIDE',     # Slide
  'SOUND',     # Sound recording
  'STAT',      # Statute
  'THES',      # Thesis/Dissertation
  'UNBILl',    # Unenacted bill/resolution
  'UNPB',      # Unpublished work
  'VIDEO',     # Video recording
  'STD',       # used by BibUtils, probably "standard" ?
);


sub import_ris {

    ( my $self, my $file ) = @_;

    if ( not open( RIS, "<$file" ) ) {
        warn("Could not open file $file for reading. ($!)");
        return;
    }

    my $ris = '';
    $ris .= $_ while (<RIS>);

    while ( $ris =~ /(TY.*?)ER/sg ) {
        my $pub = PaperPile::Library::Publication->new();
        $pub->import_ris($1);
        push @{ $self->entries }, $pub;
      }

}

1;

