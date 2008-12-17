package PaperPile::Library::Author;
use Moose;
use Moose::Util::TypeConstraints;

has 'first_names_raw' => ( is => 'rw', isa => 'Str' );

has 'last_name' => (
  is      => 'rw',
  isa     => 'Str',
  trigger => sub { my $self = shift; $self->create_id }
);

has 'suffix' => (
  is      => 'rw',
  isa     => 'Str',
  default => '',
  trigger => sub { my $self = shift; $self->create_id }
);

has 'initials' => (
  is      => 'rw',
  isa     => 'Str',
  trigger => sub { my $self = shift; $self->create_id }
);

has 'id' => ( is => 'rw', isa => 'Str' );

sub BUILD {

  my ( $self, $params ) = @_;

  if ( $params->{last_name} or $params->{initials} ) {
    $self->create_id;
  }

}

sub create_id {
  my $self = shift;

  my @components=();

  push @components, $self->last_name if ($self->last_name);
  push @components, $self->suffix if ($self->suffix);
  push @components, $self->initials if ($self->initials);

  #my $id = $self->last_name;
  #$id =~ s/\s+/_/g;
  #$id .= "_" . $self->initials;
  #$id = uc($id);

  foreach my $component (@components){
    $component=uc($component);
  }

  my $id=join('_',@components);

  return ( $self->id($id) );
}

sub parse_initials {
  my $self  = shift;
  my $input = $self->first_names_raw;

  # get individual components by splitting at '.' and whitespace
  $input =~ s/\./ /g;
  my @parts = split( /\s+/, $input );

  my $initials = '';

  foreach my $part (@parts) {
    if ( ( $part =~ /([A-Z]+)/ or ( $part =~ /(\w)\w+/ ) ) ) {
      $initials .= $1;
    }
  }
  return $self->initials($initials);
}

sub flat {
  my $self       = shift;
  my @components = ();

  push @components, $self->last_name if ( $self->last_name );
  push @components, $self->suffix    if ( $self->suffix );
  push @components, $self->initials  if ( $self->initials );

  return join( " ", @components );

}

#is there a built-in way of doing that?

sub as_hash {

  my $self = shift;

  return {
    last_name => $self->last_name,
    id        => $self->id,
    initials  => $self->initials,
  };

}

1;
