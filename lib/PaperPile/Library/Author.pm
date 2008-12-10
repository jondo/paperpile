package PaperPile::Library::Author;
use Moose;
use Moose::Util::TypeConstraints;

has 'first_names_raw' => ( is => 'rw', isa => 'Str' );
has 'last_name'       => ( is => 'rw', isa => 'Str' );
has 'suffix'          => ( is => 'rw', isa => 'Str' );
has 'initials'        => ( is => 'rw', isa => 'Str' );
has 'id'              => ( is => 'rw', isa => 'Str' );

sub create_id {
  my $self = shift;
  my $id   = $self->last_name;
  $id =~ s/\s+/_/g;
  return $self->id( $id . "_" . $self->initials );
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
  my $self  = shift;
  my @components=();

  push @components, $self->last_name if ($self->last_name);
  push @components, $self->initials if ($self->initials);
  push @components, $self->suffix if ($self->suffix);

  return join(" ", @components);

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
