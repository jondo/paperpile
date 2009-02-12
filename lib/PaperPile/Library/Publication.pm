package PaperPile::Library::Publication;
use Moose;
use Moose::Util::TypeConstraints;
use Digest::SHA1;
use Data::Dumper;

use PaperPile::Library::Author;
use PaperPile::Library::Journal;
use PaperPile::Utils;
use Bibutils;

use 5.010;

my @types=qw( ARTICLE
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
              MISC );

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

sub list_types {
  return @types;
}

sub build_from_bibutils {

  my ( $self, $data ) = @_;

  my $type = $self->_get_type_from_bibutils($data);

  ## TODO: currently not handled:
  # CONTENTS (don't know)
  # ASSIGNEE (for patents)
  # CROSSREF (special for BibTeX)
  # LCCN (library of congress card number)
  # PAPER (not sure what this is; can obviously occur in INPROCEEDINGS but non standard BibTEX)
  # BIBKEY (BibTeX specific)
  # TRANSLATOR
  # LANGUAGE
  # REFNUM
  # REVISION (field for type "STANDARD" which we currently have not included)
  # LOCATION
  # NATIONALITY (for patents)

  my $map = {
    'REFNUM'             => 'citekey',
    'BIBKEY'             => 'sortkey',
    'ABSTRACT'           => 'abstract',
    'DOI'                => 'doi',
    'DAY'                => 'day',
    'YEAR'               => 'year',
    'MONTH'              => 'month',
    'PARTDAY'            => 'day',
    'PARTYEAR'           => 'year',
    'PARTMONTH'          => 'month',
    'ADDRESS'            => 'address',
    'AUTHOR'             => 'authors',
    'EDITOR'             => 'editors',
    'ISBN'               => 'isbn',
    'ISSN'               => 'issn',
    'ISSUE'              => 'issue',
    'NUMBER'             => 'number',
    'PAGES'              => 'pages',
    'EDITION'            => 'edition',
    'NOTES'              => 'notes',
    'VOLUME'             => 'volume',
    'URL'                => 'url',
    'DEGREEGRANTOR:ASIS' => 'school',
    'KEYWORD'            => 'keywords',
    'AUTHOR:CORP'        => 'organization',
    'PUBLISHER'          => 'publisher',
  };

  foreach my $field (@$data) {

    # Already handled in function _get_type_from_bibutils
    next if ($field->{tag} ~~ ['TYPE', 'GENRE','RESOURCE', 'ISSUANCE']);

    if ( $field->{tag} eq 'TITLE' ) {
      my $title = $field->{data};
      my $level = $field->{level};

      if ( $type eq 'ARTICLE' ) {
        $self->journal($title);
      }

      if ( $type eq 'MASTERSTHESIS' or
           $type eq 'PHDTHESIS' or
           $type eq 'TECHREPORT' or
           $type eq 'MANUAL' or
           $type eq 'UNPUBLISHED' or
           $type eq 'MISC') {

        $self->title($title);

      }

      if ( $type eq 'BOOK' or $type eq 'PROCEEDINGS') {
        $self->title($title)     if $level == 0;
        $self->booktitle($title) if $level == 0;
        $self->series($title)    if $level == 1;
      }

      if ( $type eq 'INBOOK') {
        $self->chapter($title)   if $level == 0;
        $self->booktitle($title) if $level == 1;
        $self->title($title) if $level == 1;
        $self->series($title)    if $level == 2;
      }

      if ( $type eq 'INCOLLECTION') {
        $self->title($title) if $level == 0;
        $self->chapter($title)   if $level == 0;
        $self->booktitle($title) if $level == 1;
        $self->series($title)    if $level == 2;
      }

      if ( $type eq 'INPROCEEDINGS') {
        $self->title($title)   if $level == 0;
        $self->booktitle($title) if $level == 1;
        $self->series($title)    if $level == 2;
      }
      next;
    }

    my $myfield=$map->{$field->{tag}};

    if ($myfield){
      $self->$myfield($field->{data});
    } else {
      print STDERR "Could not handle $field->{tag} of value $field->{data}\n";
    }
  }
}

# this code is similar to the function
# bibtexout_type in bibtexout.c

sub _get_type_from_bibutils {

  my ( $self, $data ) = @_;

  my ( $genre, $level );
  my $type = undef;

  # We currently get the type only from "genre" field. Also the "type"
  # field (which seems to depend from which format was read) can be
  # useful and sometimes necessary for example to distinguish BibTex
  # "book" from "booklet". The "type" field from BibTeX which is used
  # for example to specify the type of a Techreport is ignored for now.
  # Also the "resource" information is ignored which does not really give
  # much information on the type.

  foreach my $field (@$data) {

    #print "$field->{level}, $field->{tag}, $field->{data}\n";
    next if ( $field->{tag} ne "GENRE" && $field->{tag} ne "NGENRE" );
    $genre = $field->{data};
    $level = $field->{level};

    if ( ( $genre eq "periodical" )
      or ( $genre eq "academic journal" )
      or ( $genre eq "magazine" )
      or ( $genre eq "newspaper" ) ) {
      $type = 'ARTICLE';
    } elsif ( $genre eq "instruction" ) {
      $type = 'MANUAL';
    } elsif ( $genre eq "unpublished" ) {
      $type = 'UNPUBLISHED';
    } elsif ( $genre eq "conference publication" and $level == 0 ) {
      $type = 'PROCEEDINGS';
    } elsif ( $genre eq "conference publication" and $level == 1 ) {
      $type = 'INPROCEEDINGS';
    } elsif ( $genre eq "collection" and $level == 0 ) {
      $type = 'COLLECTION';
    } elsif ( $genre eq "collection" and $level == 1 ) {
      $type = 'INCOLLECTION';
    } elsif ( $genre eq "BOOK" and $level == 0 ) {
      $type = 'BOOK';
    } elsif ( $genre eq "BOOK" and $level == 1 ) {
      $type = 'INBOOK';
    } elsif ( $genre eq "report" ) {
      $type = 'TECHREPORT';
    } elsif ( $genre eq "thesis" ) {
      if ( not $type ) {
        $type = 'PHDTHESIS';
      }
    } elsif ( $genre eq "Ph.D. thesis" ) {
      $type = 'PHDTHESIS';
    } elsif ( $genre eq "Masters thesis" ) {
      $type = 'MASTERSTHESIS';
    }

    elsif ( $genre eq "" ) {
      $type = '';
    } elsif ( $genre eq "" ) {
      $type = '';
    }
  }

  if ( not $type ) {
    foreach my $field (@$data) {
      next if ( $field->{tag} ne "ISSUANCE" );
      if ( $field->{data} eq "monographic" ) {
        if ( $field->{level} == 0 ) {
          $type = 'BOOK';
        } elsif ( $field->{level} == 1 ) {
          $type = 'INBOOK';
        }
      }
    }
  }

  if ( not $type ) {
    $type = 'MISC';
  }

  return $type;

}

1;

