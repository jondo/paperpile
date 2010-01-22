package Paperpile::Library::Author;
use Moose;
use Moose::Util::TypeConstraints;
use Text::Unidecode;
use Data::Dumper;
use vars qw(%common_given_names);

BEGIN {
    my @names_list = qw/Aaron Adam Adams Adelina Adrain Adron Ag Agostinho Agueda Aida Aimé Aisling Ake Akif Akram Alan Alcantara Alex Alexander Alexis Alfred Alice Alicia Allan Allen Allister Almada Alp Alton Alzira Amelia Amélia Amos ana Anders Anderson André Andrea Andrew Angela Angeles Angélica Angelyn Ann Anne Antero Anthony Anton Antonia Antónia Antonieta Antonietta Araceli Aránzazu Arnold Artee Arturo Arul Arvind Arzu Asbjørn Ascenção Asghar Ashley Ashok Aslam Austin Autzen Axel Ayhan Aziz Azizur Baba Baki Bakoto Balakrish Balakrishna Banfield Banu Baqir Barbara Bari Barrie Barry Barton Beier Bekem Belem Belén Belge Benedict Benno Berk Bernhard Berni Bertil Beryl Bethan Bhat Bilge Birgitta Birsin Biscaia Björn Blair Blake Blessmann Bo Boroomand Bosch Boyd Bozorg Bradford Bradley Braham Brandon Braz Brent Breton Brian Bridson Briolanja Britt Brock Brøgger Brooke Bruce Bryan Bryce Bryn Buddie Buket Bulent Bülent Burkhard Buz Byron Cagatay Cagri Cahit Caleb Cámara Carina Carl Carlota Carmalin Carmelo Carmen Carmo Carol Carolina Carson Carter Cary Catherine Cava Cecilia Cecília Celal Celeste Cem Cemil Cengiz Cenk Ceroni Ch Chadwick Chandra Channe Chantal Charles Charlotte Chatti Cherie Chhanalal Chidambara Chih-Ho Chris Christian Christine Christof Christopher Cinar Cindy Claiborne Claire Clare Clark Clarke Claude Claudina Clement Clifton Clint Cody Collette Comes Conceiçao Conceição Cora Corinne Cornelis Corydon Cosio Craig Crawford Cristina Crosby Cully Cynthia Dade Dale Daniel Danielle Darío Dave David Dawn Dean Deb Delores Denise Dennis Derek Derya DeWitt Dharmendira Diane Dick Dirk Dolores Dolors Dominic Don Donald Donny Dorendra Dorota Douglas Drew Duane Duco Dursun Dwight Ebrahim Eden Eduarda Eduardo Edward Ehtesham Ek Ekkehard Elaine Elena Eline Elisabete Elisabetta Elise Elizabeth Ellen Elliott Elsa Emran Emre Engin Enrique Erdem Eric Erman Ernest Eser Estela Esther Eugene Eugenia Eugénia Eun-Hyung Evan Everett Ezel Fatih Fatima Fátima Feda Federico Felicitas Felix Fernanda Fernando Filomena Firoze Fleming Flint Francis Francisco Frank Franklin Fraser Fred Frederick Fuller Füsun Gabriela Gabriella Gail Gale Galini Ganapati Ganesh Garry Gary Gayle Geoffrey George Geraldine Gerard Gerrard Gerry Gert Gertrudes Gh Ghafourian Ghajarieh Giacominelli Gilbert Gilberto Gillian Gillies Gino Glenn Glória Godfrey Gohain Golam Golubic Gordon Goretti Gotta Graça Gracinda Graeme Graham Granger Grant Grazia Greco Greg Gregg Gregory Grey Guadalupe Gunnar Guray Gustav Guy Gwen Gy Haavi Habib Hadi Haissam Haluk Hameed Hamish Hammad Hans Harivardhan Harry Harvey Hasan Hasanefendioğlu Hashim Hayden Heather Helan Helen Helena Hellmut Hemachandra Henry Hernáiz Hervalejo Hessellund Hima Hope Hossein Hosseini Howard Hudnall Hugh Hugo Hunt Hussain Ia Ian Ibomacha Ibotomba Ie Ignacio Ilhan Ilyas Innes Iqbal Iris Isabel Iskender Israr Itxaso Iu Iván Ivone Jack Jackson Jacob Jafer Jagannadha Jaime Jain Jaleel James Jamil Jane Janet Jared Jashim Jason Javed Javier Jay Jayne Jean Jeanne Jeff Jeffery Jeffrey Jegatha Jene Jerome Jerry Jesus Jesús Jill Joanna Joao João Joe Joel John Johné Jonathan Joost Jose José Joseph Júlia Julian Julius Justin Juventina Kahar Kaila Kaisar Kaleem Kamil Kane Karadeniz Karen Kariuki Karolina Katharine Kathleen Kathryn Katie Kay Kayode Keerthi Keith Kemal Ken Kenan Kenneth Kent Kerr Keshava Kevin Kezban Kh Khairul Khamassi Kim Kimberley Kirby Kirk Kirkland Konrad Koohi Koray Krishna Kristian Kulandhai Kurtis Kyle Lacerda Lafarge Lakshmi Lamar Larry Laurel Laurie LaVome Lawrence Lee Lee-Ann Lehr Leigh Leland Lenin Leon Leonor Lepine Leroy Leslie Letizia Lhassan Lily Linda Linsy Lj Lloyd Loch Loghmani Lokhendra Lokhendro Lori Loring Louis Louisa Louise Low Lu Lucia Luciana Luisa Luke Lurdes Lutfi Luz Lynn Maarten Mack Madalena Madan Madhusudan Magnus Maharaj Mahfuzur Mailen Makena Malathi Malcolm Mamtha Manca Manikyala Manoj Manoji Mansur Manuela Manzoor Marc Marcelino Márcia Marcio Marek Margaret Margarida Margarita Mariano Marie Marieke Marjana Mark Marlena Marlyne Marsel Marshall Marston Martin Marty Martyn Marvin Mary Mason Masood Matt Matthew Matthias Maureen Max May Maymone Mbika Meadow Mei-Ling Mel Meral Mercedes Metin Mhairi Michael Michal Michele Michiel Midori Miguel Mihaela Mika Mike Milburn Ming Minsue Mirajkar Mitchell Mkaya Mohammed Mohan Mohanan Mohd Mohtasheemul Molly Momene Mondain Monica Monterrey Monty Mounir Mouton Mp Mubarik Muhindhar Mukodo Murad Murat Murdoch Mustafa Muze My Nabakishore Nabeel Nadine Nageswara Nair Najjaran Nalaka Nalini Nami Nancy Narahari Narender Narendra Nassir Nath Nathan Nazem Nazemalhosseini Nazli Ndoma Neal Neela Neil Nejib Nelson Nengah Ng Ni Nicholas Nick Nickolas Niclas Nicol Nicole Nigel Nik Nikbakht Nilgün Nilüfer Niranjali Norman Nurhan Nurul Obayed Obi Olcay Olivia Omar Osama Otutubikey Owen Pandurangi Paolo Parker Pascal Pat Patchen Patricia Patrick Paul Pávková Perno Peter Ph Phil Philip Phillip Pilar Pillai Pohlandt Poon Poor Prabhakara Prakasa Praveen Prithvi Prthvi Qasim Quamrul Quinten Rafeeq Raghavendra Raj Raja Rajan Rajesh Ramazan Ramesh Ramnath Rand Randal Randall Randolph Randy Ranganath Razavi Reda Reed Reginald Reid Reinhard Renee Renofio Reyes Ribamar Ribeiro Ricardo Rich Richard Richardson Richey Richter Rick Riedaa Rios Rob Robert Robin Robinan Robinson Rod Roger Roland Romão Ron Ronald Ronan Rosa Rosario Rosário Rosca Ross Rowan Roxana Roy Rüdiger Rumay Rush Russell Ruth Ryan Sabir Sabri Sadegh Saeed Sahap Salim Sam Sambasiva Samiul Sampson Samuel Sander Sanders Sanford Sankara Santiago Sarah Sathish Satish Saveria Sawitri Scot Scott Sean Sebastián Sebnem Seier Selim Selma Semih Sena Senthamil Senthil Serefettin Serhat Sesh Sh Shaheer Shahidul Shahin Shahul Shamsul Shane Shankara Shannon Sharifi Sharon Shawn Shazam Shivaji Shri Shyong Silvina Simone Sirajam Siva Skeff Sloan Sohail Sonia Soon Sreedhara Sreekantha Sreenivasa Sri Srinivas Srinivasa Stan Stancil Stanley Stefan Stella Stephen Stephens Steve Steven Stewart Stokes Stuart Subba Subramanyam Sue Surendra Suresh Sureyya Susan Süsleyici Suzanne Sw Tamás Tanvir Tariq Tatiana Tayfur Taylor Tayyar Ted Teguh Templo Teoman Teresa Terrones Terry Tezer Thane Theodore Thiam Thilek Thomas Thresia Tift Timothy Timucin Tina Todd Tom Tony Torabi Toung Townsend Trapero Tray Trent Troy Ts Tunidau Turgut Turner Tyl Tziporah Uday Udeni Ugur Uljana Ulrich Uma Valance Vamshi Varma Vasantha Velando Vengala Venkatesh Venket Vernon Veronica Victor Vijay Vikram Villa Vincent Virginia Virgínia Vishnu Vitória Vivian Volkan Wade Waheed Wai-Kuo Wali Wallace Walsh Walter Waseem Wasif Wayne Webster Weldon Welford Wes Wesley Westley Weylin Whit Wiktor William Wills Wilson Wing Woodrow Wouter Ya Yakoob Yalçin Yan Yassine Yavuz Ye Yekta Yeşim Yu Yudhistra Yvonne Zafer Zahidunnabi Zahraoui Zangger Zarei Zeeshan Zélia Zev Zeynep Zh Zoe/;

    our %common_given_names = ( );
    foreach my $entry (@names_list) {
	$common_given_names{ $entry } = 1;
    }
    @names_list = ( );
}


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

# NOTE: It module is only able to parse names correctly if they
# they are in correct order. That means starting with first name(s)
# or initials and the family name at the last position.
# Commas are not allowed.

sub parse_freestyle {

  my ( $self, $author_string ) = @_;
  
  $self->von('');
  $self->jr('');

  ( my $first, my $last, my $level ) = _parse_freestyle_helper( $author_string );

  # If words are all upper case, casing is changed 
  if ( $last =~ m/([A-Z])([A-Z]+)$/ ) {
      my $backup = $last;
      $last = $1.lc( $2 );
      $last = $backup if ( length( $last ) != length( $backup ) );
  }

  my @tmp = split( / /, $first );
  foreach my $name ( @tmp ) {
      if ( $name =~ m/([A-Z])([A-Z]+)$/ and length( $name ) > 2 ) {
	  my $backup = $name;
	  $name = $1.lc( $2 );
	  $name = $backup if ( length( $name ) != length( $backup ) );
      }
  }
  $first = join ( " ", @tmp );
  
  
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
		     'van den', 'auf den', 'de la', 'al', 'au', 'af',
		     'el', 'do', 'del', 'de las', 'della', 'dello',
		     'des', 'di', 'de', 'da', 'dos', 'du','la', 'le', 'lo',
		     'les', 'Mc', 'lou', 'pietro', 'st.', 'st', 'ter',
		     'vanden', 'van', 'vel', 'ver','vere', 'vom',
		     'von', 'zur' , 'ten', 'te', 'den', 'sir');

    my @prefixes_special = ('del', 'de la', 'de', 'da', 'do');

    chomp $name;
    my ( $first, $last ) = ( '', '' );
    
    # remove leading and tailoring spaces
    $name =~ s/\s+$//;
    $name =~ s/^\s+//;
    # remove titles
    $name =~ s/\sPh\s?D$//i;
 
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

    if ( $name =~ /(.+)\s([A-Z]+-van)\s(.+)/i ) {
	$first = "$1";
	$last = "$2 $3";
	return ( $first, $last, 1.2 );
    }
    
    # NAMES WITH THREE WORDS
    if ( $#tmp == 2 ) {

	# RULE 2.0: The first word is an initial, the following
	# word must not be an initial.
	# Example: A Gruber Oesterreicher
	if ( $tmp[0] =~ m/^[A-Z]\.?$/ and $tmp[1] !~ m/^[A-Z]\.?$/  ) {
	    # The middle one might be part of the last name
	    # or is a given name. There is no easy way deciding this,
	    # so we do a lookup in a hash if it matches a common
	    # given name.

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

	# RULE 2.3:two full given names, and one last name
	# Example: Andreas Reinhard Gruber
	if ( $tmp[0] =~ m/^[A-Z]\S+$/ and $tmp[1] =~ m/^[A-Z]\S+$/ )
	{
	    if ( $tmp[1] eq 'Ben' or $tmp[1] eq 'Castro' ) {
		$first = "$tmp[0]";
		$last = "$tmp[1] $tmp[2]";
	    } else {
		$first = "$tmp[0] $tmp[1]";
		$last = "$tmp[2]";
	    }
	    return ( $first, $last, 2.3 );
	}
	
	# RULE 2.4:if the middle word is all in lower case letters we consider it
	# as a part of the given name 
	# Example: Kyu hwan Sihn
	if ( $tmp[1] =~ m/^[a-z]+$/ )
	{
	    $first = "$tmp[0] $tmp[1]";
	    $last = "$tmp[2]";
	    return ( $first, $last, 2.4 );
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

	# RULE 3.6: Initial/Name/Name
	# Example: M. Bel Haj Salah
	if ( $tmp[0] =~ m/^[A-Z]\.?$/ and $tmp[1] !~ m/^[A-Z]\.?$/ and $tmp[2] !~ m/^[A-Z]\.?$/) {
	    $first = "$tmp[0]";
	    $last = "$tmp[1] $tmp[2] $tmp[3]";
	    return ( $first, $last, 3.6 );
	}

	# RULE 3.7: Three given names
	# Example: Andreas Reinhard Constantin Gruber
	if ( $tmp[0] !~ m/^[A-Z]\.?$/ and $tmp[1] !~ m/^[A-Z]\.?$/ and $tmp[2] !~ m/^[A-Z]\.?$/) {
	    $first = "$tmp[0] $tmp[1] $tmp[2]";
	    $last = "$tmp[3]";
	    return ( $first, $last, 3.7 );
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
	
	# RULE 4.6: Name/Initial/Initial/Name
	# Example: Cristina M R Santos Branco
	if ( $tmp[0] !~ m/^[A-Z]\.?$/ and $tmp[1] =~ m/^[A-Z]\.?$/ and $tmp[2] =~ m/^[A-Z]\.?$/
	    and $tmp[3] !~ m/^[A-Z]\.?$/ ) {
	    $first = "$tmp[0] $tmp[1] $tmp[2] $tmp[3]";
	    $last = "$tmp[4]";
	    return ( $first, $last, 4.6 );
	}

	# RULE 4.7: four given names and one last name
	# Example: Maria Fernanda Silva Leite Gouveia
	if ( length($tmp[0]) > 2 and length($tmp[1]) > 2 and length($tmp[2]) > 2 and
	     length($tmp[3]) > 2 and length($tmp[4]) > 2 ) {
	    $first = "$tmp[0] $tmp[1] $tmp[2] $tmp[3]";
	    $last = "$tmp[4]";
	    return ( $first, $last, 4.7 );
	}
    }

    # If we and up here, we have failed so far to parse the name. Below is a list of names that are
    # likely to end up here. They serve as rules for upcoming code.
    # M Joana Franco N Carvalho
    # M Salomé S F Caetano
    # B B S J B Rana

    if ( $tmp[0] =~ m/^[A-Z]\.?$/ and $tmp[$#tmp-1] =~ m/^[A-Z]\.?$/ ) {
	$last = pop @tmp;
	$first = join ( " ", @tmp );
	return ( $first, $last, 5.0 );
    }

    # Roel L H M G Spaetjens
    if ( $tmp[0] !~ m/^[A-Z]\.?$/ ) {
	my $all_initials_flag = 1;
	for my $i ( 1 .. $#tmp-1 ) {
	    $all_initials_flag = 0 if ( $tmp[$i] !~ m/^[A-Z]\.?$/ );
	}
	if ( $all_initials_flag == 1 ) {
	    $last = pop @tmp;
	    $first = join ( " ", @tmp );
	    return ( $first, $last, 5.1 );
	}
    }

    # Maria Joao Lima R Trindade
    if ( $tmp[$#tmp-1] =~ m/^[A-Z]\.?$/ ) {
	$last = pop @tmp;
	$first = join ( " ", @tmp );
	return ( $first, $last, 5.2 );
    }

    # Anabela M Santos Batista Pombo 
    # Teresa M Campos Angelo Mendes 
    # Ana M Q L Araujo Vieira 
    # M Jose Vale Oliveira Lopes 
    # Maria Alice C S Guimaraes Rodrigues 
    # Maria Otilia M Santos Vicente 
    # M Rosario Pinho Mendes Cunha
    
    if ( $#tmp >= 4 and $tmp[$#tmp] !~ m/^[A-Z]\.?$/ ) {
	my $nr_initials = 0;
	for my $i ( 0 .. $#tmp-1 ) {
	    $nr_initials++ if ( $tmp[$i] =~ m/^[A-Z]\.?$/ );
	}

	if ( $nr_initials > 0 and $nr_initials <= $#tmp-1 ) {
	    $last = pop @tmp;
	    $first = join ( " ", @tmp );
	    return ( $first, $last, 5.3 );
	}
    }

    # let's check for some non-standard letters
    if ( $#tmp == 2 and $tmp[1] =~ m/^(\x{C5}\x{81}|\x{C3}\x{98})/ ) {
	$last = pop @tmp;
	$first = join ( " ", @tmp );
	return ( $first, $last, 6.0 );
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
