package Paperpile::Library::Publication;
use Moose;
use Moose::Util::TypeConstraints;
use Digest::SHA1;
use Data::Dumper;

use Paperpile::Library::Author;
use Paperpile::Library::Journal;
use Paperpile::Utils;
use Encode qw(encode_utf8);
use 5.010;

# Bibutils functions are in a submodule
extends('Paperpile::Library::Publication::Bibutils');

# We currently support the following publication types
our @types = qw(
  ARTICLE
  BOOK
  BOOKLET
  INBOOK
  INCOLLECTION
  PROCEEDINGS
  INPROCEEDINGS
  MANUAL
  MASTERSTHESIS
  PHDTHESIS
  TECHREPORT
  UNPUBLISHED
  MISC
);

# The fields in this objects are equivalent to the fields in the
# database table 'Publications'. Fields starting with underscore are
# special helper fields not stored in the database. In addition to
# built in fields which are hardcoded in the database schema and here
# in this Module, there is a list of fields stored (and documented) in
# the configuration file paperpile.yaml.

### 'Built-in' fields

# The unique rowid in the SQLite table 'Publications'
has '_rowid'      => ( is => 'rw', isa => 'Int' );

# The unique sha1 key which is currently calculated from title,
# authors and year.
has 'sha1'        => ( is => 'rw' );

# Timestamp when the entry was created
has 'created'     => ( is => 'rw', isa => 'Str' );

# Timestamp when it was last read
has 'last_read'   => ( is => 'rw', isa => 'Str' );

# How many times it was read
has 'times_read'  => ( is => 'rw', isa => 'Int', default => 0 );

# The associated PDF file, the path is relative to the paper_root user
# setting
has 'pdf' => ( is => 'rw', isa => 'Str', default => '' );

# The number of additional files that are associated with this entry
has 'attachments' => ( is => 'rw', isa => 'Int', default => 0 );

### Fiels from the config file

my $config = Paperpile::Utils->get_config;
foreach my $field ( keys %{ $config->{pub_fields} } ) {

  # These contribute to the sha1 and need a trigger to re-calculate it
  # upon change
  if ( $field =~ /(authors|editors|year|title$)/ ) {
    has $field => (
      is      => 'rw',
      isa     => 'Str',
      trigger => sub {
        my $self = shift;
        $self->refresh_fields;
      }
    );
  } else {
    has $field => (
      is      => 'rw',
      isa     => 'Str',
      default => ''
    );
  }
}

### Helper fields which have no equivalent field in the database

# Formatted strings to be displayed in the frontend.
has '_authors_display'   => ( is => 'rw', isa => 'Str' );
has '_citation_display'  => ( is => 'rw', isa => 'Str' );

# If an entry is already in our database this field is true.
has '_imported'          => ( is => 'rw', isa => 'Bool' );

# Some import plugins first only scrape partial information and store
# a link (or some other hint) how to complete this information
has '_details_link'      => ( is => 'rw', isa => 'Str' );

# If a search in the local database returns a hit in the fulltext,
# abstract or notes the hit+context ('snippet') is stored in these
# fields
has '_snippets_text'     => ( is => 'rw', isa => 'Str' );
has '_snippets_abstract' => ( is => 'rw', isa => 'Str' );
has '_snippets_notes'    => ( is => 'rw', isa => 'Str' );


sub BUILD {
  my ( $self, $params ) = @_;
  $self->refresh_fields;
}

# Function: refresh_fields

# Update dynamic fields like sha1 and formatted strings for display

sub refresh_fields {
  ( my $self ) = @_;

  ## Author display string
  my @display = ();
  if ( $self->authors ) {
    foreach my $a ( split( /\band\b/, $self->authors ) ) {
      push @display, Paperpile::Library::Author->new( full => $a )->nice;
    }
    $self->_authors_display( join( ', ', @display ) );
  }

  ## Citation display string
  my $cit = $self->format_citation;
  if ($cit) {
    $self->_citation_display($cit);
  }

  ## Sha1
  $self->calculate_sha1;

}

# Function: calculate_sha1

# Calculate unique sha1 from several key fields. Needs more thought on
# what to include. Function is a mess right now.

sub calculate_sha1 {

  ( my $self ) = @_;

  my $ctx = Digest::SHA1->new;

  if ( ( $self->authors or $self->_authors_display or $self->editors) and $self->title ) {
    if ( $self->authors ) {
      $ctx->add( encode_utf8( $self->authors ) );
    } elsif ($self->_authors_display) {
      $ctx->add( encode_utf8( $self->_authors_display ) );
    }
    if ($self->editors){
      $ctx->add( encode_utf8( $self->editors ) );
    }
    $ctx->add( encode_utf8( $self->title ) );
    $self->sha1( substr( $ctx->hexdigest, 0, 15 ) );
  }
}

# Function: format_citation

# Currently this functino return an adhoc Pubmed like citation formatq
# Replace this with proper formatting function once CSL is in place

sub format_citation {

  ( my $self ) = @_;

  my $cit = '';

  if ( $self->journal ) {
    $cit .= '<i>' . $self->journal . '</i>. ';
  }

  if ( $self->year ) {
    $cit .= '(' . $self->year . ') ';
  }

  if ( $self->month ) {
    $cit .= $self->month . '; ';
  } else {
    $cit .= '; ' if $cit;
  }

  if ( $self->volume ) {
    $cit .= '<b>' . $self->volume . '</b>:';
  }

  if ( $self->issue ) {
    $cit .= '(' . $self->issue . ') ';
  }

  if ( $self->pages ) {
    $cit .= $self->pages;
  }

  return $cit;

}

# Function: as_hash

# Return all fields as a simple HashRef.

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

# Function: get_authors

# We store the authors in a flat string in BibTeX formatting This
# function returns an ArrayRef of Paperpile::Library::Author objects.

sub get_authors {
  ( my $self ) = @_;
  my @authors = ();
  foreach my $a ( split( /\band\b/, $self->authors ) ) {
    $a =~ s/^\s+//;
    $a =~ s/\s+$//;
    push @authors, Paperpile::Library::Author->new( full => $a );
  }
  return [@authors];
}

# Function: format_pattern

# Generates a string from a pattern like [firstauthor][year] See code
# for available fields and syntax.

# The optional HashRef $substitutions can hold additional fields to be
# replaced dynamically. e.g {key => 'Gruber2009'} will replace [key]
# with 'Gruber2009'.

sub format_pattern {

  ( my $self, my $pattern, my $substitutions ) = @_;

  my @authors = ();
  foreach my $a ( @{ $self->get_authors } ) {
    push @authors, $a->last;
  }

  my $first_author = $authors[0];
  my $last_author  = $authors[$#authors];

  my $YYYY = $self->year;
  my $YY   = $YYYY;

  my $title = $self->title;

  my @title_words = split( /\s+/, $title );

  my $journal = $self->journal;

  $journal =~ s/\s+/_/g;

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

  # Custom susbstitutions, given as parameter

  if ( defined $substitutions ) {
    foreach my $key ( keys %$substitutions ) {
      my $value = $substitutions->{$key};
      $pattern =~ s/\[$key\]/$value/g;
    }
  }

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
    } elsif ( $format eq ':UC' ) {
      $field = uc($field);
    } elsif ( $format eq ':lc' ) {
      $field = lc($field);
    }
  }

  return $field;
}


# Function: list_types

# Getter function for available publication types

sub list_types {
  return @types;
}

1;

