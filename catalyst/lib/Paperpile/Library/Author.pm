package Paperpile::Library::Author;
use Moose;
use Moose::Util::TypeConstraints;
use Text::Unidecode;
use Data::Dumper;
use Lingua::EN::NameParse;

sub BUILD {

  #print "author object\n";
}

has _autorefresh => (is =>'rw', isa=>'Int', default =>1);

has 'full' => (
  is      => 'rw',
  trigger => sub {
    my $self = shift;
    $self->split_full;
    $self->create_key;
  }
);

has 'last' => (
  is      => 'rw',
  default => '',
);

has 'first' => ( is => 'rw',
                 default => '',
                 trigger => sub { my $self = shift; $self->initials($self->_parse_initials($self->first));}
              );

has 'von' => (
  is      => 'rw',
  default => '',
);

has 'jr' => (
  is      => 'rw',
  default => '',
);

has 'collective' => (
  is      => 'rw',
  default => '',
);


has 'initials' => (
  is  => 'rw',
);

has 'key' => ( is => 'rw');


### Splits BibTeX like author string into components.
### expects names in the form "von Last, Jr ,First"

sub split_full {

  my $self = shift;

  my $d = $self->_split_full($self->full);

  foreach my $key (keys %$d){
    $self->$key($d->{$key});
  }
}


sub _split_full {

  my ($dummy, $full) = @_;

  my ($first, $von, $last, $jr);

  # Do nothing in this trivial case
  if (not $full){
    return {first => '', von => '', last => '', jr => '', collective => ''};
  }

  # Recognize non-human entities like collaborative names;
  # Currently they are marked by {..}, probably add
  # full support of {...} as in BibTeX rather this one special
  # case
  if ($full=~/^\s*\{(.*)\}\s*$/){
    return {first => '', von => '', last => '', jr => '', collective => $1};
  }

  # first split by comma
  my @parts = split( /,/, $full );

  for my $i (0..$#parts){
    $parts[$i]=~s/^\s+//;
  }

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

  #print STDERR join('|', @parts), "\n";
  #print STDERR join('|', @words), "\n";

  my $word;

  # if only one word is given we consider this as the 
  # last name irrespective of case
  if (@words==1){
    $last=$words[0];
    $von='';

  # otherwise we search for the last lowercase "von" word;
  } else {
    #print STDERR $self->full, "\n";
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

  return {first => $first, von => $von, last => $last, jr => $jr, collective => ''};
}

sub read_bibutils{

  my ($self, $string) = @_;
  my ($first, $von, $last, $jr);


  my @parts=split(/\|/,$string);

  # No second name is given. For example due to wrong Bibtex: Schuster
  # P. (no comma).  When we are sure that this is an error because it
  # is obviously a name we parse it. Otherwise we convert it to a
  # collective author.

  if (scalar @parts > 1 and $parts[0] eq ''){
    #binmode STDERR, ":utf8";
    #print STDERR "$string\n";
    my $merged=join(' ',@parts);
    $merged=~s/^\s+//;
    #print STDERR "$merged\n";

    # match Stadler P. F. and that like
    if ($merged=~/^([A-Z]\w+) (([A-Z]\.?)( [A-Z]\.?)?)$/){
      $last=$1;
      $first=$2;
    } else {
      $self->collective($merged);
      $last='';
      $first='';
    }

  }

  # Bibutils does not handle collective authors very well, they are
  # just forced into first/last name. TODO: think what to do about
  # this

  # author without first names do not exist to my knowledge. We
  # interpret this as collective name,
  elsif (scalar @parts == 1){
    $self->collective($parts[0]);
    $last='';
    $first='';
  } else {

    $last=$parts[0];
    $first=join(" ", @parts[1..$#parts]);

    # von and jr currently not handled explicitely Bibutils does not
    # seem to handle suffix (at least for pubmed); so we leave them
    # emtpy

  }

  $self->last($last);
  $self->first($first);

  return $self;
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

  $key = unidecode($key);

  return ( $self->key($key) );
}



sub _parse_initials {

  my ($dummy, $input) = @_;

  # get individual components by splitting at '.' and whitespace
  $input =~ s/\./ /g;
  my @parts = split( /\s+/, $input );

  my $initials = '';

  foreach my $part (@parts) {
    if ( ( $part =~ /([A-Z]+)/ or ( $part =~ /(\w)\w+/ ) ) ) {
      $initials .= $1;
    }
  }
  return $initials;
}

# Nicely format name for use in UI; this format can be re-parsed
# by $self->flat

sub nice {
  my $self = shift;

  return $self->_nice( {
      first      => $self->first,
      von        => $self->von,
      last       => $self->last,
      jr         => $self->jr,
      collective => $self->collective,
      initials   => $self->initials,

    }
  );

}

sub _nice {
  my ($dummy, $data) = @_;

  if ( $data->{collective} ) {
    return $data->{collective};
  }

  my @components = ();

  push @components, $data->{von}      if ( $data->{von} );
  push @components, $data->{last}     if ( $data->{last} );
  push @components, $data->{jr}       if ( $data->{jr} );
  push @components, $data->{initials} if ( $data->{initials} );

  my $output = join( " ", @components );

  # Don't show groupings for collaborative names
  $output =~ s/\{//g;
  $output =~ s/\}//g;

  return $output;

}



# Returns author in a normalized format with initials. We use this to
# generate unique IDs for authors
sub normalized {

  my $self       = shift;

  if ($self->collective){
    return '{'.$self->collective.'}';
  }

  my @components = ();
  my $output='';

  $output.=$self->von if ($self->von)." ";

  $output.=$self->last.", ";
  $output.=$self->jr.", " if ($self->jr);
  $output.=$self->initials;

  return $output;
}

# Returns author as bibtex which we use as flat storage format.
sub bibtex {

  my $self       = shift;

  if ($self->collective){
    return '{'.$self->collective.'}';
  }

  my @components = ();

  my $output='';

  $output.=$self->von if ($self->von)." ";

  $output.=$self->last.", ";
  $output.=$self->jr.", " if ($self->jr);
  $output.=$self->first;

  return $output;
}

sub bibutils {

  my $self       = shift;
  my @components = ();

  if ($self->collective){
    # Currently we just set the whole cooperative name as last name
    # and leave first names empty Todo: check if this can be handled
    # better, e.g. by setting author:corp
    return $self->collective;
  }

  my $output='';

  $output.=$self->von if ($self->von)." ";
  $output.=$self->last;
  $output.=" ".$self->jr if ($self->jr);
  $output.='|';
  my @firsts=split(/\s+/,$self->first);
  $output.=join('|',@firsts);

  return $output;
}


sub parse_freestyle {

  my ( $self, $author_string ) = @_;

  # Think more about this
  $self->von('');
  $self->jr('');

  # For efficiency reaseons, we first try to parse the most simplest
  # patterns ourselves

  my ( $first, $last ) = ( '', '' );

  # Peter Stadler
  if ( $author_string =~ /^\s*(\u\w+)\s+(\u\w+)\s*$/ ) {
    ( $first, $last ) = ( $1, $2 );
  }

  # Peter F. Stadler
  elsif ( $author_string =~ /^\s*(\u\w+)\s*(\u\w\.)\s+(\u\w+)\s*$/ ) {
    ( $first, $last ) = ( $1 . ' ' . $2, $3 );
  }

  # P. Stadler
  elsif ( $author_string =~ /^\s*(\u\w\.)\s+(\u\w+)\s*$/ ) {
    ( $first, $last ) = ( $1, $2 );
  }

  # P. F. Stadler and J. -L. Picard
  elsif ( $author_string =~ /^\s*(\u\w\.)\s+(-?\u\w\.)\s+(\u\w+)\s*$/ ) {
    ( $first, $last ) = ( $1 . ' ' . $2, $3 );
  }

  # We have found a match with the simple patterns
  if ( $first and $last ) {

    $self->last($last);
    $self->first($first);

  }

  # We use Lingua::EN::NameParse magic
  else {

    my %args = (
      auto_clean     => 1,
      force_case     => 1,
      lc_prefix      => 1,
      initials       => 3,
      allow_reversed => 1
    );

    my $parser = new Lingua::EN::NameParse(%args);

    my $error = $parser->parse($author_string);

    if ( $error == 0 ) {
      my $correct_casing = $parser->case_all_reversed;
      ( my $last, my $first ) = split( /,/, $correct_casing );

      $self->last($last);
      $self->first($first);

    }
    # if we can't parse it we add it verbatim as 'collective' author
    else {
      $self->collective($author_string);
    }
  }

  return $self;
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

sub clear{

  my $self = shift;

  $self->_autorefresh(0);

  $self->first('');
  $self->last('');
  $self->von('');
  $self->jr('');
  $self->collective('');
  $self->initials('');

  $self->_autorefresh(1);


}


no Moose;

__PACKAGE__->meta->make_immutable;


1;
