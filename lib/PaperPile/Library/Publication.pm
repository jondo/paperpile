package PaperPile::Library::Publication;
use Moose;
use Digest::SHA1;
use Data::Dumper;

use PaperPile::Library::Author;
use PaperPile::Library::Journal;
use PaperPile::Utils;
use Bibutils;

use 5.010;

# Built-in fields
has 'sha1'       => ( is => 'rw' );
has '_rowid'     => ( is => 'rw', isa => 'Int' );
has 'created'    => ( is => 'rw', isa => 'Str' );
has 'last_read'  => ( is => 'rw', isa => 'Str' );
has 'times_read' => ( is => 'rw', isa => 'Int', default => 0 );
has 'pdf'        => ( is => 'rw', isa => 'Str', default => '' );

# Read other fields from config file

my %config = PaperPile::Utils->get_config;
foreach my $field ( keys %{ $config{fields} } ) {

  if ( $field =~ /(authors|year|title$)/ ) {
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

# Helper fields which have no equivalent field in the database
has '_authors_nice'  => ( is => 'rw', isa => 'Str' );
has '_citation_nice' => ( is => 'rw', isa => 'Str' );
has '_imported'      => ( is => 'rw', isa => 'Bool' );

sub BUILD {
  my ( $self, $params ) = @_;
  $self->refresh_fields;
}

sub refresh_fields {
  ( my $self ) = @_;

  my @nice = ();

  if ( $self->authors ) {
    foreach my $a ( split( /\band\b/, $self->authors ) ) {
      push @nice, PaperPile::Library::Author->new( full => $a )->nice;
    }
    $self->_authors_nice( join( ', ', @nice ) );
  }

  $self->format_citation;

  $self->calculate_sha1;

}

sub calculate_sha1 {

  ( my $self ) = @_;

  my $ctx = Digest::SHA1->new;

  if ( $self->authors and $self->title ) {
    $ctx->add( $self->_authors_nice );
    $ctx->add( $self->title );
    $self->sha1( substr( $ctx->hexdigest, 0, 15 ) );
  }

}

# Simple Pubmed like citation format
# Replace this with proper formatting function,
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
    $cit .= '; ';
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

  $self->_citation_nice($cit);

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

sub get_authors {
  ( my $self ) = @_;
  my @authors = ();
  foreach my $a ( split( /\band\b/, $self->authors ) ) {
    $a =~ s/^\s+//;
    $a =~ s/\s+$//;
    push @authors, PaperPile::Library::Author->new( full => $a );
  }
  return [@authors];
}

sub format {

  ( my $self, my $pattern ) = @_;

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

sub prepare_bibutils_fields {

  my $self=shift;

}

sub build_from_bibutils {

  my ( $self, $data ) = @_;

  foreach my $field (@$data) {
    print "$field->{level}, $field->{tag}, $field->{data}\n";
  }

  my $map;
  $map->{ ARTICLE => { AUTHOR => [ 'author', '' ],
                       TITLE =>  [ 'title', 'journal'],
                       TITLE =>  [ 'title', 'journal'],

                     },

        };

  $map->{ARTICLE}->{AUTHOR} = [ 'author', '' ];

  #	REFTYPE( "article", article ),
  #	REFTYPE( "booklet", book ),
  #	REFTYPE( "book", book ),
  #	REFTYPE( "electronic", electronic ),
  #	REFTYPE( "inbook", inbook ),
  # 	REFTYPE( "incollection", incollection ),
  # 	REFTYPE( "inconference", inproceedings ),
  # 	REFTYPE( "inproceedings", inproceedings ),
  # 	REFTYPE( "manual", manual ),
  # 	REFTYPE( "mastersthesis", masters ),
  # 	REFTYPE( "misc", misc ),
  # 	REFTYPE( "patent", patent ),
  # 	REFTYPE( "phdthesis", phds ),
  # 	REFTYPE( "periodical", periodical ),
  # 	REFTYPE( "proceedings", proceedings ),
  # 	REFTYPE( "standard", standard ),
  # 	REFTYPE( "techreport", report ),
  # 	REFTYPE( "unpublished", unpublished ),

  #   static lookups incollection[] = {
  # 	{ "author",    "AUTHOR",    PERSON, LEVEL_MAIN },
  # 	{ "translator",   "TRANSLATOR",PERSON, LEVEL_MAIN },
  # 	{ "editor",    "EDITOR",    PERSON, LEVEL_HOST },
  # 	{ "title",     "TITLE",     TITLE,  LEVEL_MAIN },
  # 	{ "chapter",   "TITLE",     TITLE,  LEVEL_MAIN },
  # 	{ "booktitle", "TITLE",     TITLE,  LEVEL_HOST },
  # 	{ "series",    "TITLE",     TITLE,  LEVEL_SERIES },
  # 	{ "publisher", "PUBLISHER", SIMPLE, LEVEL_HOST },
  # 	{ "address",   "ADDRESS",   SIMPLE, LEVEL_HOST },
  # 	{ "year",      "YEAR",      SIMPLE, LEVEL_HOST },
  # 	{ "month",     "MONTH",     SIMPLE, LEVEL_HOST },
  # 	{ "day",       "DAY",       SIMPLE, LEVEL_HOST },
  # 	{ "volume",    "VOLUME",    SIMPLE, LEVEL_MAIN },
  # 	{ "number",    "NUMBER",    SIMPLE, LEVEL_MAIN },
  # 	{ "pages",     "PAGES",     PAGES,  LEVEL_MAIN },
  # 	{ "isbn",      "ISBN",      SIMPLE, LEVEL_HOST },
  # 	{ "lccn",      "LCCN",      SIMPLE, LEVEL_HOST },
  # 	{ "edition",   "EDITION",   SIMPLE, LEVEL_HOST },
  # 	{ "abstract",  "ABSTRACT",  SIMPLE, LEVEL_MAIN },
  # 	{ "contents",  "CONTENTS",  SIMPLE, LEVEL_HOST },
  # 	{ "language",     "LANGUAGE",     SIMPLE, LEVEL_MAIN },
  # 	{ "type",      "TYPE",      SIMPLE, LEVEL_MAIN },
  # 	{ "note",         "NOTES",        SIMPLE, LEVEL_MAIN },
  # 	{ "key",          "BIBKEY",          SIMPLE, LEVEL_MAIN },
  # 	{ "doi",       "DOI",       SIMPLE, LEVEL_MAIN },
  # 	{ "ftp",       "URL",       BIBTEX_URL, LEVEL_MAIN },
  # 	{ "url",       "URL",       BIBTEX_URL, LEVEL_MAIN },
  # 	{ "location",     "LOCATION",     SIMPLE, LEVEL_HOST },
  # 	{ "howpublished", "URL",    BIBTEX_URL, LEVEL_MAIN },
  # 	{ "refnum",    "REFNUM",    SIMPLE, LEVEL_MAIN },
  # 	{ "crossref",     "CROSSREF",  SIMPLE, LEVEL_MAIN },
  # 	{ "keywords",     "KEYWORD",   SIMPLE, LEVEL_MAIN },
  # 	{ " ",         "TYPE|INCOLLECTION",   ALWAYS, LEVEL_MAIN },
  # 	{ " ",         "RESOURCE|text", ALWAYS, LEVEL_MAIN },
  # 	{ " ",         "ISSUANCE|monographic", ALWAYS, LEVEL_MAIN },
  # 	{ " ",         "GENRE|collection",    ALWAYS, LEVEL_HOST }

}

1;

