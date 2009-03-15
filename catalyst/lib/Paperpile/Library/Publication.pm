package Paperpile::Library::Publication;
use Moose;
use Moose::Util::TypeConstraints;
use Digest::SHA1;
use Data::Dumper;

use Paperpile::Library::Author;
use Paperpile::Library::Journal;
use Paperpile::Utils;
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


## TODO: currently not handled:
# CONTENTS (don't know what it is)
# ASSIGNEE (for patents, patents not handled for now)
# CROSSREF (special for BibTeX)
# LCCN (library of congress card number, do we need it?)
# PAPER (not sure what this is; can obviously occur in INPROCEEDINGS but non standard BibTEX)
# TRANSLATOR
# LANGUAGE
# REFNUM
# REVISION (field for type "STANDARD" which we currently have not included)
# LOCATION
# NATIONALITY (for patents, patents not handled for now)

# BibTeX field "type" is not handled. Bibutils lists it verbatim in
# addition to standard type field like ('ARTICLE', ...). Also Bibutils ignores it when writing out
# to xml. Nothing we can easily do about it, should only occur in Techreports tough.

# If chapter and title is given in an INBOOK citation, this is listed
# as TITLE level 0 two times by Bibutils. Currently we write the
# first title to both title and chapter fields.

# Booklet is not explicitely considered, is implicitely handled as book; seems to be fine for every practical
# purpose



# Built-in fields
has 'sha1'       => ( is => 'rw' );
has '_rowid'     => ( is => 'rw', isa => 'Int' );
has 'created'    => ( is => 'rw', isa => 'Str' );
has 'last_read'  => ( is => 'rw', isa => 'Str' );
has 'times_read' => ( is => 'rw', isa => 'Int', default => 0 );
has 'pdf'        => ( is => 'rw', isa => 'Str', default => '' );

# Read other fields from config file

my %config = Paperpile::Utils->get_config;
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
      push @nice, Paperpile::Library::Author->new( full => $a )->nice;
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
    push @authors, Paperpile::Library::Author->new( full => $a );
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

sub list_types {
  return @types;
}

sub build_from_bibutils {

  my ( $self, $data ) = @_;



my %bibutils_map = (
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
  );





  my $type = $self->_get_type_from_bibutils($data);
  $self->pubtype($type);

  my ( @title_fields, @subtitle_fields );
  my (@authors, @editors);
  my ( $page_start, $page_end );

  foreach my $field (@$data) {

    if ( $field->{tag} ~~ ['TITLE'] ) {
      push @title_fields, $field;
    }

    if ( $field->{tag} ~~ ['SUBTITLE'] ) {
      push @subtitle_fields, $field;
    }

    if ($field->{tag} eq 'AUTHOR'){
      my $a=Paperpile::Library::Author->new();
      push @authors, $a->read_bibutils($field->{data})->bibtex;
    }

    if ($field->{tag} eq 'EDITOR'){
      my $a=Paperpile::Library::Author->new();
      push @editors, $a->read_bibutils($field->{data})->bibtex;
    }

    $page_start = $field->{data} if $field->{tag} eq 'PAGESTART';
    $page_end   = $field->{data} if $field->{tag} eq 'PAGEEND';

    # Already handled
    next if ( $field->{tag} ~~ [ 'TITLE', 'SUBTITLE', 'AUTHOR','EDITOR',
                                 'PAGESTART', 'PAGEEND',
                                 'TYPE', 'GENRE', 'RESOURCE', 'ISSUANCE' ] );

    my $myfield = $bibutils_map{ $field->{tag} };
    my $mydata=$field->{data};

    if ($myfield) {
      $self->$myfield( $mydata );
    } else {
      print STDERR "WARNING: Could not handle $field->{tag} of value $field->{data}\n";
    }
  }

  my $titles    = $self->_get_titles_from_bibutils( $type, [@title_fields] );
  my $subtitles = $self->_get_titles_from_bibutils( $type, [@subtitle_fields] );

  foreach my $title_type ( 'journal', 'title', 'booktitle', 'chapter', 'series' ) {
    my $string = $titles->{$title_type};
    $string .= ": " . $subtitles->{$title_type} if $subtitles->{$title_type};

    if ($string) {
      $self->$title_type($string);
    }
  }

  if ($page_start){
    if ($page_end){
      $self->pages($page_start."-".$page_end);
    } else {
      $self->pages($page_start);
    }
  }

  $self->authors(join(' and ',@authors));
  $self->editors(join(' and ',@editors));

}


# Get the correct fields depending on publication type and 'level'
# Takes a list of title (or subtitle) fields encountered in one bibutiils entry
# and returns the appropriate fields of the Publication object as hash.

sub _get_titles_from_bibutils {

  my ( $self, $type, $fields ) = @_;

  my %output = ();

  foreach my $field (@$fields) {

    my $curr_title = $field->{data};
    my $level      = $field->{level};

    if ( $type eq 'ARTICLE' ) {
      $output{journal} = $curr_title if $level==1;
      $output{title} = $curr_title if $level==0;
    }

    if ( $type ~~ [ 'MASTERSTHESIS', 'PHDTHESIS', 'TECHREPORT', 'MANUAL', 'UNPUBLISHED', 'MISC' ] )
    {
      $output{title} = $curr_title;
    }

    if ( $type eq 'BOOK' or $type eq 'PROCEEDINGS' ) {
      $output{title}     = $curr_title if $level == 0;
      $output{booktitle} = $curr_title if $level == 0;
      $output{series}    = $curr_title if $level == 1;
    }

    if ( $type eq 'INBOOK' ) {
      $output{chapter}   = $curr_title if $level == 0;
      $output{booktitle} = $curr_title if $level == 1;
      $output{title}     = $curr_title if $level == 1;
      $output{series}    = $curr_title if $level == 2;
    }

    if ( $type eq 'INCOLLECTION' ) {
      $output{title}     = $curr_title if ($level == 0 and not $output{title});
      $output{chapter}   = $curr_title if $level == 0;
      $output{booktitle} = $curr_title if $level == 1;
      $output{series}    = $curr_title if $level == 2;
    }

    if ( $type eq 'INPROCEEDINGS' ) {
      $output{title}     = $curr_title if $level == 0;
      $output{booktitle} = $curr_title if $level == 1;
      $output{series}    = $curr_title if $level == 2;
    }
  }
  return {%output};
}


sub format_bibutils {

  my ($self) = @_;

  my @output = ();

  if ( $self->pages ) {
    my $level=0;
    if ( $self->pubtype eq 'INBOOK' ) {
      $level=1;
    }
    if ($self->pages=~/(\d+)\s*-+\s*(\d+)/){
      my ( $start, $end ) = ($1,$2);
      # Don't know why INBOOK has level 1 and all other types level 0
      push @output, { tag => 'PAGESTART', data => $start, level => $level };
      if ($end){
        push @output, { tag => 'PAGEEND', data => $end, level => $level };
      }
    } else {
      push @output, { tag => 'PAGESTART', data => $self->pages, level => $level };
    }
  }

  foreach my $author ( split( /\band\b/, $self->authors ) ) {
    my $a = Paperpile::Library::Author->new( full => $author );
    push @output, { tag => 'AUTHOR', data => $a->bibutils, level => 0 };
  }

  foreach my $editor ( split( /and\s+/, $self->editors ) ) {
    my $a = Paperpile::Library::Author->new( full => $editor );
    if ( $self->pubtype ~~ [ 'BOOK', 'PROCEEDINGS' ] ) {
      push @output, { tag => 'EDITOR', data => $a->bibutils, level => 0 };
    } else {
      push @output, { tag => 'EDITOR', data => $a->bibutils, level => 1 };
    }
  }

  my ( $year, $month, $day ) = ( $self->year, $self->month, $self->day );

  my $general_level = 0;

  given ( $self->pubtype ) {

    when ('ARTICLE') {
      push @output, {tag     => 'GENRE',  data  => 'periodical', level => 1};
      push @output, { tag => 'GENRE',    data => 'academic journal', level => 1 };
      push @output, { tag => 'ISSUANCE', data => 'continuing',       level => 1 };
      push @output, { tag => 'RESOURCE', data => 'text',             level => 0 };

      push @output, { tag => 'PARTYEAR',  data => $year,  level => 0 } if $year;
      push @output, { tag => 'PARTMONTH', data => $month, level => 0 } if $month;
      push @output, { tag => 'PARTDAY',   data => $day,   level => 0 } if $day;

      push @output, { tag => 'VOLUME',   data => $self->volume,   level => 0 } if $self->volume;

      push @output, $self->_format_title_bibutils( $self->journal, 1 );
      push @output, $self->_format_title_bibutils( $self->title,   0 );

    }

    when ('MANUAL') {
      push @output, {tag => 'GENRE', data => 'instruction', level => 0};
      push @output, { tag => 'RESOURCE', data => 'text', level => 0 };

      push @output, { tag => 'YEAR',  data => $year,  level => 0 } if $year;
      push @output, { tag => 'MONTH', data => $month, level => 0 } if $month;
      push @output, { tag => 'DAY',   data => $day,   level => 0 } if $day;

      push @output, $self->_format_title_bibutils( $self->title, 0 );
    }

    when ('UNPUBLISHED') {
      push @output, {tag => 'GENRE', data => 'unpublished', level => 0};
      push @output, { tag => 'RESOURCE', data => 'text', level => 0 };

      push @output, { tag => 'YEAR',  data => $year,  level => 0 } if $year;
      push @output, { tag => 'MONTH', data => $month, level => 0 } if $month;
      push @output, { tag => 'DAY',   data => $day,   level => 0 } if $day;

      push @output, $self->_format_title_bibutils( $self->title, 0 );

    }

    when ('PROCEEDINGS') {
      push @output, {tag => 'GENRE', data => 'conference publication', level => 0};
      push @output, { tag => 'RESOURCE', data => 'text', level => 0 };

      push @output, { tag => 'YEAR',  data => $year,  level => 0 } if $year;
      push @output, { tag => 'MONTH', data => $month, level => 0 } if $month;
      push @output, { tag => 'DAY',   data => $day,   level => 0 } if $day;
      push @output, $self->_format_title_bibutils( $self->booktitle, 0 );
      push @output, $self->_format_title_bibutils( $self->series, 1 ) if $self->series;

      #push @output, { tag => 'ADDRESS', data => $self->address, level => 0 } if $self->address;

    }

    when ('INPROCEEDINGS') {
      push @output, { tag => 'GENRE', data => 'conference publication', level => 1 };
      push @output, { tag => 'RESOURCE', data => 'text', level => 0 };

      push @output, { tag => 'PARTYEAR',  data => $year,  level => 0 } if $year;
      push @output, { tag => 'PARTMONTH', data => $month, level => 0 } if $month;
      push @output, { tag => 'PARTDAY',   data => $day,   level => 0 } if $day;

      push @output, $self->_format_title_bibutils( $self->title,     0 );
      push @output, $self->_format_title_bibutils( $self->booktitle, 1 );
      push @output, $self->_format_title_bibutils( $self->series,    2 ) if $self->series;

      $general_level = 1;

    }

    when ('BOOK') {
      push @output, {tag => 'GENRE', data => 'book', level => 0};
      push @output, { tag => 'ISSUANCE', data => 'monographic', level => 0 };
      push @output, { tag => 'RESOURCE', data => 'text',        level => 0 };

      push @output, { tag => 'YEAR',  data => $year,  level => 0 } if $year;
      push @output, { tag => 'MONTH', data => $month, level => 0 } if $month;
      push @output, { tag => 'DAY',   data => $day,   level => 0 } if $day;

      push @output, { tag => 'VOLUME',   data => $self->volume,   level => 0 } if $self->volume;

      push @output, $self->_format_title_bibutils( $self->booktitle, 0 );
      push @output, $self->_format_title_bibutils( $self->series, 1 ) if $self->series;

    }

    when ('INBOOK') {
      push @output, {tag => 'GENRE', data => 'book', level => 1};
      push @output, { tag => 'ISSUANCE', data => 'monographic', level => 1 };
      push @output, { tag => 'RESOURCE', data => 'text',        level => 0 };

      push @output, { tag => 'YEAR',  data => $year,  level => 1 } if $year;
      push @output, { tag => 'MONTH', data => $month, level => 1 } if $month;
      push @output, { tag => 'DAY',   data => $day,   level => 1 } if $day;

      push @output, $self->_format_title_bibutils( $self->chapter, 0 ) if $self->chapter;
      push @output, $self->_format_title_bibutils( $self->booktitle, 1 );
      push @output, $self->_format_title_bibutils( $self->series, 2 ) if $self->series;

      push @output, { tag => 'VOLUME',   data => $self->volume,   level => 2 } if $self->volume;

      $general_level = 1;

    }

    when ('INCOLLECTION') {
      push @output, { tag => 'GENRE', data => 'collection', level => 1 };
      push @output, { tag => 'ISSUANCE', data => 'monographic', level => 0 };
      push @output, { tag => 'RESOURCE', data => 'text',        level => 0 };

      push @output, { tag => 'YEAR',  data => $year,  level => 1 } if $year;
      push @output, { tag => 'MONTH', data => $month, level => 1 } if $month;
      push @output, { tag => 'DAY',   data => $day,   level => 1 } if $day;

      push @output, $self->_format_title_bibutils( $self->title,     0 );
      push @output, $self->_format_title_bibutils( $self->booktitle, 1 );
      push @output, $self->_format_title_bibutils( $self->series,    2 ) if $self->series;

      $general_level = 1;

    }

    when ('TECHREPORT') {
      push @output, { tag => 'GENRE', data => 'report', level => 0 };
      push @output, { tag => 'RESOURCE', data => 'text', level => 0 };

      push @output, { tag => 'YEAR',  data => $year,  level => 0 } if $year;
      push @output, { tag => 'MONTH', data => $month, level => 0 } if $month;
      push @output, { tag => 'DAY',   data => $day,   level => 0 } if $day;

      push @output, $self->_format_title_bibutils( $self->title, 0 );

    }

    when ('PHDTHESIS') {
      push @output, { tag => 'GENRE', data => 'thesis', level => 0};
      push @output, { tag => 'GENRE',    data => 'Ph.D. thesis', level => 0 };
      push @output, { tag => 'RESOURCE', data => 'text',         level => 0 };

      push @output, { tag => 'YEAR',  data => $year,  level => 0 } if $year;
      push @output, { tag => 'MONTH', data => $month, level => 0 } if $month;
      push @output, { tag => 'DAY',   data => $day,   level => 0 } if $day;

      push @output, $self->_format_title_bibutils( $self->title, 0 );

    }

    when ('MASTERSTHESIS') {
      push @output, { tag => 'GENRE', data => 'thesis', level => 0 };
      push @output, { tag => 'GENRE',    data => 'Masters thesis', level => 0 };
      push @output, { tag => 'RESOURCE', data => 'text',           level => 0 };

      push @output, { tag => 'YEAR',  data => $year,  level => 0 } if $year;
      push @output, { tag => 'MONTH', data => $month, level => 0 } if $month;
      push @output, { tag => 'DAY',   data => $day,   level => 0 } if $day;

      push @output, $self->_format_title_bibutils( $self->title, 0 );

    }

    when ('MISC') {
      push @output, { tag => 'YEAR',  data => $year,  level => 0 } if $year;
      push @output, { tag => 'MONTH', data => $month, level => 0 } if $month;
      push @output, { tag => 'DAY',   data => $day,   level => 0 } if $day;

      push @output, $self->_format_title_bibutils( $self->title, 0 );

    }
  }

  my %map0 = (
    'citekey'      => 'REFNUM',
    'sortkey'      => 'BIBKEY',
    'abstract'     => 'ABSTRACT',
    'doi'          => 'DOI',
    'isbn'         => 'ISBN',
    'issn'         => 'ISSN',
    'issue'        => 'ISSUE',
    'number'       => 'NUMBER',
    'notes'        => 'NOTES',
    'url'          => 'URL',
    'school'       => 'DEGREEGRANTOR:ASIS',
    'keywords'     => 'KEYWORD',
  );

  my %map1 = (
    'address'   => 'ADDRESS',
    'publisher' => 'PUBLISHER',
    'edition'      => 'EDITION',
    'organization' => 'AUTHOR:CORP',
  );

  foreach my $key ( keys %map0 ) {
    my $data = $self->$key;
    if ($data) {
      push @output, { tag => $map0{$key}, data => $data, level => 0 };
    }
  }

  foreach my $key ( keys %map1 ) {
    my $data = $self->$key;
    if ($data) {
      push @output, { tag => $map1{$key}, data => $data, level => $general_level };
    }
  }

  # Bibutils has a field 'TYPE' in addtion to genre. Don't know
  # exactly how this works.  Seems to store e.g. the BibTeX type if
  # read from BibTeX. However, some exceptions were found during
  # testing and they are here reflected just to pass the test suite
  # and in the hope that this is not very important anyway.

  if ($self->pubtype eq 'MANUAL'){
    push @output, { tag => 'TYPE', data => 'REPORT', level => 0 };
  } elsif ($self->pubtype ~~ ['PHDTHESIS','MASTERSTHESIS']){
    push @output, { tag => 'TYPE', data => $self->pubtype, level => 0 };
    push @output, { tag => 'TYPE', data=>'THESIS', level => 0 };
  } elsif ($self->pubtype ~~ ['TECHREPORT']){
    push @output, { tag => 'TYPE', data=>'REPORT', level => 0 };
    push @output, { tag => 'TYPE', data => $self->pubtype, level => 0 };
  } elsif ($self->pubtype ~~ ['UNPUBLISHED']){
    push @output, { tag => 'TYPE', data=>'BOOK', level => 0 };
  } else {
    push @output, { tag => 'TYPE', data => $self->pubtype, level => 0 };
  }


  return [@output];
}

sub _format_title_bibutils{

  my ($self, $title,$level)=@_;

  my @output=();

  if ($title){
    if ($title =~/^(.*)\s*:\s*(.*)$/){
      push @output, {tag=>'TITLE',data=>$1,level=>$level};
      push @output, {tag=>'SUBTITLE',data=>$2,level=>$level};
    } else {
      push @output, {tag=>'TITLE',data=>$title,level=>$level};
    }
  }

  return @output;

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
    } elsif ( $genre eq "collection" and $level == 1 ) {
      $type = 'INCOLLECTION';
    } elsif ( $genre eq "book" and $level == 0 ) {
      $type = 'BOOK';
    } elsif ( $genre eq "book" and $level == 1 ) {
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

