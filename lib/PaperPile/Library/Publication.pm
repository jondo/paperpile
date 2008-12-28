package PaperPile::Library::Publication;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Timestamp;
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
  'STD',       # used by BibUtils, probably "standard" ?
);

has 'sha1'    => ( is => 'rw' );
has 'rowid'   => ( is => 'rw', isa => 'Int' );
has 'pubtype' => ( is => 'rw', isa => 'PublicationType' );
has 'key'     => ( is => 'rw', isa => 'Str' );
has 'title' => (
  is      => 'rw',
  isa     => 'Str',
  default => 'No title.',
  trigger => sub { my $self = shift; $self->refresh_fields }
);
has 'title2' => ( is => 'rw', isa => 'Str', default => 'No title.' );
has 'title3' => ( is => 'rw', isa => 'Str', default => 'No title.' );
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
has 'text'       => ( is => 'rw', isa => 'Str' );
has 'imported'       => ( is => 'rw', isa => 'Bool', default => 0 );
has 'authors' => (
  is      => 'rw',
  isa     => 'ArrayRef[PaperPile::Library::Author]',
  trigger => sub { my $self = shift; $self->refresh_fields }
);
has 'editors' => ( is => 'rw', isa => 'ArrayRef[PaperPile::Library::Author]' );
has 'journal' => ( is => 'rw', isa => 'PaperPile::Library::Journal' );
has 'created' => ( is => 'rw', isa => 'Timestamp' );
has 'last_read' => ( is => 'rw', isa => 'Timestamp' );



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
  $ctx->add( $self->title );
  $self->sha1( substr( $ctx->hexdigest, 0, 15 ) );

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

sub format {

  ( my $self, my $pattern ) = @_;

  my @authors = ();

  foreach my $a ( @{ $self->authors } ) {
    push @authors, $a->last_name;
  }

  my $first_author = $authors[0];
  my $last_author  = $authors[$#authors];

  my $YYYY = $self->year;
  my $YY   = $YYYY;

  my $title = $self->title;

  my @title_words = split( /\s+/, $title );

  my $journal = $self->journal_flat;

  if ( length($YY) == 4 ) {
    $YY = substr( $YYYY, 2, 2 );
  }

  # [firstauthor]
  if ( $pattern =~ /\[(firstauthor(_abbr(\d+))?(:Uc|:UC|:lc)?)\]/ ) {
    my $found_field = $1;
    $first_author = substr( $first_author, 0, $3 ) if $2;
    $first_author = _setcase( $first_author, $4 );
    $pattern =~ s/$found_field/$first_author/g;
  }

  # [lastauthor]
  if ( $pattern =~ /\[(lastauthor(_abbr(\d+))?(:Uc|:UC|:lc)?)\]/ ) {
    my $found_field = $1;
    $first_author = substr( $last_author, 0, $3 ) if $2;
    $first_author = _setcase( $last_author, $4 );
    $pattern =~ s/$found_field/$last_author/g;
  }

  # [authors]
  if ( $pattern =~ /\[(authors(\d*)(_abbr(\d+))?(:Uc|:UC|:lc)?)\]/ ) {
    my $found_field = $1;
    my $to          = @authors;
    $to = $2 if $2;
    foreach my $i ( 0 .. $to - 1 ) {
      $authors[$i] = substr( $authors[$i], 0, $4 ) if ($3);
      $authors[$i] = _setcase( $authors[$i], $5 );
    }
    my $author_string = join( '_', @authors[ 0 .. $to - 1 ] );
    if ( $to < @authors ) {
      $author_string .= '_et_al';
    }
    $pattern =~ s/$found_field/$author_string/g;
  }

  # [title]
  if ( $pattern =~ /\[(title(\d*)(_abbr(\d+))?(:Uc|:UC|:lc)?)\]/ ) {
    my $found_field = $1;
    my $to          = @title_words;
    $to = $2 if $2;
    foreach my $i ( 0 .. $to - 1 ) {
      $title_words[$i] = substr( $title_words[$i], 0, $4 ) if ($3);
      $title_words[$i] = _setcase( $title_words[$i], $5 );
    }
    my $title_string = join( '_', @title_words[ 0 .. $to - 1 ] );
    $pattern =~ s/$found_field/$title_string/g;
  }

  # [YY] and [YYYY]
  $pattern =~ s/\[YY\]/$YY/g;
  $pattern =~ s/\[YYYY\]/$YYYY/g;

  $pattern =~ s/\[journal\]/$journal/g;

  # remove brackets that are still left
  $pattern =~ s/\[//g;
  $pattern =~ s/\]//g;

  return $pattern;

}

sub _setcase {

  ( my $field, my $format ) = @_;

  return $field if not defined $format;

  if ($format) {
    if ( $format eq ':Uc' ) {
      $field = ucfirst($field);
    }
    elsif ( $format eq ':UC' ) {
      $field = uc($field);
    }
    elsif ( $format eq ':lc' ) {
      $field = lc($field);
    }
  }

  return $field;
}

1;

