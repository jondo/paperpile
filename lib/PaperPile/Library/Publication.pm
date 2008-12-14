package PaperPile::Library::Publication;
use Moose;
use Moose::Util::TypeConstraints;
use Digest::SHA1;
use PaperPile::Library::Author;
use PaperPile::Library::Journal;
use PaperPile::Schema::Publication;

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
  'STD',        # used by BibUtils, probably "standard" ?
);

has 'id'             => ( is => 'rw');
has 'pubtype'        => ( is => 'rw', isa => 'PublicationType');
has 'title'          => ( is => 'rw', isa => 'Str', default => 'No title.',
                          trigger => sub { my $self=shift; $self->refresh_fields} );
has 'title2'         => ( is => 'rw', isa => 'Str', default => 'No title.' );
has 'title3'         => ( is => 'rw', isa => 'Str', default => 'No title.' );
has 'authors_flat'   => ( is => 'rw', isa => 'Str' );
has 'editors_flat'   => ( is => 'rw', isa => 'Str' );
has 'authors_series' => ( is => 'rw', isa => 'Str' );
has 'journal_flat'   => ( is => 'rw', isa => 'Str' );
has 'journal_id'     => ( is => 'rw', isa => 'Str' );
has 'volume'         => ( is => 'rw', isa => 'Str' );
has 'issue'          => ( is => 'rw', isa => 'Str' );
has 'pages'          => ( is => 'rw', isa => 'Str' );
has 'publisher'      => ( is => 'rw', isa => 'Str' );
has 'city'           => ( is => 'rw', isa => 'Str' );
has 'address'        => ( is => 'rw', isa => 'Str' );
has 'date'           => ( is => 'rw', isa => 'Str' );
has 'year'           => ( is => 'rw', isa => 'Int' );
has 'month'          => ( is => 'rw', isa => 'Str' );
has 'day'            => ( is => 'rw', isa => 'Str' );
has 'issn'           => ( is => 'rw', isa => 'Str' );
has 'pmid'           => ( is => 'rw', isa => 'Int' );
has 'doi'            => ( is => 'rw', isa => 'Str' );
has 'url'            => ( is => 'rw', isa => 'Str' );
has 'abstract'       => ( is => 'rw', isa => 'Str' );
has 'notes'          => ( is => 'rw', isa => 'Str' );
has 'tags_flat'      => ( is => 'rw', isa => 'Str' );
has 'pdf'            => ( is => 'rw', isa => 'Str' );
has 'fulltext'       => ( is => 'rw', isa => 'Str' );
has 'imported'       => ( is => 'rw', isa => 'Bool', default => 0 );
has 'authors' => ( is => 'rw', isa => 'ArrayRef[PaperPile::Library::Author]',
                   trigger => sub { my $self=shift; $self->refresh_fields} );
has 'editors' => ( is => 'rw', isa => 'ArrayRef[PaperPile::Library::Author]' );
has 'journal' => ( is => 'rw', isa => 'PaperPile::Library::Journal' );

sub BUILD {

  my ( $self, $params ) = @_;

  $self->refresh_fields;

}

sub refresh_fields {

  ( my $self ) = @_;

  if ( $self->authors ) {
    my @tmp = ();
    foreach my $author ( @{ $self->authors } ) {
      push @tmp, $author->flat;
    }
    $self->authors_flat( join( ', ', @tmp ) );
  }

  if ( $self->editors ) {
    my @tmp = ();
    foreach my $editor ( @{ $self->editors } ) {
      push @tmp, $editor->flat;
    }
    $self->editors_flat( join( ', ', @tmp ) );
  }

  if ( $self->journal ) {
    $self->journal_flat( $self->journal->short );
  }

  if ( $self->authors and $self->title ) {
    $self->calculate_sha1;
  }

}

sub calculate_sha1 {

  ( my $self ) = @_;

  my $ctx = Digest::SHA1->new;

  $ctx->add( $self->authors_flat );
  $ctx->add( $self->title);
  $self->id( substr( $ctx->hexdigest, 0, 15 ) );

}

sub as_hash {

  ( my $self ) = @_;

  my %hash = ();

  foreach my $key ( $self->meta->get_attribute_list ) {
    my $value = $self->$key;

    # take only simple scalar and not refs of any sort
    next if ref($value);
    $hash{$key} = $value;
  }

  return {%hash};

}

1;

