package Paperpile::Library::Author;
use Moose;
use Moose::Util::TypeConstraints;
use Text::Unidecode;
use Data::Dumper;

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
  
  $self->von('');
  $self->jr('');

  ( my $first, my $last, my $level ) = _parse_freestyle_helper( $author_string );

  # We have found a match with the simple patterns
  if ( $level < 9 ) {
    $self->last( $last );
    $self->first( $first );
  } else {
	# if we can't parse it we add it verbatim as 'collective' author
	$self->collective( $author_string );
  }

  return $self;
}

# The Story: Initially we used the Lingua::EN::NameParse package, but
# it suffers from a severe memory leak caused by
# Parse::RecDescent. Attempts to fix this packages failed and so we
# wrote ower own parser. This parse routine is tested on over 300,000
# first name/last name pairs from MEDLINE sample data
# (ftp://ftp.nlm.nih.gov/nlmdata/sample/medline/) and is able to parse
# 99% correctly.

sub _parse_freestyle_helper {
    my $name = $_[0];

    my @prefixes = ( 'Op de', 'van der', 'von der', 'von zu', 'van de',
		     'van den', 'auf den', 'de la', 'al', 'au',
		     'el', 'do', 'del', 'de las', 'della', 'dello',
		     'des', 'di', 'de', 'da','du','la', 'le', 'lo',
		     'les', 'Mc', 'lou', 'pietro', 'st.', 'st', 'ter',
		     'vanden', 'van', 'vel', 'ver','vere', 'vom',
		     'von', 'zur' );

    my @prefixes_special = ('del', 'de la', 'de', 'da', 'do');

    my %common_given_names = ( 'Aaron' => 1, 'Abdul' => 1, 'Acosta' =>
    1, 'Adam' => 1, 'Adelina' => 1, 'Adrain' => 1, 'Adron' => 1,
    'Agostinho' => 1, 'Agueda' => 1, 'Aida' => 1, 'Aisling' => 1,
    'Ake' => 1, 'Akif' => 1, 'Akram' => 1, 'Alan' => 1, 'Alberto' =>
    1, 'Alcantara' => 1, 'Alex' => 1, 'Alexander' => 1, 'Alexis' => 1,
    'Alfred' => 1, 'Ali' => 1, 'Alice' => 1, 'Alicia' => 1, 'Allan' =>
    1, 'Allen' => 1, 'Allister' => 1, 'Almada' => 1, 'Alton' => 1,
    'Alzira' => 1, 'Amelia' => 1, 'Amin' => 1, 'Amos' => 1, 'Anders'
    => 1, 'Anderson' => 1, 'Andrea' => 1, 'Andrew' => 1, 'Angela' =>
    1, 'Angeles' => 1, 'Angelyn' => 1, 'Ann' => 1, 'Anna' => 1,
    'Annabel' => 1, 'Anne' => 1, 'Antero' => 1, 'Anthony' => 1,
    'Anton' => 1, 'Antonia' => 1, 'Antonieta' => 1, 'Antonietta' => 1,
    'Araceli' => 1, 'Arnold' => 1, 'Artee' => 1, 'Arturo' => 1, 'Arul'
    => 1, 'Arvind' => 1, 'Arzu' => 1, 'Asghar' => 1, 'Ashley' => 1,
    'Ashok' => 1, 'Aslam' => 1, 'Asunción' => 1, 'Austin' => 1,
    'Autzen' => 1, 'Axel' => 1, 'Ayhan' => 1, 'Aziz' => 1, 'Azizur' =>
    1, 'Baba' => 1, 'Baki' => 1, 'Bakoto' => 1, 'Balakrish' => 1,
    'Balakrishna' => 1, 'Banfield' => 1, 'Banu' => 1, 'Baqir' => 1,
    'Bar' => 1, 'Barbara' => 1, 'Barbosa' => 1, 'Bari' => 1, 'Barrie'
    => 1, 'Barry' => 1, 'Barton' => 1, 'Beier' => 1, 'Bekem' => 1,
    'Belem' => 1, 'Belge' => 1, 'Benedict' => 1, 'Benno' => 1, 'Berk'
    => 1, 'Bernhard' => 1, 'Berni' => 1, 'Bertil' => 1, 'Beryl' => 1,
    'Bethan' => 1, 'Bhat' => 1, 'Bilge' => 1, 'Birgitta' => 1,
    'Birsin' => 1, 'Biscaia' => 1, 'Björn' => 1, 'Blair' => 1, 'Blake'
    => 1, 'Blanca' => 1, 'Blessmann' => 1, 'Bo' => 1, 'Boroomand' =>
    1, 'Bosch' => 1, 'Bou' => 1, 'Boyd' => 1, 'Bozorg' => 1,
    'Bradford' => 1, 'Bradley' => 1, 'Braham' => 1, 'Brandon' => 1,
    'Braz' => 1, 'Brent' => 1, 'Breton' => 1, 'Brian' => 1, 'Bridson'
    => 1, 'Briolanja' => 1, 'Britt' => 1, 'Brock' => 1, 'Brooke' => 1,
    'Bruce' => 1, 'Bryan' => 1, 'Bryce' => 1, 'Bryn' => 1, 'Buddie' =>
    1, 'Buket' => 1, 'Bulent' => 1, 'Burkhard' => 1, 'Buz' => 1,
    'Byron' => 1, 'Cagatay' => 1, 'Cagri' => 1, 'Cahit' => 1, 'Caleb'
    => 1, 'Cámara' => 1, 'Carina' => 1, 'Carl' => 1, 'Carlota' => 1,
    'Carmalin' => 1, 'Carmelo' => 1, 'Carmen' => 1, 'Carmo' => 1,
    'Carneiro' => 1, 'Carol' => 1, 'Carolina' => 1, 'Carson' => 1,
    'Carter' => 1, 'Cary' => 1, 'Catherine' => 1, 'Cava' => 1,
    'Cecilia' => 1, 'Celal' => 1, 'Celeste' => 1, 'Cem' => 1, 'Cemil'
    => 1, 'Cengiz' => 1, 'Cenk' => 1, 'Ceroni' => 1, 'Chadwick' => 1,
    'Chandra' => 1, 'Channe' => 1, 'Chantal' => 1, 'Charles' => 1,
    'Charlotte' => 1, 'Chatti' => 1, 'Cherie' => 1, 'Chhanalal' => 1,
    'Chidambara' => 1, 'Chih-Ho' => 1, 'Chris' => 1, 'Christian' => 1,
    'Christine' => 1, 'Christof' => 1, 'Christopher' => 1, 'Cinar' =>
    1, 'Cindy' => 1, 'Claiborne' => 1, 'Claire' => 1, 'Clare' => 1,
    'Clark' => 1, 'Clarke' => 1, 'Claude' => 1, 'Claudina' => 1,
    'Clement' => 1, 'Clifton' => 1, 'Clint' => 1, 'Cody' => 1, 'Coen'
    => 1, 'Collette' => 1, 'Comes' => 1, 'Cora' => 1, 'Corinne' => 1,
    'Cornelis' => 1, 'Corydon' => 1, 'Cosio' => 1, 'Craig' => 1,
    'Crawford' => 1, 'Crespo' => 1, 'Cristina' => 1, 'Crosby' => 1,
    'Cully' => 1, 'Cynthia' => 1, 'Dade' => 1, 'Dale' => 1, 'Daniel'
    => 1, 'Danielle' => 1, 'Darío' => 1, 'Dave' => 1, 'David' => 1,
    'Dawn' => 1, 'Dean' => 1, 'Deb' => 1, 'Delores' => 1, 'Denise' =>
    1, 'Dennis' => 1, 'Derek' => 1, 'Derya' => 1, 'Dharmendira' => 1,
    'Diane' => 1, 'Dick' => 1, 'Dirk' => 1, 'Dolores' => 1, 'Dolors'
    => 1, 'Dominic' => 1, 'Don' => 1, 'Donald' => 1, 'Donny' => 1,
    'Dorendra' => 1, 'Dorota' => 1, 'Douglas' => 1, 'Drew' => 1,
    'Duane' => 1, 'Duco' => 1, 'Dursun' => 1, 'Dwight' => 1, 'Ebrahim'
    => 1, 'Eden' => 1, 'Eduarda' => 1, 'Eduardo' => 1, 'Edward' => 1,
    'Ehtesham' => 1, 'Ekkehard' => 1, 'Elaine' => 1, 'Elena' => 1,
    'Eline' => 1, 'Elira' => 1, 'Elisabete' => 1, 'Elisabetta' => 1,
    'Elise' => 1, 'Elizabeth' => 1, 'Ellen' => 1, 'Elliott' => 1,
    'Elsa' => 1, 'Emran' => 1, 'Emre' => 1, 'Engin' => 1, 'Enrique' =>
    1, 'Erdem' => 1, 'Eric' => 1, 'Erin' => 1, 'Erman' => 1, 'Ernest'
    => 1, 'Eser' => 1, 'Espinosa' => 1, 'Estela' => 1, 'Esther' => 1,
    'Eugene' => 1, 'Eugenia' => 1, 'Eun-Hyung' => 1, 'Evan' => 1,
    'Everett' => 1, 'Ezel' => 1, 'Fatih' => 1, 'Fatima' => 1, 'Feda'
    => 1, 'Federico' => 1, 'Felicitas' => 1, 'Felix' => 1, 'Fernanda'
    => 1, 'Fernando' => 1, 'Filomena' => 1, 'Firoze' => 1, 'Fleming'
    => 1, 'Flint' => 1, 'Francis' => 1, 'Francisco' => 1, 'Frank' =>
    1, 'Franklin' => 1, 'Fraser' => 1, 'Fred' => 1, 'Frederick' => 1,
    'Fuller' => 1, 'Füsun' => 1, 'Gabriela' => 1, 'Gabriella' => 1,
    'Gail' => 1, 'Gale' => 1, 'Galini' => 1, 'Ganapati' => 1, 'Ganesh'
    => 1, 'García' => 1, 'Garry' => 1, 'Gary' => 1, 'Gayle' => 1,
    'Geoffrey' => 1, 'George' => 1, 'Geraldine' => 1, 'Gerard' => 1,
    'Gerrard' => 1, 'Gerry' => 1, 'Gert' => 1, 'Gertrudes' => 1, 'Gh'
    => 1, 'Ghafourian' => 1, 'Ghajarieh' => 1, 'Gholam' => 1,
    'Giacominelli' => 1, 'Gil' => 1, 'Gilbert' => 1, 'Gilberto' => 1,
    'Gillian' => 1, 'Gillies' => 1, 'Gino' => 1, 'Glenn' => 1,
    'Godfrey' => 1, 'Gohain' => 1, 'Golam' => 1, 'Golubic' => 1,
    'Gonzalez' => 1, 'Gordon' => 1, 'Goretti' => 1, 'Gotta' => 1,
    'Gracinda' => 1, 'Graeme' => 1, 'Graham' => 1, 'Granger' => 1,
    'Grant' => 1, 'Grazia' => 1, 'Greco' => 1, 'Greg' => 1, 'Gregg' =>
    1, 'Gregory' => 1, 'Grey' => 1, 'Guadalupe' => 1, 'Gunnar' => 1,
    'Guray' => 1, 'Gustav' => 1, 'Guy' => 1, 'Gwen' => 1, 'Gy' => 1,
    'Haavi' => 1, 'Habib' => 1, 'Hadi' => 1, 'Haissam' => 1, 'Haluk'
    => 1, 'Hameed' => 1, 'Hamid' => 1, 'Hamish' => 1, 'Hammad' => 1,
    'Hans' => 1, 'Harivardhan' => 1, 'Harry' => 1, 'Harvey' => 1,
    'Hasan' => 1, 'Hashim' => 1, 'Hayden' => 1, 'Heather' => 1,
    'Helan' => 1, 'Helen' => 1, 'Helena' => 1, 'Hellmut' => 1,
    'Hemachandra' => 1, 'Henry' => 1, 'Hernáiz' => 1, 'Herrera' => 1,
    'Hima' => 1, 'Hope' => 1, 'Hossein' => 1, 'Hosseini' => 1,
    'Howard' => 1, 'Hudnall' => 1, 'Hugh' => 1, 'Hugo' => 1, 'Hunt' =>
    1, 'Hussain' => 1, 'Ia' => 1, 'Ian' => 1, 'Ibomacha' => 1,
    'Ibotomba' => 1, 'Ie' => 1, 'Ignacio' => 1, 'Ilhan' => 1, 'Ilyas'
    => 1, 'Innes' => 1, 'Iqbal' => 1, 'Iris' => 1, 'Isabel' => 1,
    'Iskender' => 1, 'Israr' => 1, 'Itxaso' => 1, 'Iu' => 1, 'Ivan' =>
    1, 'Ivone' => 1, 'Jack' => 1, 'Jackson' => 1, 'Jacob' => 1,
    'Jafer' => 1, 'Jagannadha' => 1, 'Jaime' => 1, 'Jain' => 1,
    'Jaleel' => 1, 'James' => 1, 'Jamil' => 1, 'Jane' => 1, 'Janet' =>
    1, 'Jared' => 1, 'Jashim' => 1, 'Jason' => 1, 'Javed' => 1,
    'Javier' => 1, 'Jay' => 1, 'Jayne' => 1, 'Jean' => 1, 'Jeanne' =>
    1, 'Jeff' => 1, 'Jeffery' => 1, 'Jeffrey' => 1, 'Jegatha' => 1,
    'Jene' => 1, 'Jerome' => 1, 'Jerry' => 1, 'Jesus' => 1, 'Jill' =>
    1, 'Jo' => 1, 'Joanna' => 1, 'Joao' => 1, 'Joe' => 1, 'Joel' => 1,
    'John' => 1, 'Jonathan' => 1, 'Joost' => 1, 'Jose' => 1, 'Joseph'
    => 1, 'Joyce' => 1, 'Julia' => 1, 'Julian' => 1, 'Julius' => 1,
    'Justin' => 1, 'Juventina' => 1, 'Kahar' => 1, 'Kaila' => 1,
    'Kaisar' => 1, 'Kaleem' => 1, 'Kamil' => 1, 'Kane' => 1,
    'Karadeniz' => 1, 'Karen' => 1, 'Kariuki' => 1, 'Karolina' => 1,
    'Katharine' => 1, 'Katherine' => 1, 'Kathleen' => 1, 'Kathryn' =>
    1, 'Katie' => 1, 'Kay' => 1, 'Kayode' => 1, 'Keerthi' => 1,
    'Keith' => 1, 'Kelly' => 1, 'Kemal' => 1, 'Ken' => 1, 'Kenan' =>
    1, 'Kenneth' => 1, 'Kent' => 1, 'Kerr' => 1, 'Keshava' => 1,
    'Kevin' => 1, 'Kezban' => 1, 'Kh' => 1, 'Khairul' => 1, 'Khamassi'
    => 1, 'Kim' => 1, 'Kimberley' => 1, 'Kirby' => 1, 'Kirk' => 1,
    'Kirkland' => 1, 'Konrad' => 1, 'Koohi' => 1, 'Koray' => 1,
    'Krishna' => 1, 'Kristian' => 1, 'Kulandhai' => 1, 'Kurtis' => 1,
    'Kyle' => 1, 'Lacasa' => 1, 'Lacerda' => 1, 'Lafarge' => 1,
    'Lakshmana' => 1, 'Lakshmi' => 1, 'Lamar' => 1, 'Larry' => 1,
    'Laurel' => 1, 'Laurie' => 1, 'LaVome' => 1, 'Lawrence' => 1,
    'Lee' => 1, 'Lee-Ann' => 1, 'Lehr' => 1, 'Leigh' => 1, 'Leland' =>
    1, 'Lenin' => 1, 'Leon' => 1, 'Leonor' => 1, 'Lepine' => 1,
    'Leroy' => 1, 'Leslie' => 1, 'Letizia' => 1, 'Lhassan' => 1,
    'Lily' => 1, 'Linda' => 1, 'Linsy' => 1, 'Lj' => 1, 'Lloyd' => 1,
    'Loch' => 1, 'Loghmani' => 1, 'Lokhendra' => 1, 'Lokhendro' => 1,
    'Lori' => 1, 'Loring' => 1, 'Louis' => 1, 'Louisa' => 1, 'Louise'
    => 1, 'Lourdes' => 1, 'Low' => 1, 'Lu' => 1, 'Lucia' => 1,
    'Luciana' => 1, 'Luis' => 1, 'Luisa' => 1, 'Luke' => 1, 'Lurdes'
    => 1, 'Lutfi' => 1, 'Luz' => 1, 'Lynn' => 1, 'Maarten' => 1, 'Mac'
    => 1, 'Mack' => 1, 'Madalena' => 1, 'Madan' => 1, 'Madhavan' => 1,
    'Madhusudan' => 1, 'Magnus' => 1, 'Maharaj' => 1, 'Mahfuzur' => 1,
    'Mailen' => 1, 'Makena' => 1, 'Malathi' => 1, 'Malcolm' => 1,
    'Mamtha' => 1, 'Manca' => 1, 'Manikyala' => 1, 'Manoj' => 1,
    'Manoji' => 1, 'Mansur' => 1, 'Manuela' => 1, 'Manzoor' => 1,
    'Marc' => 1, 'Marcelino' => 1, 'Marcio' => 1, 'Marek' => 1,
    'Margaret' => 1, 'Margarida' => 1, 'Margarita' => 1, 'Mariano' =>
    1, 'Marie' => 1, 'Marieke' => 1, 'Marjana' => 1, 'Mark' => 1,
    'Marlena' => 1, 'Marlyne' => 1, 'Marsel' => 1, 'Marshall' => 1,
    'Marston' => 1, 'Martin' => 1, 'Marty' => 1, 'Martyn' => 1,
    'Marvin' => 1, 'Mary' => 1, 'Mason' => 1, 'Masood' => 1, 'Matt' =>
    1, 'Matthew' => 1, 'Matthias' => 1, 'Maureen' => 1, 'Max' => 1,
    'May' => 1, 'Maymone' => 1, 'Mbika' => 1, 'McIntyre' => 1,
    'Meadow' => 1, 'Mei-Ling' => 1, 'Mel' => 1, 'Meral' => 1,
    'Mercedes' => 1, 'Metin' => 1, 'Mhairi' => 1, 'Michael' => 1,
    'Michal' => 1, 'Michele' => 1, 'Michiel' => 1, 'Midori' => 1,
    'Miguel' => 1, 'Mihaela' => 1, 'Mika' => 1, 'Mikael' => 1, 'Mike'
    => 1, 'Milburn' => 1, 'Ming' => 1, 'Minsue' => 1, 'Mirajkar' => 1,
    'Miranda' => 1, 'Mitchell' => 1, 'Mkaya' => 1, 'Mohamed' => 1,
    'Mohammed' => 1, 'Mohan' => 1, 'Mohanan' => 1, 'Mohd' => 1,
    'Mohtasheemul' => 1, 'Molly' => 1, 'Momene' => 1, 'Mondain' => 1,
    'Monica' => 1, 'Monty' => 1, 'Morton' => 1, 'Mounir' => 1,
    'Mouton' => 1, 'Mp' => 1, 'Mubarik' => 1, 'Muhindhar' => 1,
    'Mukodo' => 1, 'Murad' => 1, 'Murat' => 1, 'Murdoch' => 1,
    'Mustafa' => 1, 'Muze' => 1, 'My' => 1, 'Nabakishore' => 1,
    'Nabeel' => 1, 'Nadine' => 1, 'Nageswara' => 1, 'Nair' => 1,
    'Najjaran' => 1, 'Nalaka' => 1, 'Nalini' => 1, 'Nami' => 1,
    'Nancy' => 1, 'Narahari' => 1, 'Narasimha' => 1, 'Narender' => 1,
    'Narendra' => 1, 'Nassir' => 1, 'Nath' => 1, 'Nathan' => 1,
    'Nazem' => 1, 'Nazli' => 1, 'Ndoma' => 1, 'Neal' => 1, 'Neela' =>
    1, 'Neil' => 1, 'Nejib' => 1, 'Nelson' => 1, 'Nengah' => 1, 'Ng'
    => 1, 'Ni' => 1, 'Nicholas' => 1, 'Nick' => 1, 'Nickolas' => 1,
    'Niclas' => 1, 'Nicol' => 1, 'Nicole' => 1, 'Nigel' => 1, 'Nik' =>
    1, 'Niranjali' => 1, 'Nirmala' => 1, 'Norman' => 1, 'Nurhan' => 1,
    'Nurul' => 1, 'Obayed' => 1, 'Obi' => 1, 'Olcay' => 1, 'Olivia' =>
    1, 'Omar' => 1, 'Osama' => 1, 'Otutubikey' => 1, 'Owen' => 1,
    'Oya' => 1, 'Pablo' => 1, 'Pandurangi' => 1, 'Paolo' => 1,
    'Parker' => 1, 'Pascal' => 1, 'Pat' => 1, 'Patchen' => 1,
    'Patricia' => 1, 'Patrick' => 1, 'Paul' => 1, 'Pávková' => 1,
    'Paz' => 1, 'Perno' => 1, 'Peter' => 1, 'Ph' => 1, 'Phil' => 1,
    'Philip' => 1, 'Phillip' => 1, 'Pilar' => 1, 'Pillai' => 1,
    'Pohlandt' => 1, 'Poon' => 1, 'Poor' => 1, 'Prabhakara' => 1,
    'Prakasa' => 1, 'Praveen' => 1, 'Prithvi' => 1, 'Prthvi' => 1,
    'Purushotham' => 1, 'Qasim' => 1, 'Quamrul' => 1, 'Quinten' => 1,
    'Rafeeq' => 1, 'Raghavendra' => 1, 'Raj' => 1, 'Raja' => 1,
    'Rajan' => 1, 'Rajesh' => 1, 'Rama' => 1, 'Ramana' => 1, 'Ramazan'
    => 1, 'Ramesh' => 1, 'Ramnath' => 1, 'Rand' => 1, 'Randal' => 1,
    'Randall' => 1, 'Randolph' => 1, 'Randy' => 1, 'Ranganath' => 1,
    'Razavi' => 1, 'Reda' => 1, 'Reed' => 1, 'Reginald' => 1, 'Reid'
    => 1, 'Reinhard' => 1, 'Renee' => 1, 'Renofio' => 1, 'Rey' => 1,
    'Reyes' => 1, 'Ribamar' => 1, 'Ribeiro' => 1, 'Ricardo' => 1,
    'Rich' => 1, 'Richard' => 1, 'Richardson' => 1, 'Richey' => 1,
    'Richter' => 1, 'Rick' => 1, 'Riedaa' => 1, 'Rios' => 1, 'Rob' =>
    1, 'Robert' => 1, 'Robin' => 1, 'Robinan' => 1, 'Robinson' => 1,
    'Rod' => 1, 'Rodrigo' => 1, 'Roger' => 1, 'Roland' => 1, 'Ron' =>
    1, 'Ronald' => 1, 'Ronan' => 1, 'Rosa' => 1, 'Rosario' => 1,
    'Rosca' => 1, 'Ross' => 1, 'Rossi' => 1, 'Rowan' => 1, 'Roxana' =>
    1, 'Roy' => 1, 'Rüdiger' => 1, 'Rumay' => 1, 'Rush' => 1,
    'Russell' => 1, 'Ruth' => 1, 'Ryan' => 1, 'Sabir' => 1, 'Sabri' =>
    1, 'Sadegh' => 1, 'Saeed' => 1, 'Sahap' => 1, 'Saint' => 1,
    'Salim' => 1, 'Sam' => 1, 'Sambasiva' => 1, 'Samiul' => 1,
    'Sampson' => 1, 'Samuel' => 1, 'Sander' => 1, 'Sanders' => 1,
    'Sanford' => 1, 'Sankara' => 1, 'Santiago' => 1, 'Sarah' => 1,
    'Sathish' => 1, 'Satish' => 1, 'Saveria' => 1, 'Sawitri' => 1,
    'Scot' => 1, 'Scott' => 1, 'Sean' => 1, 'Sebastian' => 1, 'Sebnem'
    => 1, 'Seier' => 1, 'Selim' => 1, 'Selma' => 1, 'Semih' => 1,
    'Sena' => 1, 'Senthamil' => 1, 'Senthil' => 1, 'Serefettin' => 1,
    'Serhat' => 1, 'Sesh' => 1, 'Sh' => 1, 'Shaheer' => 1, 'Shahidul'
    => 1, 'Shahin' => 1, 'Shahul' => 1, 'Shamsul' => 1, 'Shane' => 1,
    'Shankara' => 1, 'Shannon' => 1, 'Sharifi' => 1, 'Sharon' => 1,
    'Shawn' => 1, 'Shazam' => 1, 'Shivaji' => 1, 'Shri' => 1, 'Shyong'
    => 1, 'Silvina' => 1, 'Simon' => 1, 'Simone' => 1, 'Singh' => 1,
    'Sirajam' => 1, 'Siva' => 1, 'Skeff' => 1, 'Sloan' => 1, 'Sohail'
    => 1, 'Sonia' => 1, 'Soon' => 1, 'Sreedhara' => 1, 'Sreekantha' =>
    1, 'Sreenivasa' => 1, 'Srinivas' => 1, 'Srinivasa' => 1, 'Stan' =>
    1, 'Stancil' => 1, 'Stanley' => 1, 'Stefan' => 1, 'Stella' => 1,
    'Stephen' => 1, 'Stephens' => 1, 'Steve' => 1, 'Steven' => 1,
    'Stewart' => 1, 'Stokes' => 1, 'Stuart' => 1, 'Subba' => 1,
    'Subramanyam' => 1, 'Sue' => 1, 'Surendra' => 1, 'Suresh' => 1,
    'Sureyya' => 1, 'Susan' => 1, 'Suzanne' => 1, 'Tanvir' => 1,
    'Tariq' => 1, 'Tatiana' => 1, 'Tayfur' => 1, 'Taylor' => 1,
    'Tayyar' => 1, 'Ted' => 1, 'Teguh' => 1, 'Templo' => 1, 'Teoman'
    => 1, 'Teresa' => 1, 'Terrones' => 1, 'Terry' => 1, 'Tezer' => 1,
    'Thane' => 1, 'Theodore' => 1, 'Thiam' => 1, 'Thilek' => 1,
    'Thomas' => 1, 'Thresia' => 1, 'Tift' => 1, 'Timothy' => 1,
    'Timucin' => 1, 'Tina' => 1, 'Todd' => 1, 'Tom' => 1, 'Tony' => 1,
    'Torabi' => 1, 'Torres' => 1, 'Toung' => 1, 'Townsend' => 1,
    'Trapero' => 1, 'Tray' => 1, 'Trent' => 1, 'Troy' => 1, 'Ts' => 1,
    'Tunidau' => 1, 'Turgut' => 1, 'Turner' => 1, 'Tyl' => 1,
    'Tziporah' => 1, 'Uday' => 1, 'Udeni' => 1, 'Ugur' => 1, 'Uljana'
    => 1, 'Ulrich' => 1, 'Uma' => 1, 'Valance' => 1, 'Vamshi' => 1,
    'Vaquero' => 1, 'Vargas' => 1, 'Varma' => 1, 'Vasantha' => 1,
    'Velando' => 1, 'Vengala' => 1, 'Venkata' => 1, 'Venkatesh' => 1,
    'Venket' => 1, 'Vernon' => 1, 'Veronica' => 1, 'Viana' => 1,
    'Victor' => 1, 'Vijay' => 1, 'Vikram' => 1, 'Villa' => 1,
    'Vincent' => 1, 'Virginia' => 1, 'Vishnu' => 1, 'Vitoria' => 1,
    'Vivian' => 1, 'Volkan' => 1, 'Wade' => 1, 'Waheed' => 1,
    'Wai-Kuo' => 1, 'Wali' => 1, 'Wallace' => 1, 'Walsh' => 1,
    'Walter' => 1, 'Waseem' => 1, 'Wasif' => 1, 'Wayne' => 1,
    'Webster' => 1, 'Weldon' => 1, 'Welford' => 1, 'Wes' => 1,
    'Wesley' => 1, 'Westley' => 1, 'Weylin' => 1, 'Whit' => 1, 'Wiel'
    => 1, 'Wiktor' => 1, 'William' => 1, 'Wills' => 1, 'Wilson' => 1,
    'Woodrow' => 1, 'Wouter' => 1, 'Wright' => 1, 'Ya' => 1, 'Yakoob'
    => 1, 'Yan' => 1, 'Yassine' => 1, 'Yavuz' => 1, 'Ye' => 1, 'Yekta'
    => 1, 'Yeşim' => 1, 'Yu' => 1, 'Yudhistra' => 1, 'Yvonne' => 1,
    'Zafer' => 1, 'Zahidunnabi' => 1, 'Zahraoui' => 1, 'Zandieh' => 1,
    'Zangger' => 1, 'Zarei' => 1, 'Zeeshan' => 1, 'Zev' => 1, 'Zeynep'
    => 1, 'Zoe' => 1 );

    chomp $name;
    my ( $first, $last ) = ( '', '' );
    
    # remove leading and tailoring spaces
    $name =~ s/\s+$//;
    $name =~ s/^\s+//;
 
    my @tmp = split ( /\s+/, $name );

    # TWO WORDS
    # RULE 1.0: Only two words; the first one is considered
    # to be the given name, the last one is the family name
    # Example: Andreas Gruber
    if ( $#tmp == 1 ) {
	$first = $tmp[0];
	$last = $tmp[1];
	return ( $first, $last, 1.0 );
    }

    # NAMES WITH A PREFIX
    foreach my $prefix ( @prefixes_special ) {
	if ( $name =~ /(.+)\s(\S{3,})\s($prefix)\s(.+)/i ) {
	    $first = "$1";
	    $last = "$2 $3 $4";
	    return ( $first, $last, 1.1 );
	} 
    }
    
    foreach my $prefix ( @prefixes ) {
	if ( $name =~ /(.+)\s($prefix)\s(.+)/i ) {
	    $first = "$1";
	    $last = "$2 $3";
	    return ( $first, $last, 1.2 );
	} 
    }
    
    # NAMES WITH THREE WORDS
    if ( $#tmp == 2 ) {

	# RULE 2.0: The first word is an initial, the following
	# word must not be an initial.
	# Example: A Gruber Oesterreicher
	if ( $tmp[0] =~ m/^[A-Z]\.?$/ and $tmp[1] !~ m/^[A-Z]\.?$/  ) {
	    # The next one might be part of the last name
	    # or is a given name. There is no easy way deciding this,
	    # so we do a lookup in a hash if it matches a common
	    # given name

	    if ( $common_given_names{ $tmp[1] } ) {
		$first = "$tmp[0] $tmp[1]";
		$last = "$tmp[2]";
	    } else {
		$first = "$tmp[0]";
		$last = "$tmp[1] $tmp[2]";
	    }
	    return ( $first, $last, 2.0 );
	}

	# RULE 2.1: The word in the middle is an initial, while the first one is
	# a true word.  
	# Example: Andreas R. Gruber
	if ( $tmp[0] !~ m/^[A-Z]\.?$/ and $tmp[1] =~ m/^[A-Z]\.?$/ ) {
	    $first = "$tmp[0] $tmp[1]";
	    $last = $tmp[2];
	    return ( $first, $last, 2.1 );
	}

	# RULE 2.2: The first word and the word in the middle are both initials 
	# Example: A. R. Gruber
	if ( $tmp[0] =~ m/^[A-Z]\.?$/ and $tmp[1] =~ m/^[A-Z]\.?$/ ) {
	    $first = "$tmp[0] $tmp[1]";
	    $last = $tmp[2];
	    return ( $first, $last, 2.2 );
	}

	# two full given names, and one last name
	if ( $tmp[0] =~ m/^[A-Z]\S+$/ and $tmp[1] =~ m/^[A-Z]\S+$/ )
	{
	    if ( $tmp[1] eq 'Ben' ) {
		$first = "$tmp[0]";
		$last = "$tmp[1] $tmp[2]";
	    } else {
		$first = "$tmp[0] $tmp[1]";
		$last = "$tmp[2]";
	    }
	    return ( $first, $last, 2.3 );
	}
    }

    # NAMES WITH FOUR WORDS
    if ( $#tmp == 3 ) {

	# RULE 3.0: The first word and the word in the middle are both initials 
	# Example: A. R. Gruber Oesterreicher
	if ( $tmp[0] =~ m/^[A-Z]\.?$/ and $tmp[1] =~ m/^[A-Z]\.?$/ and $tmp[2] !~ m/^[A-Z]\.?$/ ) {
	    $first = "$tmp[0] $tmp[1]";
	    $last = "$tmp[2] $tmp[3]";
	    return ( $first, $last, 3.0 );
	}

	# RULE 3.1: The first THREE words are all initials.
	# Example: A. R. J. Gruber 
	if ( $tmp[0] =~ m/^[A-Z]\.?$/ and $tmp[1] =~ m/^[A-Z]\.?$/ and $tmp[2] =~ m/^[A-Z]\.?$/ ) {
	    $first = "$tmp[0] $tmp[1] $tmp[2]";
	    $last = "$tmp[3]";
	    return ( $first, $last, 3.1 );
	}
	
	# RULE 3.2: One given name and two initials
	# Example: Andreas R. J. Gruber 
	if ( $tmp[0] !~ m/^[A-Z]\.?$/ and $tmp[1] =~ m/^[A-Z]\.?$/ and $tmp[2] =~ m/^[A-Z]\.?$/) {
	    $first = "$tmp[0] $tmp[1] $tmp[2]";
	    $last = "$tmp[3]";
	    return ( $first, $last, 3.2 );
	}

	# RULE 3.3: Two given names and one initial
	# Example: Andreas Reinhard J. Gruber 
	if ( $tmp[0] !~ m/^[A-Z]\.?$/ and $tmp[1] !~ m/^[A-Z]\.?$/ and $tmp[2] =~ m/^[A-Z]\.?$/) {
	    $first = "$tmp[0] $tmp[1] $tmp[2]";
	    $last = "$tmp[3]";
	    return ( $first, $last, 3.3 );
	}	

	# RULE 3.4: One given name and one initials
	# Example: Andreas R. Gruber Oesterreicher
	if ( $tmp[0] !~ m/^[A-Z]\.?$/ and $tmp[1] =~ m/^[A-Z]\.?$/ and $tmp[2] !~ m/^[A-Z]\.?$/) {
	    $first = "$tmp[0] $tmp[1]";
	    $last = "$tmp[2] $tmp[3]";
	    return ( $first, $last, 3.4 );
	}

	# RULE 3.5: Initial/Name/Initial
	# Example: A. Reinhard C. Gruber
	if ( $tmp[0] =~ m/^[A-Z]\.?$/ and $tmp[1] !~ m/^[A-Z]\.?$/ and $tmp[2] =~ m/^[A-Z]\.?$/) {
	    $first = "$tmp[0] $tmp[1] $tmp[2]";
	    $last = "$tmp[3]";
	    return ( $first, $last, 3.5 );
	}	

	# RULE 3.6: Three given names
	# Example: Andreas Reinhard Constantin Gruber
	if ( $tmp[0] !~ m/^[A-Z]\.?$/ and $tmp[1] !~ m/^[A-Z]\.?$/ and $tmp[2] !~ m/^[A-Z]\.?$/) {
	    $first = "$tmp[0] $tmp[1] $tmp[2]";
	    $last = "$tmp[3]";
	    return ( $first, $last, 3.6 );
	}	
    }

    # NAMES WITH FIVE WORDS
    if ( $#tmp == 4 ) {

	# RULE 4.0: The first word and the word in the middle are both initials 
	# Example: A. R. Gruber Oesterreicher Mueller
	if ( $tmp[0] =~ m/^[A-Z]\.?$/ and $tmp[1] =~ m/^[A-Z]\.?$/ and $tmp[2] !~ m/^[A-Z]\.?$/ and
	    $tmp[3] !~ m/^[A-Z]\.?$/ ) {
	    $first = "$tmp[0] $tmp[1]";
	    $last = "$tmp[2] $tmp[3] $tmp[4]";
	    return ( $first, $last, 4.0 );
	}

	# RULE 4.1: The first THREE words are all initials.
	# Example: A. R. J. Gruber Oesterreicher
	if ( $tmp[0] =~ m/^[A-Z]\.?$/ and $tmp[1] =~ m/^[A-Z]\.?$/ and $tmp[2] =~ m/^[A-Z]\.?$/ and
	    $tmp[3] !~ m/^[A-Z]\.?$/ ) {
	    $first = "$tmp[0] $tmp[1] $tmp[2]";
	    $last = "$tmp[3] $tmp[4]";
	    return ( $first, $last, 4.1 );
	}
	
	# RULE 4.2: The first FOUR words are all initials.
	# Example: A. R. J. C. Gruber
	if ( $tmp[0] =~ m/^[A-Z]\.?$/ and $tmp[1] =~ m/^[A-Z]\.?$/ and $tmp[2] =~ m/^[A-Z]\.?$/
	    and $tmp[3] =~ m/^[A-Z]\.?$/ ) {
	    $first = "$tmp[0] $tmp[1] $tmp[2] $tmp[3]";
	    $last = "$tmp[4]";
	    return ( $first, $last, 4.2 );
	}

	# RULE 4.3: Initial/Name/Initial 
	# Example: J Fernando G Salmon Velez
	if ( $tmp[0] =~ m/^[A-Z]\.?$/ and $tmp[1] !~ m/^[A-Z]\.?$/ and $tmp[2] =~ m/^[A-Z]\.?$/
	    and $tmp[3] !~ m/^[A-Z]\.?$/ ) {
	    $first = "$tmp[0] $tmp[1] $tmp[2]";
	    $last = "$tmp[3] $tmp[4]";
	    return ( $first, $last, 4.3 );
	}
	
        # RULE 4.4: Initial/Initial/Name/Initial 
	# Example: D A Daniel A Hammer
	if ( $tmp[0] =~ m/^[A-Z]\.?$/ and $tmp[1] =~ m/^[A-Z]\.?$/ and $tmp[2] !~ m/^[A-Z]\.?$/
	    and $tmp[3] =~ m/^[A-Z]\.?$/ ) {
	    $first = "$tmp[0] $tmp[1] $tmp[2] $tmp[3]";
	    $last = "$tmp[4]";
	    return ( $first, $last, 4.4 );
	}

	# RULE 4.5: Name/Initial/Initial/Initial 
	# Example: Maurice L G C Luijten
	if ( $tmp[0] !~ m/^[A-Z]\.?$/ and $tmp[1] =~ m/^[A-Z]\.?$/ and $tmp[2] =~ m/^[A-Z]\.?$/
	    and $tmp[3] =~ m/^[A-Z]\.?$/ ) {
	    $first = "$tmp[0] $tmp[1] $tmp[2] $tmp[3]";
	    $last = "$tmp[4]";
	    return ( $first, $last, 4.5 );
	}
	
    }

    return ( $first, $last, 9.0 );
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
