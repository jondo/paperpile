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

extends('Paperpile::Library::Publication::Bibutils');

our @types=qw( ARTICLE
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
has 'attachments' => ( is => 'rw', isa => 'Int', default => 0 );

has 'pdf'        => ( is => 'rw', isa => 'Str', default => '' );

# Read other fields from config file

my $config = Paperpile::Utils->get_config;
foreach my $field ( keys %{ $config->{pub_fields} } ) {

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
has '_authors_display'  => ( is => 'rw', isa => 'Str' );
has '_citation_display' => ( is => 'rw', isa => 'Str' );
has '_imported'      => ( is => 'rw', isa => 'Bool' );
has '_details_link'      => ( is => 'rw', isa => 'Str' );


sub BUILD {
  my ( $self, $params ) = @_;
  $self->refresh_fields;
}

sub refresh_fields {
  ( my $self ) = @_;

  my @display = ();

  if ( $self->authors ) {
    foreach my $a ( split( /\band\b/, $self->authors ) ) {
      push @display, Paperpile::Library::Author->new( full => $a )->nice;
    }
    $self->_authors_display( join( ', ', @display) );
  }

  my $cit=$self->format_citation;

  if ($cit){
    $self->_citation_display($cit);
  }

  $self->calculate_sha1;

}

sub calculate_sha1 {

  ( my $self ) = @_;

  my $ctx = Digest::SHA1->new;

  if ( ($self->authors or $self->_authors_display) and $self->title ) {
    if ($self->authors){
      $ctx->add( encode_utf8($self->authors) );
    } else {
      $ctx->add( encode_utf8($self->_authors_display) );
    }
    $ctx->add( encode_utf8($self->title) );
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

  if (defined $substitutions){
    foreach my $key (keys %$substitutions){
      my $value=$substitutions->{$key};
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

sub list_types {
  return @types;
}



1;

