package PaperPile::Library::Publication;
use Moose;
use Moose::Util::TypeConstraints;
use Digest::SHA1;
use PaperPile::Library::Author;
use PaperPile::Library::Journal;
use PaperPile::Schema::Publication;

# Clone the basic attributes of this class from table schema and set the type attributes

foreach my $column ( PaperPile::Schema::Publication->columns ) {
  if ( $column eq 'pub_type' ) {
    has 'pub_type' => ( is => 'rw', isa => 'PublicationType' );
  }
  elsif ( $column eq 'year' ) {
    has 'year' => ( is => 'rw', isa => 'Int' );
  }
  elsif ( $column eq 'id' ) {
    has 'id' => ( is => 'rw' );
  }
  else {
    has $column => ( is => 'rw', isa => 'Str' );
  }
}

has 'authors' => ( is => 'rw', isa => 'ArrayRef[PaperPile::Library::Author]' );
has 'editors' => ( is => 'rw', isa => 'ArrayRef[PaperPile::Library::Author]' );
has 'journal' => ( is => 'rw', isa => 'PaperPile::Library::Journal' );

sub BUILD {
  my ( $self, $params ) = @_;

  if ($params->{authors}){
    my @tmp=();
    foreach my $author (@{$params->{authors}}){
      push @tmp, $author->flat;
    }
    $self->authors_flat(join(',',@tmp));
  }

  if ($params->{editors}){
    my @tmp=();
    foreach my $editor (@{$params->{editors}}){
      push @tmp, $editor->flat;
    }
    $self->editors_flat(join(',',@tmp));
  }




  if ( $params->{authors} and $params->{title} ) {
    $self->calculate_sha1;
  }
}

sub calculate_sha1 {

  ( my $self ) = @_;

  my $ctx = Digest::SHA1->new;

  $ctx->add( $self->authors_flat );
  $ctx->add( $self->title );
  $self->id( substr( $ctx->hexdigest, 0, 15 ) );

}

# currently only for testing purposes

sub import_ris {

  ( my $self, my $ris ) = @_;

  my %map = (
    'TY' => 'pubtype',
    'T1' => 'title',
    'TI' => 'title',
    'CT' => 'title',
    'BT' => 'title',
    'T2' => 'journal',
    'T3' => 'journal',
    'N1' => 'notes',
    'AB' => 'notes',
    'N2' => 'abstract',
    'JO' => 'journal_short',
    'JF' => 'journal_short',
    'JA' => 'journal_short',
    'VL' => 'volume',
    'IS' => 'issue',
    'CP' => 'issue',
    'CY' => 'city',
    'PB' => 'publisher',
    'AD' => 'address',
    'UR' => 'url',
    'L1' => 'pdf',
    'ID' => 'id',
  );

  my @authors = ();
  my @editors = ();

  my $journal = PaperPile::Library::Journal->new();

  my $startPage = '';
  my $endPage   = '';

  while ( $ris =~ /^\s*(\w\w)\s*-\s*(.*?)$/gms ) {
    ( my $tag, my $value ) = ( $1, $2 );

    if ( $tag =~ /(AU|A1|A2|A3|ED)/ ) {
      ( my $lastName, my $firstName, my $suffix ) = split( /,/, $value );
      $suffix = '' if not defined $suffix;

      my $author = PaperPile::Library::Author->new(
        last_name       => $lastName,
        first_names_raw => $firstName,
        suffix          => $suffix
      );

      $author->parse_initials;
      $author->create_id;

      if ( $tag =~ /(A1|AU)/ ) {
        push @authors, $author;
      }
      elsif ( $tag =~ /(A2|ED)/ ) {
        push @editors, $author;
      }
    }
    elsif ( $tag =~ /(PY|Y1)/ ) {

      # only year handled right now, the RIS file we used for testing
      # was created by BibUtils and it gets this field wrong... TODO:
      # do this later properly...

      ( my $year, my $month, my $day ) = split( /\//, $value );

      $self->year($year);

      # TODO: Handling of journal names is crude and not correct...
    }
    elsif ( $tag =~ /(JO|JF|JA)/ ) {
      $journal->{name} = $value;
      $value =~ s/[.,-]/ /g;
      $value =~ s/(^\s+|\s+$)//g;
      $value =~ s/(^\s+|\s+$)//g;
      $value =~ s/\s+/_/g;
      $value =~ s/_\)/\)/g;
      $journal->{id}         = $value;
      $self->{journal_short} = $value;
    }
    elsif ( $tag =~ /(EP)/ ) {
      $startPage = $value;
    }
    elsif ( $tag =~ /(SP)/ ) {
      $endPage = $value;
    }
    else {
      my $field = $map{$tag};
      if ( defined $field ) {
        $self->$field($value);
      }
      else {
        warn("Tag $tag not handled.\n");
      }
    }
    $self->pages("$startPage-$endPage");
    $self->authors( [@authors] );
    $self->editors( [@editors] );
    $self->journal($journal);

  }
}

sub format_fields {

  my $self = shift;

  return {
    title    => $self->title,
    year     => $self->year,
    pub_type => $self->pub_type
  };

}

1;

