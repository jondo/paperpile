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
    has $column => ( is => 'rw', isa => 'Str', default =>'' );
  }
}

has 'authors' => ( is => 'rw', isa => 'ArrayRef[PaperPile::Library::Author]' );
has 'editors' => ( is => 'rw', isa => 'ArrayRef[PaperPile::Library::Author]' );
has 'journal' => ( is => 'rw', isa => 'PaperPile::Library::Journal' );

sub BUILD {

  my ( $self, $params ) = @_;

  if ( $params->{authors} ) {
    my @tmp = ();
    foreach my $author ( @{ $params->{authors} } ) {
      push @tmp, $author->flat;
    }
    $self->authors_flat( join( ', ', @tmp ) );
  } else {
    $self->authors_flat('');
  }

  if ( $params->{editors} ) {
    my @tmp = ();
    foreach my $editor ( @{ $params->{editors} } ) {
      push @tmp, $editor->flat;
    }
    $self->editors_flat( join( ', ', @tmp ) );
  }

  if ( $params->{journal} ) {
    $self->journal_short( $params->{journal}->short );
  }

  if ( $params->{authors} and $params->{title} ) {
    $self->calculate_sha1;
  }
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

  if ( $self->journal->short ) {
    $self->journal_short( $self->journal->short );
  }

}

sub calculate_sha1 {

  ( my $self ) = @_;

  my $ctx = Digest::SHA1->new;

  $ctx->add( $self->authors_flat );
  $ctx->add( $self->title );
  $self->id( substr( $ctx->hexdigest, 0, 15 ) );

}

sub as_hash {

  ( my $self ) = @_;

  my %hash=();

  foreach my $key ($self->meta->get_attribute_list){
    my $value=$self->$key;
    # take only simple scalar and not refs of any sort
    next if ref($value);
    $hash{$key}=$value;
  }

  return {%hash};


}

1;

