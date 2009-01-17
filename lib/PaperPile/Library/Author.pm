package PaperPile::Library::Author;
use Moose;
use Moose::Util::TypeConstraints;

has 'full' => (
  is      => 'rw',
  isa     => 'Str',
  trigger => sub {
    my $self = shift;
    $self->split_full;
    $self->parse_initials
  }
);

has 'last' => (
  is      => 'rw',
  isa     => 'Str',
  default => '',
  #trigger => sub { my $self = shift; $self->create_id }
);

has 'first' => ( is => 'rw',
                 isa => 'Str',
                 default => '',
                 trigger => sub { my $self = shift; $self->parse_initials}
              );

has 'von' => (
  is      => 'rw',
  isa     => 'Str',
  default => '',

  #trigger => sub { my $self = shift; $self->create_id }
);

has 'jr' => (
  is      => 'rw',
  isa     => 'Str',
  default => '',
);

has 'initials' => (
  is  => 'rw',
  isa => 'Str',

  #trigger => sub { my $self = shift; $self->create_id }
);

has 'key' => ( is => 'rw', isa => 'Str' );

#sub BUILD {
#  my ( $self, $params ) = @_;
#}


### Splits BibTeX like author string into components.
### expects names in the form "von Last, Jr ,First"

sub split_full {

  my ($self) = @_;

  my ($first, $von, $last, $jr);

  if ($self->full eq ''){
    return;
  }

  # first split by comma
  my @parts = split( /,/, $self->full );

  # we have a jr part
  if ( @parts == 3 ) {
    $jr=$parts[1];
    $first=$parts[2];
    # We remove the jr part 
    @parts = ( $parts[0], $parts[2] );

  # we have no jr part
  } else {
    $jr='';
    if (defined($parts[1])){
      $first=$parts[1];
    } else {
      $first='';
    }
  }

  # First and jr part can be set immediately;
  # Last and von part must be separated before

  my @words = split( /\s+/, $parts[0] );
  my @vons  = ();
  my @lasts = ();

  my $word;

  # if only one word is given we consider this as the 
  # last name irrespective of case
  if (@words==1){
    $last=$words[0];
    $von='';

  # otherwise we search for the last lowercase "von" word;
  } else {
    my $last_lc=0;

    for my $i (0..$#words){
      if ( $words[$i] =~ /^[a-z]/ ) {
        $last_lc=$i;
      }
    }
    # everything before is "von"
    $von=join(' ', @words[0..$last_lc]);
    # everything after is "last"
    $last=join(' ', @words[$last_lc+1..$#words]);
  }

  # remove leading and trailing whitespace
  foreach my $string (\$von, \$last, \$first, \$jr){
    $$string=~s/^\s+//;
    $$string=~s/\s+$//;
  }

  $self->von($von);
  $self->last($last);
  $self->first($first);
  $self->jr($jr);

}

sub create_key {
  my $self = shift;

  my @components = ();

  push @components, $self->last if ( $self->last );
  push @components, $self->initials  if ( $self->initials );

  foreach my $component (@components) {
    $component = uc($component);
    $component=~s/\s+/_/g;
  }

  my $key = join( '_', @components );

  return ( $self->key($key) );
}

sub parse_initials {
  my $self  = shift;
  my $input = $self->first;

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

# Nicely format name for use in UI; this format can be re-parsed
# by $self->flat

sub nice {
  my $self       = shift;
  my @components = ();

  push @components, $self->von if ( $self->von );
  push @components, $self->last if ( $self->last);
  push @components, $self->jr    if ( $self->jr );
  push @components, $self->initials  if ( $self->initials );

  return join( " ", @components );

}

sub normalized {

  my $self       = shift;
  my @components = ();

  my $output='';

  $output.=$self->von if ($self->von)." ";

  $output.=$self->last.", ";
  $output.=$self->jr.", " if ($self->jr);
  $output.=$self->initials;

  return $output;

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
