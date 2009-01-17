package PaperPile::Library::Publication;
use Moose;
use Digest::SHA1;
use Data::Dumper;

use PaperPile::Library::Author;
use PaperPile::Library::Journal;
use PaperPile::Schema::Publication;
use PaperPile::Utils;

use 5.010;

# Built-in fields
has 'sha1'    => ( is => 'rw' );
has 'rowid'   => ( is => 'rw', isa => 'Int' );
has 'created' => ( is => 'rw', isa => 'Str' );
has 'last_read' => ( is => 'rw', isa => 'Str' );
has 'times_read' => ( is => 'rw', isa => 'Int' );
has 'pdf' => ( is => 'rw', isa => 'Str' );

# Read other fields from config file
my %config=PaperPile::Utils->get_config;
foreach my $field (keys %{$config{fields}}){

  if ($field=~/(authors|year|title)/){
    has $field  => ( is => 'rw', isa => 'Str', trigger => sub { my $self = shift; $self->refresh_fields } );
  } else {
    has $field  => ( is => 'rw', isa => 'Str' );
  }
}

# Helper fields which have no equivalent field in the database
has '_authors_nice' => ( is => 'rw', isa => 'Str' );
has '_imported' => ( is => 'rw', isa => 'Bool' );



sub BUILD {
  my ( $self, $params ) = @_;
  $self->refresh_fields;
}

sub refresh_fields {
  ( my $self ) = @_;
  $self->calculate_sha1;

  my @nice=();

  if ($self->authors){
    foreach my $a (split(/and/,$self->authors)){
      push @nice,  PaperPile::Library::Author->new(full=>$a)->nice;
    }
    $self->_authors_nice(join(', ',@nice));
  }

}

sub calculate_sha1 {

  ( my $self ) = @_;

  my $ctx = Digest::SHA1->new;

  if ($self->authors and $self->title){
    $ctx->add( PaperPile::Library::Author->new(full=>$self->authors)->nice);
    $ctx->add( $self->title );
    $self->sha1( substr( $ctx->hexdigest, 0, 15 ) );
  }

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

sub get_authors{
  ( my $self) = @_;
  my @authors=();
  foreach my $a ( split(/and/, $self->authors) ) {
    $a=~s/^\s+//;
    $a=~s/\s+$//;
    push @authors, PaperPile::Library::Author->new(full=>$a);
  }
  return [@authors];
}


sub format {

  ( my $self, my $pattern ) = @_;

  my @authors=();
  foreach my $a (@{$self->get_authors}){
    push @authors, $a->last;
  }


  my $first_author = $authors[0];
  my $last_author  = $authors[$#authors];

  my $YYYY = $self->year;
  my $YY   = $YYYY;

  my $title = $self->title;

  my @title_words = split( /\s+/, $title );

  my $journal = $self->journal;

  $journal=~s/\s+/_/g;

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

sub get_form {

  ( my $self, my $type ) = @_;

  my %fields = (
    'pubtype'        => { fieldLabel => 'Type'},
    'key'            => { fieldLabel => 'Key'},
    'title'          => { fieldLabel => 'Title'},
    'title2'         => { fieldLabel => 'Book title'},
    'title3'         => { fieldLabel => 'Series title'},
    'authors_flat'   => { fieldLabel => 'Authors',},
    'editors_flat'   => { fieldLabel => 'Editors',},
    'authors_series' => { fieldLabel => 'Series Editors',},
    'journal_flat'   => { fieldLabel => 'Journal',},
    'volume'         => { fieldLabel => 'Volume',},
    'issue'          => { fieldLabel => 'Issue (number)',},
    'pages'          => { fieldLabel => 'Pages',},
    'publisher'      => { fieldLabel => 'Publisher',},
    'city'           => { fieldLabel => 'City',},
    'address'        => { fieldLabel => 'Address',},
    'date'           => { fieldLabel => 'Date',},
    'year'           => { fieldLabel => 'Year',},
    'month'          => { fieldLabel => 'Month',},
    'day'            => { fieldLabel => 'Day',},
    'issn'           => { fieldLabel => 'ISSN',},
    'pmid'           => { fieldLabel => 'Pubmed ID',},
    'doi'            => { fieldLabel => 'DOI',},
    'url'            => { fieldLabel => 'URL',},
    'abstract'       => { fieldLabel => 'Abstract',},
    'pdf'            => { fieldLabel => 'PDF file',},
    'created'        => { fieldLabel => 'Creation date',},
    'last_read'      => { fieldLabel => 'Last read',},
 );

  my @list;

  given($type){

    when ('JOUR'){
      @list=('pubtype', 'key', 'title', 'authors_flat','journal_flat',
             'volume', 'issue', 'pages', 'month', 'day', 'year',
             'issn', 'pmid', 'url', 'abstract', 'pdf', 'doi');
    }
  }


  my @out;

  foreach my $name (@list){
    $fields{$name}->{name}=$name;
    push @out, $fields{$name};
  }

  return [@out];

}

1;

