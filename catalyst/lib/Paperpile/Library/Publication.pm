package Paperpile::Library::Publication;
use Moose;
use Moose::Util::TypeConstraints;
use Digest::SHA1;
use Data::Dumper;

use Paperpile::Library::Author;
use Paperpile::Library::Journal;
use Paperpile::Utils;
use Encode qw(encode_utf8);
use Text::Unidecode;
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
has '_rowid' => ( is => 'rw');

# The unique sha1 key which is currently calculated from title,
# authors and year.
has 'sha1' => ( is => 'rw' );

# Timestamp when the entry was created
has 'created' => ( is => 'rw');

# Flags entry as trashed
has 'trashed' => ( is => 'rw', isa => 'Int', default => 0 );

# Timestamp when it was last read
has 'last_read' => ( is => 'rw');

# How many times it was read
has 'times_read' => ( is => 'rw', isa => 'Int', default => 0 );

# If available, direct link to PDF goes in here
has 'pdf_url' => ( is => 'rw', default => '' );

# An attached PDF file, the path is relative to the paper_root user
# setting
has 'pdf' => ( is => 'rw', default => '' );

# Size of PDF in bytes
has 'pdf_size' => ( is => 'rw', default => 0, isa => 'Int' );

# The number of additional files that are associated with this entry
has 'attachments' => ( is => 'rw', isa => 'Int', default => 0 );

# User provided annotation "Notes", formatted in HTML
has 'annote' => ( is => 'rw', default => '' );

# Comma separated list of tags (known as "labels" in the UI)
has 'tags' => ( is => 'rw', default => '' );

# Comma separated list of folders
has 'folders' => ( is => 'rw', default => '' );


### Fields from the config file

my $config = Paperpile::Utils->get_config;
foreach my $field ( keys %{ $config->{pub_fields} } ) {

  # These contribute to the sha1 and need a trigger to re-calculate it
  # upon change
  if ( $field ~~ ['year','title', 'booktitle']) {
    has $field => (
      is      => 'rw',
      trigger => sub {
        my $self = shift;
        $self->refresh_fields;
      }
    );
  } elsif ( $field ~~ ['authors','editors']) {
    has $field => (
      is      => 'rw',
      trigger => sub {
        my $self = shift;
        $self->refresh_authors;
      }
    );
  } else {
    has $field => (
      is      => 'rw',
      default => ''
    );
  }
}

### Helper fields which have no equivalent field in the database

# Formatted strings to be displayed in the frontend.
has '_authors_display'  => ( is => 'rw');
has '_citation_display' => ( is => 'rw');

# If an entry is already in our database this field is true.
has '_imported' => ( is => 'rw', isa => 'Bool' );

# Some import plugins first only scrape partial information and store
# a link (or some other hint) how to complete this information
has '_details_link' => ( is => 'rw', default => '' );

# Is some kind of _details_link for Google Scholar. It is the link
# to British Library Direct, where bibliographic data is available. 
# In some cases it also offers the absract, which is impossible to  
# get directly from Google.
has '_google_BL_link' => ( is => 'rw', default => '' );

# Holds the linkout for a related article search.
has '_related_articles' => ( is => 'rw', default => '' );

# If a search in the local database returns a hit in the fulltext,
# abstract or notes the hit+context ('snippet') is stored in these
# fields
has '_snippets_text'     => ( is => 'rw');
has '_snippets_abstract' => ( is => 'rw');
has '_snippets_notes'    => ( is => 'rw');

# CSS style to highlight the entry in the frontend
has '_highlight' => ( is => 'rw', default => 'pp-grid-highlight0' );

# Holds the Google Scholar link to other versions of
# the same publication.
has '_all_versions' => ( is => 'rw', default => '' );

# Google Scholar gives the IP or URL as publisher. This is not
# that what we want to display as publisher, but it is useful
# for other purposes in the Google Scholar Plugin.
has '_www_publisher' => ( is => 'rw', default => '' );

# If true fields update themselves automatically. Is only activated
# after initial object creation in BUILD to avoid excessive redundant
# refreshing.
has '_auto_refresh'    => ( is => 'rw', isa => 'Int', default => 0);

# If set to true helper fields for gui (_citation_display,
# _author_display) are not generated. Thus we avoid created tons of
# author objects which is not always needed (e.g. for import).
has '_light' =>  ( is => 'rw', isa => 'Int', default => 0);


sub BUILD {
  my ( $self, $params ) = @_;

  $self->_auto_refresh(1);
  $self->refresh_authors;

}

# Function: refresh_fields

# Update dynamic fields like sha1 and formatted strings for display

sub refresh_fields {
  ( my $self ) = @_;

  return if (not $self->_auto_refresh);

  if (not $self->_light){

    ## Citation display string
    my $cit = $self->format_citation;
    if ($cit) {
      $self->_citation_display($cit);
    }

  }

  ## Sha1
  $self->calculate_sha1;

}

sub refresh_authors {

  ( my $self ) = @_;

  return if $self->_light;
  return if not ($self->_auto_refresh);

  ## Author display string
  my $authors = $self->format_authors;
  if ($authors) {
    $self->_authors_display($authors);
  }
  $self->refresh_fields;
}

# Function: calculate_sha1

# Calculate unique sha1 from several key fields. Needs more thought on
# what to include. Function is a mess right now.

sub calculate_sha1 {

  ( my $self ) = @_;

  my $ctx = Digest::SHA1->new;

  if ( ( $self->authors or $self->_authors_display or $self->editors ) and ($self->title or $self->booktitle)) {
    if ( $self->authors ) {
      $ctx->add( encode_utf8( $self->authors ) );
    } elsif ( $self->_authors_display and !$self->editors) {
      $ctx->add( encode_utf8( $self->_authors_display ) );
    }
    if ( $self->editors ) {
      $ctx->add( encode_utf8( $self->editors ) );
    }
    if ($self->title){
      $ctx->add( encode_utf8( $self->title ) );
    }
    if ($self->booktitle){
      $ctx->add( encode_utf8( $self->booktitle ) );
    }

    $self->sha1( substr( $ctx->hexdigest, 0, 15 ) );
  }
}

# Function: format_citation

# Currently this function return an adhoc Pubmed like citation format
# Replace this with proper formatting function once CSL is in place

sub format_citation {

  ( my $self ) = @_;

  my $cit = '';

  my $j = $self->journal;

  if ($j) {
    $j =~ s/\.//g;
    $cit .= '<i>' . $j . '</i>. ';
  }

  if ( $self->booktitle ) {
    if ( $self->pubtype eq 'INCOLLECTION' ) {
      $cit .= "in ";
    }
    if ( $self->title ) {
      $cit .= '<i>' . $self->booktitle . '</i>. ' if ( $self->title ne $self->booktitle );
    } else {
      $cit .= '<i>' . $self->booktitle . '</i>. ';
    }
  }

  $cit .= $self->howpublished . ' ' if ( $self->howpublished );
  $cit .= '<i>Unpublished</i>. '      if ( $self->pubtype eq 'UNPUBLISHED' );
  $cit .= '<i>PhD Thesis</i>. '       if ( $self->pubtype eq 'PHDTHESIS' );
  $cit .= '<i>Master\'s Thesis</i>. ' if ( $self->pubtype eq 'MASTERSTHESIS' );
  $cit .= $self->school . ' '         if ( $self->school );

  $cit .= '(' . $self->year . ') ' if ( $self->year );
  $cit .= $self->month             if ( $self->month );
  $cit .= '; '                     if $cit;

  if ( $self->pubtype eq 'ARTICLE' or $self->pubtype eq 'INPROCEEDINGS' ) {
    $cit .= '<b>' . $self->volume . '</b>:' if ( $self->volume );
    $cit .= '(' . $self->issue . ') '       if ( $self->issue );
    $cit .= $self->pages                    if ( $self->pages );
  }

  if ( $self->pubtype eq 'BOOK' or $self->pubtype eq 'INBOOK' or $self->pubtype eq 'INCOLLECTION' )
  {
    $cit .= $self->publisher . ', ' if ( $self->publisher );
    $cit .= $self->address . ' '    if ( $self->address );
  }

  $cit =~ s/\s*[;,.]\s*$//;

  return $cit;

}

sub format_authors {

  my $self = shift;

  #return "";

  my @display = ();
  if ( $self->authors ) {

    my $tmp = Paperpile::Library::Author->new();

    foreach my $a ( split( /\band\b/, $self->authors ) ) {

      #push @display, Paperpile::Library::Author->new( full => $a )->nice;
      $tmp->full($a);
      push @display, $tmp->nice;
      $tmp->clear;
    }
    $self->_authors_display( join( ', ', @display ) );
  }

  # We only show editors when no authors are given
  if ( $self->editors and !$self->authors ) {
    foreach my $a ( split( /\band\b/, $self->editors ) ) {
      push @display, Paperpile::Library::Author->new( full => $a )->nice;
    }
    $self->_authors_display( join( ', ', @display ) . ' (eds.)' );
  }

}

# Function: as_hash

# Return all fields as a simple HashRef.

sub as_hash {

  ( my $self ) = @_;

  my %hash = ();

  foreach my $key ( $self->meta->get_attribute_list ) {
    my $value = $self->$key;
    next if ref($value);

    # Force it to a number to be correctly converted to JSON
    if ($key ~~ ['attachments', 'times_read', 'trashed']){
      $value+=0;
    }

    # take only simple scalar and not refs of any sort
    $hash{$key} = $value;
  }

  return {%hash};

}

# Function: get_authors

# We store the authors in a flat string in BibTeX formatting This
# function returns an ArrayRef of Paperpile::Library::Author objects.
# if $editors is true, we return editors

sub get_authors {

  ( my $self, my $editors ) = @_;
  my @authors = ();

  my $data = $self->authors;

  if ($editors) {
    $data = $self->editors;
  }

  return [] if not $data;

  foreach my $a ( split( /\band\b/, $data ) ) {
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
  foreach my $a ( @{ $self->get_authors(0) } ) {
    if ( $a->collective ) {
      push @authors, $a->collective;
    } else {
      push @authors, $a->last;
    }
  }

  # if no authors are given we use editors
  if ( not @authors ) {

    foreach my $a ( @{ $self->get_authors(1) } ) {
      if ( $a->collective ) {
        push @authors, $a->collective;
      } else {
        push @authors, $a->last;
      }
    }
  }
  if ( not @authors ) {
    @authors = ('unnamed');
  }

  my $first_author = $authors[0];
  my $last_author  = $authors[$#authors];

  if ( $first_author eq $last_author ) {
    $last_author = "-";
  }

  my $YYYY = $self->year;
  my $YY   = $YYYY;

  my $title = $self->title;

  my @title_words = split( /\s+/, $title );

  my $journal = $self->journal;

  $journal      =~ s/\s+/_/g;
  $first_author =~ s/\s+/_/g;
  $last_author  =~ s/\s+/_/g;

  if ( defined $YY && length($YY) == 4 ) {
    $YY = substr( $YYYY, 2, 2 );
  }

  # [firstauthor]
  if ( $pattern =~ /\[((firstauthor)(:(\d+))?)\]/i ) {
    my $found_field = $1;
    $first_author = uc($first_author)      if $2 eq 'FIRSTAUTHOR';
    $first_author = ucfirst($first_author) if $2 eq 'Firstauthor';
    $first_author = lc($first_author)      if $2 eq 'firstauthor';
    $first_author = substr( $first_author, 0, $4 ) if $3;
    $pattern =~ s/$found_field/$first_author/g;
  }

  # [lastauthor]
  if ( $pattern =~ /\[((lastauthor)(:(\d+))?)\]/i ) {
    my $found_field = $1;
    $last_author = uc($last_author)      if $2 eq 'LASTAUTHOR';
    $last_author = ucfirst($last_author) if $2 eq 'Lastauthor';
    $last_author = lc($last_author)      if $2 eq 'lastauthor';
    $last_author = substr( $last_author, 0, $4 ) if $3;
    $pattern =~ s/$found_field/$last_author/g;
  }

  # [authors]
  if ( $pattern =~ /\[((authors)(\d*)(:(\d+))?)\]/i ) {
    my $found_field = $1;
    my $to          = @authors;
    $to = $3 if $3;
    foreach my $i ( 0 .. $to - 1 ) {
      $authors[$i] = substr( $authors[$i], 0, $5 ) if ($4);
      $authors[$i] = uc( $authors[$i] )      if $2 eq 'AUTHORS';
      $authors[$i] = ucfirst( $authors[$i] ) if $2 eq 'Authors';
      $authors[$i] = lc( $authors[$i] )      if $2 eq 'authors';
    }
    my $author_string = join( '_', @authors[ 0 .. $to - 1 ] );
    if ( $to < @authors ) {
      $author_string .= '_et_al';
    }
    $pattern =~ s/$found_field/$author_string/g;
  }

  # [title]
  if ( $pattern =~ /\[((title)(\d*)(:(\d+))?)\]/i ) {
    my $found_field = $1;
    my $to          = @title_words;
    $to = $3 if $3;
    foreach my $i ( 0 .. $to - 1 ) {
      $title_words[$i] = substr( $title_words[$i], 0, $5 ) if ($4);
      $title_words[$i] = uc( $title_words[$i] ) if $2 eq 'TITLE';

      #$title_words[$i] = ucfirst( $title_words[$i] ) if $2 eq 'Title';
      $title_words[$i] = lc( $title_words[$i] ) if $2 eq 'title';
    }
    my $title_string = join( '_', @title_words[ 0 .. $to - 1 ] );
    $pattern =~ s/$found_field/$title_string/g;
  }

  # [YY] and [YYYY]
  if ( defined $YYYY ) {
    $pattern =~ s/\[YY\]/$YY/g;
    $pattern =~ s/\[YYYY\]/$YYYY/g;
  }

  $pattern =~ s/\[journal\]/$journal/g;

  # Custom substitutions, given as parameter

  if ( defined $substitutions ) {
    foreach my $key ( keys %$substitutions ) {
      my $value = $substitutions->{$key};
      $pattern =~ s/\[$key\]/$value/g;
    }
  }

  # remove brackets that are still left
  $pattern =~ s/\[//g;
  $pattern =~ s/\]//g;

  # Try to change unicode character to the appropriate ASCII characters
  $pattern = unidecode($pattern);

  # Remove all remaining non-alphanumeric characters that might be left
  $pattern =~ s/\W//g;

  return $pattern;

}

sub format_csl {

  ( my $self ) = @_;

  my %output = ();

  $output{id} = $self->sha1;

  if ( $self->pubtype eq 'ARTICLE' ) {
    $output{'type'}            = 'article-journal';
    $output{'container-title'} = $self->journal;

    for my $field ( 'title', 'volume', 'issue' ) {
      $output{$field} = $self->$field;
    }

    $output{page} = $self->pages;

    $output{issued} = { year => $self->year };

    my @tmp = ();

    foreach my $author ( @{ $self->get_authors } ) {
      push @tmp, {
        'name'          => $author->full,
        'primary-key'   => $author->last,
        'secondary-key' => $author->first,
        };
    }

    $output{author} = [@tmp];
  }

  return {%output};

}

# Function: list_types

# Getter function for available publication types

sub list_types {
  return @types;
}

no Moose;

__PACKAGE__->meta->make_immutable;

1;

