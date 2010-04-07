package Paperpile::PdfExtract;

use Moose;
use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Data::Dumper;
use XML::Simple;
use File::Temp qw(tempfile);

has 'file'     => ( is => 'rw', isa => 'Str' );
has 'pub'      => ( is => 'rw', isa => 'Paperpile::Library::Publication' );
has 'pdftoxml' => ( is => 'rw', isa => 'Str' );

sub parsePDF {

  my $self = shift;

  my $verbose = 0;
  my $debug   = 0;

  my $PDFfile = $self->file;
  my $PDF2XML = $self->pdftoxml;

  # create a temp file
  ( undef, my $tmpfile ) = tempfile( OPEN => 0 );

  # The file may contain spaces or brackets, that have to be escaped.
  # I do not know how this will be handled in Windows.
  $PDFfile =~ s/\s/\\ /g;
  $PDFfile =~ s/\(/\\(/g;
  $PDFfile =~ s/\)/\\)/g;

  # create and read XML file, just the first page
  system("$PDF2XML -noImage -f 1 -l 1 -q $PDFfile $tmpfile 2>/dev/null");
  if (! -e $tmpfile ) {
    NetError->throw( error => 'PDF to XML conversion failed.' ) if ( $debug == 0 );
    return;
  }
  my $xml = new XML::Simple;
  my $data = $xml->XMLin( "$tmpfile", ForceArray => 1 );

  # remove temp file
  unlink("$tmpfile");

  my @page0 = @{ $data->{PAGE}->[0]->{TEXT} } if ( defined $data->{PAGE}->[0]->{TEXT} );

  my ( $title, $authors, $doi, $arxiv_id, $level, $has_cover_page );

  if ( $#page0 > -1 ) {
    ( $title, $authors, $doi, $level, $has_cover_page, $arxiv_id ) =
      _ParseXML( \@page0, $verbose, $debug );
  } else {
    NetError->throw( error => 'PDF contains only images and no parsable text.' )  if ( $debug == 0 );
    return;
  }

  if ( $verbose == 1 ) {
    print STDERR "\n========== EXTRACTION RESULTS FOR PAGE 1 ===========\n" ;
    print STDERR "\tTITLE:==$title==\n\tAUTHORS:==$authors==\n";
    print STDERR "\tCOVERPAGE:$has_cover_page\n\tEXIT-LEVEL:$level\n";
    print STDERR "\tDOI:$doi\n\tARXIV:$arxiv_id\n";
    print STDERR "====================================================\n";
  }

  # let's do some sane checking
  my $wrong = 0;
  $wrong = 1 if ( $title   =~ m/MAtERIALS And MEtHOdS/i );
  $wrong = 1 if ( $title   =~ m/^MEtHOdS$/i );
  $wrong = 1 if ( $title   =~ m/^Introduction$/i );
  $wrong = 1 if ( $title   =~ m/^Results$/i );
  $wrong = 1 if ( _Bad_Author_Words($authors) == 1 );

  if ( $wrong == 1 ) {
    $authors = '';
    $title   = '';
    $level   = -2;
    print STDERR "TITLE or AUTHORS did not pass the filtering.\n"
      if ( $verbose == 1 );
  }

  # Maybe the first page was a sort of cover page, so we parse
  # the second page, too.
  if ( ( $title eq '' and $authors eq '' and $doi eq '' ) or ( $has_cover_page == 1 ) ) {
    print STDERR "\n=================== PAGE 2 ==========================\n" if ( $verbose == 1 );
    my $title_bak = $title;
    my $authors_bak = $authors;

    # create a temp file
    ( undef, my $tmpfile2 ) = tempfile( OPEN => 0 );

    # create and read XML file, but now only the second page
    system("$PDF2XML -noImage -f 2 -l 2 -q $PDFfile $tmpfile2 2>/dev/null");
    $data = $xml->XMLin( "$tmpfile2", ForceArray => 1 );

    # remove temp file
    unlink("$tmpfile2");

    my @page1 = @{ $data->{PAGE}->[0]->{TEXT} } if ( defined $data->{PAGE}->[0]->{TEXT} );
    if ( $#page1 > -1 ) {
      ( $title, $authors, my $doi_page2, $level, $has_cover_page, my $arxiv_id_page2 ) =
        _ParseXML( \@page1, $verbose, $debug );

      if ( $verbose == 1 ) {
	print STDERR "\n========== EXTRACTION RESULTS FOR PAGE 2 ===========\n" ;
	print STDERR "\tTITLE:==$title==\n\tAUTHORS:==$authors==\n";
	print STDERR "\tCOVERPAGE:$has_cover_page\n\tEXIT-LEVEL:$level\n";
	print STDERR "\tDOI:$doi_page2\n\tARXIV:$arxiv_id_page2\n";
	print STDERR "====================================================\n";
      }

      my $wrong = 0;
      $wrong = 1 if ( $title   =~ m/MAtERIALS And MEtHOdS/i );
      $wrong = 1 if ( $title   =~ m/^MEtHOdS$/i );
      $wrong = 1 if ( $title   =~ m/^Introduction$/i );
      $wrong = 1 if ( $title   =~ m/^Results$/i );
      $wrong = 1 if ( _Bad_Author_Words($authors) == 1 );
      $doi      = $doi_page2      if ( $doi      eq '' );
      $arxiv_id = $arxiv_id_page2 if ( $arxiv_id eq '' );
      $title    = $title_bak      if ( $level == 4 or $wrong == 1 and $title_bak ne '');
      $authors  = $authors_bak    if ( $level == 4 or $wrong == 1 and $authors_bak ne '');
    }
  }

  # if we found some authors, we are going to convert them into
  # an authors object
  my @authors_obj = ();
  if ( $authors ne '' ) {

    my $processed = 0;

    # we clean the authors and remove numbers
    #$authors =~ s/1/L/g;           # often OCR error
    $authors =~ s/\x{2019}//g;
    $authors =~ s/\x{2018}//g;
    $authors =~ s/\d//g;
    $authors =~ s/\$//g;
    $authors =~ s/\./. /g;
    $authors =~ s/,$//;
    $authors =~ s/^,//;
    $authors =~ s/\sand,/ and/g;
    $authors =~ s/` //g;
    $authors =~ s/\s?\x{B4}//g;
    $authors =~ s/^(by\s)//gi;

    # if we observe a single word flanked by two commas,
    # we remove the last one
    $authors =~ s/(.*),\s([a-z]+),(.*)/$1, $2 $3/ig;
    $authors =~ s/(.*),\s([a-z]+)$/$1 $2/i;
    $authors =~ s/\s+/ /g;

    # First we check if authors are separated by commas
    my @authors_array = ();
    if ( $authors =~ m/,/ or $authors =~m/Consortium/i ) {
      @authors_array = split( /(,|\sand\s)/, $authors );

      # some sane checking
      pop(@authors_array) if ( $authors_array[$#authors_array] !~ m/[A-Z]/i );

      if ( $authors_array[$#authors_array] =~ m/^\s?and\s(.+)/i ) {
        $authors_array[$#authors_array] = $1;
      }
      if ( $authors_array[$#authors_array] =~ m/(.+)\sand\s(.+)/i ) {
        $authors_array[$#authors_array] = $1;
        $authors_array[ $#authors_array + 1 ] = $2;
      }
      if ( $authors_array[$#authors_array] =~ m/(.+)\s&\s(.+)/i ) {
        $authors_array[$#authors_array] = $1;
        $authors_array[ $#authors_array + 1 ] = $2;
      }
      if ( $authors_array[$#authors_array] =~ m/^\s&\s(.+)/i ) {
        $authors_array[$#authors_array] = $1;
      }
      $processed = 1;
    }

    # there maybe two others sepated by an 'and'
    if ( $processed == 0 and $authors =~ m/^(.+)\sand\s(.+)$/i ) {
      $authors_array[0] = $1;
      $authors_array[1] = $2;
      $processed        = 1;
    }

    # there maybe two others sepated by an '&'
    if ( $processed == 0 and $authors =~ m/^(.+)\s&\s(.+)$/i ) {
      $authors_array[0] = $1;
      $authors_array[1] = $2;
      $processed        = 1;
    }

    # there maybe just one
    my $nr_spaces = ( $authors =~ tr/ // );
    if ( $processed == 0 and $nr_spaces <= 4 ) {

      # We do some cleaning
      $authors_array[0] = $authors;
    }

    # now we parse each author separately
    foreach my $author (@authors_array) {
      # remove unnecessary white spaces, and forgotten 'ands'
      #$author =~ s/and\s//;
      $author =~ s/\sand//;
      $author =~ s/\s+$//;
      $author =~ s/^\s+//;
      next if ( length($author) < 3 );
      $author =~ s/-\s/-/g;

      # sometimes we have to change the order of given name
      # and surename
      if ( $author =~ m/\.$/ ) {
        my @tmp_author = split( /\s/, $author );
        $author = join( ' ', reverse(@tmp_author) );
      }
      my $all_lc = ( $author =~ tr/[a-z]// );
      if ( $author =~ m/\s[A-Z]{1,2}$/ and $all_lc > 0 ) {
        my @tmp_author = split( /\s/, $author );
        $author = join( ' ', reverse(@tmp_author) );
      }

      push @authors_obj, Paperpile::Library::Author->new()->parse_freestyle($author)->bibtex();
    }
  }

  # repair common OCR errors
  my %OCRerrors = ( '\x{FB01}' => 'fi', '\x{FC}'   => 'ü',
		    '\x{2013}' =>  '-', '\x{2032}' => "'",
		    '\x{A8} o' =>  'ö', '\x{A8} a' => 'ä',
		    '\x{A8} u' =>  'ü' );

  while (my ($key, $value) = each(%OCRerrors)){
    $title =~ s/$key/$value/g;
  }

  # sometime still some cleaning is required
  $title =~ s/^(Research\sarticle)//i;
  $title =~ s/^(Short\sarticle)//i;
  $title =~ s/^(Report)//i;
  $title =~ s/^Articles?//i;
  $title =~ s/^(Review\s)//i;
  $title =~ s/^([A-Z]*\sMinireview)//i;
  $title =~ s/^(Letter:?)//i;
  $title =~ s/(\.|\*)$//;
  $title =~ s/\d$// if ( $title =~ m/[A-Z]\s?\d$/i );
  $title =~ s/\x{2019}/'/g;
  $title =~ s/\x{2018}/'/g;
  $title =~ s/\x{2217}//g;
  $title =~ s/'$//;
  $title =~ s/\s+/ /g;
  $title =~ s/^\s+//;
  $title =~ s/\s+$//;
  $title =~ s/\.$//;

  # We can now create the publication object and return it
  my $pub = Paperpile::Library::Publication->new( pubtype => 'MISC' );
  if ( $#authors_obj > -1 and $title ne '' ) {
    $pub->title($title);
    $pub->authors( join( ' and ', @authors_obj ) );
  }
  $pub->doi($doi)          if ( $doi      ne '' );
  $pub->arxivid($arxiv_id) if ( $arxiv_id ne '' );

  return $pub;
}

sub _Bad_Author_Words {
  my $line = $_[0];

  my $flag = 0;

  my @badWords = (
    '\sthis\s',   '\sthat\s',   '\shere\s', '\swhere\s', '\sstudy\s', '\sabout\s',
    '\swhat\s',   '\s?which\s', '\sfrom\s', '\sare\s',   '\ssome\s',  '\sfew\s',
    '\ssystem\s', 'nucleic\s',  'Fig\.\s\d'
  );
  foreach my $word (@badWords) {
    $flag = 1 if ( $line =~ m/$word/i );
  }

  return $flag;
}

sub _AuthorLine_by_Superscripts {
  my $candidate_title   = $_[0];
  my $candidate_authors = $_[1];
  my $nr_title          = $_[2];
  my $nr_authors        = $_[3];
  my $title             = '';
  my $authors           = '';
  my $flag              = 0;

  if ( $nr_authors > $nr_title ) {
    $authors = $candidate_authors;
    $title   = $candidate_title;
    $flag    = 1;
  }

  return ( $title, $authors, $flag );
}
#####################################################
# Authors usually have more commas than the heading

sub _AuthorLine_by_Commas {
  my $candidate_title   = $_[0];
  my $candidate_authors = $_[1];
  my $title             = '';
  my $authors           = '';
  my $flag              = 0;

  my $commas_title   = ( $candidate_title   =~ tr/,// );
  my $commas_authors = ( $candidate_authors =~ tr/,// );
  my $words_title    = ( $candidate_title   =~ tr/ // );
  my $words_authors  = ( $candidate_authors =~ tr/ // );

  if ( $words_title > 0 and $words_authors > 0 ) {
    if ( $commas_authors / $words_authors > $commas_title / $words_title ) {
      $authors = $candidate_authors;
      $title   = $candidate_title;
      $flag    = 1;
    } else {
      # detailed inspection required
      my @tmp1 = split(/, /, $candidate_title);
      my @tmp2 = split(/, /, $candidate_authors);
      # not implemented

    }
  }

  return ( $title, $authors, $flag );
}

sub _AuthorLine_is_Two_Authors {
  my $candidate_title   = $_[0];
  my $candidate_authors = $_[1];
  my $title             = '';
  my $authors           = '';
  my $flag              = 0;

  my @temp_authors = split( / and /i, $candidate_authors );

  # there is exactly 1 AND
  if ( $#temp_authors == 1 ) {
    my $spaces0 = ( $temp_authors[0] =~ tr/ // );
    my $spaces1 = ( $temp_authors[1] =~ tr/ // );
    if ( $spaces0 <= 3 and $spaces1 <= 3 ) {
      $authors = $candidate_authors;
      $title   = $candidate_title;
      $flag    = 1;
    }
  }

  # there is no and; let's try if there is an &
  if ( $#temp_authors == 0 ) {
    @temp_authors = split( / & /, $candidate_authors );
    if ( $#temp_authors == 1 ) {
      my $spaces0 = ( $temp_authors[0] =~ tr/ // );
      my $spaces1 = ( $temp_authors[1] =~ tr/ // );
      if ( $spaces0 <= 3 and $spaces1 <= 3 ) {
        $authors = $candidate_authors;
        $title   = $candidate_title;
        $flag    = 1;
      }
    }

  }

  return ( $title, $authors, $flag );
}

sub _AuthorLine_is_One_Author {
  my $candidate_title   = $_[0];
  my $candidate_authors = $_[1];
  my $title             = '';
  my $authors           = '';
  my $flag              = 0;

  my $spaces = ( $candidate_authors =~ tr/ // );
  if ( $spaces <= 3 ) {
    $authors = $candidate_authors;
    $title   = $candidate_title;
    $flag    = 1;
  }
  return ( $title, $authors, $flag );
}

sub _MarkBadWords {
  my $orig = $_[0];
  ( my $tmp_line = $orig ) =~ s/\s//g;
  my $bad = 0;

  # lines that describe the type of paper
  # original article, mini review, ...
  my @badTypes = (
    'articles?$',                      'paper$',
    'review$',                         '^ResearchPaper',
    '^REVIEWS$',                       '^ResearchNote$',
    '^(research)?report$',             '^(Short)?Communication$',
    '^originalresearch$',              'originalarticle',
    '^Letters$',                       '^.?ExtendedAbstract.?$',
    '^(short)?(scientific)?reports?$', '^ORIGINALINVESTIGATION$',
    'discoverynotes',                  '^SURVEYANDSUMMARY$',
    'APPLICATIONSNOTE$',               'Chapter\d+',
    '^CORRESPONDENCE$',                '^SPECIALTOPIC',
    'Briefreport',                     'DISCOVERYNOTE$',
    'letters?to',                       'BRIEFCOMMUNICATIONS'
  );
  foreach my $type (@badTypes) {
    $bad++ if ( $tmp_line =~ m/$type/i );
  }

  # years and numbers
  my @badNumbers = (
    '20\d\d', '19\d\d', '\d{5,}', '(3|4|5|6|7|8|9)\d\d\d', '1(0|1|2|3|4|5|6|7|8)\d\d',
    '2(1|2|3|4|5|6|7|8|9)\d\d', '\d\d\/\d\d\/\d\d', '\d\d+-\d\d+', '\[\d+\]', '\[\d+-\d+\]', '^\d+$'
  );

  foreach my $number (@badNumbers) {
    $bad++ if ( $tmp_line =~ m/$number/i );
  }

  # words that are not supposed to appear in title or authors
  my @badWords = (
    'doi',           'vol\.\d+',      'keywords',        'openaccess$',
    'ScienceDirect', 'Blackwell',     'journalhomepage', 'e-?mail',
    'journal',       'ISSN',          'http:\/\/',       '\.html',
    'Copyright',     'BioMedCentral', 'BMC',             'corresponding',
    'author',        'Abbreviations', '@',               'Hindawi',
    'Pages\d+',      '\.{5,}',        '^\*',             'NucleicAcidsResearch',
    'Printedin',     'Receivedforpublication',           'Received:',
    'Accepted:'
  );

  foreach my $word (@badWords) {
    $bad++ if ( $tmp_line =~ m/$word/i );
  }

  # if it starts with superscripts
  $bad++ if ( $tmp_line =~ m/^\*/ );
  $bad++ if ( $tmp_line =~ m/^%SC_S%/ );

  return $bad;
}

sub _MarkAdress {
  my $orig = $_[0];
  ( my $tmp_line = $orig ) =~ s/\s//g;
  my $adress = 0;

  my @adressWords = (
    'Universi[t|d]',               'Department',
    'D.partement',                 'Lehrstuhl',
    'Dept\.',                      'Center(for)?(of)?',
    'Centre(for)?(of)?',           'Laboratory',
    'Laboratoirede',               'division(of)?',
    'Institut',                    'Science Division',
    '(current)?(present)?address', 'school',
    'Faculty',                     'P\.O\.Box',
    'POBox',                       'GeneralHospital',
    'Hospitalof',                  'Facultad',
    'U\.S\.A\.',                   'College',
    'Polytechnique',               'MolecularStructureSection',
    'Chairfor',                    'Dipartimento',
    'Ltd\.',                       'ResearchOrganisation',
    'Dept\.?of'
  );

  foreach my $word (@adressWords) {
    $adress++ if ( $tmp_line =~ m/$word/i );
  }

  # special cases
  $adress-- if ( $tmp_line =~ m/addressed/i );
  $adress++ if ( $orig     =~ m/Road(\s|,)/ );
  $adress++ if ( $orig     =~ m/Centro\s/ );

  return $adress;
}

sub _ParseDOI {
  my $doi = $_[0];

  # now we try to parse the doi in a more elaborate regexp
  # there is a bug in pdf2xml and pdf2text: sometimes the loose
  # a slash in an URL; but this regexp should be able to handel it

  # there might be a strange minus sign (unicode &#8211; --> \x{2013}
  $doi =~ s/\s\x{2013}\s/-/g;

  if ( $doi =~ m/\D?(10\.\d{4})/ ) {
    $doi =~ s/(.*)(10\.\d{4})(\/?\s*)(\S+)(.*)/$2\/$4/;
    $doi =~ s/\(*\)*//g;
  } else {
    $doi = '';
  }

  # DOIs do not have commas
  $doi =~ s/,//g;

  # remove points at the end
  $doi =~ s/\.$//;

  return $doi;
}

sub _ParseXML {
  my @lines   = @{ $_[0] };
  my $verbose = $_[1];
  my $debug   = $_[2];

  my @lines_fs                          = ();
  my @lines_bold                        = ();
  my @lines_italic                      = ();
  my @lines_y                           = ();
  my @lines_content                     = ();
  my @lines_nrsuperscripts              = ();
  my @lines_starts_with_superscripts    = ();
  my @lines_nrwords                     = ();
  my @lines_x                           = ();
  my @lines_width                       = ();
  my @lines_adress                      = ();
  my @TMPlines_fs                       = ();
  my @TMPlines_bold                     = ();
  my @TMPlines_italic                   = ();
  my @TMPlines_y                        = ();
  my @TMPlines_content                  = ();
  my @TMPlines_nrsuperscripts           = ();
  my @TMPlines_starts_with_superscripts = ();
  my @TMPlines_nrwords                  = ();
  my @TMPlines_x                        = ();
  my @TMPlines_width                    = ();
  my @TMPlines_adress                   = ();

  my %seen_fontsizes  = ();
  my $doi             = '';
  my $title           = '';
  my $authors         = '';
  my $arxiv_id        = '';
  my $min_x           = 100000;
  my $max_x           = 0;
  my $first_y         = 0;
  my $y_abstract      = 10000;
  my $y_intro         = 10000;
  my $has_cover_page  = 0;
  my $ScienceMag_flag = 0;
  my $JSTOR_flag      = 0;
  my $Nature_flag     = 0;

  ###########################################
  # read in all the elements
  ###########################################

  # @lines holds all TEXT elements (TEXT -> one line)

  my @tmp   = ();
  my $count = 0;
  foreach my $j ( 0 .. $#lines ) {

    # TOKEN elements are the words
    my @words = @{ $lines[$j]->{TOKEN} };
    my $y     = 0;
    my $x     = $lines[$j]->{'x'};
    my $width = $lines[$j]->{'width'};

    my $bold                    = 0;
    my $italic                  = 0;
    my $fs                      = 0;
    my $nr_superscripts         = 0;
    my $starts_with_superscript = 0;
    my $nr_words                = 0;
    my @content                 = ();

    # parse each word to see if it is
    # bold or italic
    # and to determine the fontsize and the position on the y-axis
    my $bold_yes      = 0;
    my $bold_no       = 0;
    my $italic_yes    = 0;
    my $italic_no     = 0;
    my %hash_fontsize = ();
    my %hash_y        = ();
    my $angle_flag    = 0;
    foreach my $i ( 0 .. $#words ) {

      if ( $words[$i]->{angle} != 0 )    # we do not want watermarks and all that stuff
      {
        $angle_flag = 1;
        next if ( !$words[$i]->{content} );
        if ( $words[$i]->{content} =~ m/arXiv:(.+)/ ) {
          $arxiv_id = $1;
        }
        last;
      }

      if ( $words[$i]->{content} ) {
        $hash_fontsize{ $words[$i]->{'font-size'} }++;
	$hash_y{ $words[$i]->{'y'} }++;
        ( $words[$i]->{'bold'}   eq 'yes' ) ? $bold_yes++   : $bold_no++;
        ( $words[$i]->{'italic'} eq 'yes' ) ? $italic_yes++ : $italic_no++;
      }
    }
    next if ( $angle_flag == 1 );

    $nr_words = $#words + 1;
    $bold     = 1 if ( $bold_yes / $nr_words > 0.5 );
    $italic   = 1 if ( $italic_yes / $nr_words > 0.9 );

    # now determine the fontsize for the line
    for my $key ( keys %hash_fontsize ) {
      $fs = $key if ( $hash_fontsize{$key} / $nr_words > 0.5 );
      $seen_fontsizes{$key} += $hash_fontsize{$key};
    }

    # now determine the vertical position of the current line
    for my $key ( keys %hash_y ) {
      $y = $key if ( $hash_y{$key} / $nr_words >= 0.5 and $hash_y{$key} > $y);
    }
    $first_y = $y if ( $first_y == 0 );

    # if we could not find any, let's take the largest one
    if ( $fs == 0 ) {
      for my $key ( keys %hash_fontsize ) {
        $fs = $key if ( $key > $fs );
      }
    }

    # now parse content and see if there are superscripts
    foreach my $i ( 0 .. $#words ) {
      if ( $words[$i]->{content} ) {
        my $word = $words[$i]->{content};

        if ( $words[$i]->{'font-size'} < $fs ) {
          $count++;
          $word = ',';
          $nr_superscripts++;
          $starts_with_superscript = 1 if ( $i == 0 );
        }

        # let's screen for special chars that mark authors
        if ( $word =~ m/\x{A0}/ ) {
          $word =~ s/\x{A0}/,/g;
          $nr_superscripts++;
        }
        if ( $word =~ m/\x{A7}/ ) {
          $word =~ s/\x{A7}/,/g;
          $nr_superscripts++;
        }
        if ( $word =~ m/\x{204E}/ ) {
          $word =~ s/\x{204E}/,/g;
          $nr_superscripts++;
        }
        if ( $word =~ m/\x{2021}/ ) {
          $word =~ s/\x{2021}/,/g;
          $nr_superscripts++;
        }
        if ( $word =~ m/\x{2020}/ ) {
          $word =~ s/\x{2020}/,/g;
          $nr_superscripts++;
        }
        if ( $word =~ m/\x{B9}/ ) {
          $word =~ s/\x{B9}/,/g;
          $nr_superscripts++;
        }
        if ( $word =~ m/\x{B2}/ ) {
          $word =~ s/\x{B2}/,/g;
          $nr_superscripts++;
        }
        if ( $word =~ m/\*/ ) {
          $word =~ s/\*/,/g;
          $nr_superscripts++;
        }
        push @content, $word if ( $word ne '' );
      }
    }

    my $content_line = join( " ", @content );

    # some publishers like 'Cold Spring Harbor Laboratory Press' have a
    # kind of cover page. We set a flag for those cases that is returned.
    # Also some all articles form Oxford journals
    $has_cover_page = 0.5 if ( $content_line =~ m/top\sright\scorner\sof\sthe\sarticle/ );
    $has_cover_page = 0.5 if ( $content_line =~ m/This\sarticle\scites\s\d+\sarticles/ );
    $has_cover_page = 1   if ( $content_line =~ m/Cold\sSpring\sHarbor\sLaboratory\sPress/
			       and $has_cover_page == 0.5);
    $has_cover_page = 1   if ( $content_line =~ m/rsbl\.royalsocietypublishing\.org/ );
    $has_cover_page = 1   if ( $content_line =~ m/PLEASE\sSCROLL\sDOWN\sFOR\sARTICLE/i );
    $has_cover_page = 1
      if ( $content_line =~ m/Reprints\sof\sthis\sarticle\scan\sbe\sordered\sat/ );
    $has_cover_page = 1   if ( $content_line =~ m/\d+\sarticle\(s\)\son\sthe\sISI\sWeb\sof\sScience/ );
    $has_cover_page = 1   if ( $content_line =~ m/Receive\sfree\semail\salerts\swhen\snew\sarticles\scite\sthis\sarticle/ );
    $has_cover_page = 1   if ( $content_line =~ m/Please\sscroll\sdown\sto\ssee\sthe\sfull\stext\sarticle/ );
    $has_cover_page = 1   if ( $content_line =~ m/This\sProvisional\sPDF\scorresponds\sto\sthe\sarticle\sas\sit\sappeared/ );
    $has_cover_page = 1   if ( $content_line =~ m/This\sreprint\sis\sprovided\sfor\spersonal\sand\snoncommercial\suse/ );

    $content_line =~ s/\s+,/,/g;
    $content_line =~ s/,+/,/g;

    $ScienceMag_flag = 1 if ( $content_line =~ m/www\.sciencemag\.org/ );
    $JSTOR_flag      = 1 if ( $content_line =~ m/Your\suse\sof\sthe\sJSTOR\sarchive\sindicates/ );
    $Nature_flag     = 1 if ( $content_line =~ m/www\.nature\.com\/nature/ );
    $Nature_flag     = 1 if ( $content_line =~ m/nature\.com/ );

    my $content_line_tmp = join( "", @content );

    $y_abstract = $y if ( $content_line_tmp =~ m/Abstract$/i );
    $y_abstract = $y if ( $content_line_tmp =~ m/^Abstract/i );
    $y_intro    = $y if ( $content_line_tmp =~ m/^(\d\.?)?Introduction$/i and $y < $y_intro );
    $y_intro    = $y if ( $content_line_tmp =~ m/^(\d\.?)?Results$/i and $y < $y_intro );
    $y_intro    = $y if ( $content_line_tmp =~ m/^(\d\.?)?Background$/i and $y < $y_intro );
    $y_intro    = $y if ( $content_line_tmp =~ m/^Background:/i and $y < $y_intro );
    $y_intro    = $y if ( $content_line_tmp =~ m/^(\d\.?)?Methods$/i and $y < $y_intro and $y > 100);
    $y_intro    = $y if ( $content_line_tmp =~ m/^(\d\.?)?MaterialsandMethods$/i and $y < $y_intro and $y > 100);
    $y_intro    = $y if ( $content_line_tmp =~ m/^(\d\.?)?Summary$/i and $y < $y_intro );
    $y_intro    = $y if ( $content_line_tmp =~ m/^Addresses$/i and $y < $y_intro );
    $y_intro    = $y if ( $content_line_tmp =~ m/^KEYWORDS:/i and $y < $y_intro );
    $y_intro    = $y if ( $content_line_tmp =~ m/^SUMMARY/i and $y < $y_intro );
    $y_intro    = $y if ( $content_line_tmp =~ m/^SYNOPSIS$/i and $y < $y_intro );

    # now we can search for the DOI
    if ( $doi eq '' or $doi =~ m/(\/|-)$/ ) {

      # let's check if we see somehting like doi|DOI
      if ( $content_line =~ m/(10\.\d{4})/i ) {
        $doi = _ParseDOI($content_line);
      } else {

        # in rare case the doi is split in two lines
        if ( $#lines_content > -1 ) {
          my $temp = $lines_content[$#lines_content] . $content_line;
          if ( $temp =~ m/(10\.\d{4})/i ) {
            $doi = _ParseDOI($temp);
          }
        }
      }
      $doi =~ s/;$//;
    }

    #let's see if it has some adress tags
    my $adress = 0;
    $adress = _MarkAdress($content_line);

    # lines that are less than 2 chars are discarded
    # possible source (equations that are not correctly parsed, ...)
    if ( length($content_line) > 2 ) {
      if ( $y >= $first_y ) {
        push @lines_fs,                       $fs;
        push @lines_bold,                     $bold;
        push @lines_italic,                   $italic;
        push @lines_y,                        $y;
        push @lines_content,                  $content_line;
        push @lines_nrsuperscripts,           $nr_superscripts;
        push @lines_nrwords,                  $nr_words;
        push @lines_x,                        $x;
        push @lines_width,                    $width;
        push @lines_adress,                   $adress;
        push @lines_starts_with_superscripts, $starts_with_superscript;
      } else {
        push @TMPlines_fs,                       $fs;
        push @TMPlines_bold,                     $bold;
        push @TMPlines_italic,                   $italic;
        push @TMPlines_y,                        $y;
        push @TMPlines_content,                  $content_line;
        push @TMPlines_nrsuperscripts,           $nr_superscripts;
        push @TMPlines_nrwords,                  $nr_words;
        push @TMPlines_x,                        $x;
        push @TMPlines_width,                    $width;
        push @TMPlines_adress,                   $adress;
        push @TMPlines_starts_with_superscripts, $starts_with_superscript;
      }
    }
  }

  ###################
  # NOW ADD TMP LINES
  for ( my $i = $#TMPlines_fs ; $i > -1 ; $i-- ) {
    unshift( @lines_fs,                       $TMPlines_fs[$i] );
    unshift( @lines_bold,                     $TMPlines_bold[$i] );
    unshift( @lines_italic,                   $TMPlines_italic[$i] );
    unshift( @lines_y,                        $TMPlines_y[$i] );
    unshift( @lines_content,                  $TMPlines_content[$i] );
    unshift( @lines_nrsuperscripts,           $TMPlines_nrsuperscripts[$i] );
    unshift( @lines_starts_with_superscripts, $TMPlines_starts_with_superscripts[$i] );
    unshift( @lines_nrwords,                  $TMPlines_nrwords[$i] );
    unshift( @lines_x,                        $TMPlines_x[$i] );
    unshift( @lines_width,                    $TMPlines_width[$i] );
    unshift( @lines_adress,                   $TMPlines_adress[$i] );
  }

  ################################################
  # NOW DETERMINE MAJOR FONT SIZE
  my $major_fs       = 0;
  my $max_occurences = 0;
  for my $seen_fs ( keys %seen_fontsizes ) {
    if ( $seen_fontsizes{$seen_fs} > $max_occurences ) {
      $major_fs       = $seen_fs;
      $max_occurences = $seen_fontsizes{$seen_fs};
    }
  }

  ################################################
  # NOW DETERMINE PAGE (MAIN TEXT) BOUNDARIES
  ################################################
  my %tmp_hash = ();
  for my $i ( 0 .. $#lines_content ) {
    if ( $lines_fs[$i] >= $major_fs )  # we don't consider lines with a fs smaller than the major fs
    {
      $min_x = $lines_x[$i] if ( $lines_x[$i] < $min_x );
      $max_x = $lines_x[$i] + $lines_width[$i] if ( $lines_x[$i] + $lines_width[$i] > $max_x );
    }
  }

  #####################################################
  # EXIT POINT NUMBER ONE
  # Some journal have such weird page layouts
  # that they cannot be parsed the regular way
  # Here is the first check point if we encounter such
  # a journal
  #####################################################
  if ( $lines_content[0] ) {
    if ( $lines_content[0] =~ m/Landes\sBioscience$/ ) {
      my @title_tmp   = ();
      my @authors_tmp = ();
      for my $pos ( 0 .. $#lines_content ) {
	push @title_tmp, $lines_content[$pos] if ( $lines_fs[$pos] == 24 );
 	push @authors_tmp, $lines_content[$pos]
	  if ( $lines_fs[$pos] == 12 and $lines_content[$pos] =~ m/,$/ );
      }
      $title   = join( " ", @title_tmp );
      $authors = join( " ", @authors_tmp );
      return ( $title, $authors, $doi, 6, 0, '' ) if ( $title ne '' and $authors ne '' );
    }
  }

  if ( $ScienceMag_flag == 1 and $has_cover_page == 0) {
    my @title_tmp   = ();
    my @authors_tmp = ();
    for my $pos ( 0 .. $#lines_content ) {
      next if ( $lines_content[$pos] =~ m/^\d+$/ );
      push @title_tmp, $lines_content[$pos] if ( $lines_fs[$pos] == 20 );
      push @authors_tmp, $lines_content[$pos] if ( $lines_fs[$pos] == 10 );
    }
    $title   = join( " ", @title_tmp );
    $authors = join( " ", @authors_tmp );
    if ( $title eq '' ) {
      my $last22 = -1;
      for my $pos ( 0 .. $#lines_content ) {
	if ( $lines_fs[$pos] == 22 ) {
	  push @title_tmp, $lines_content[$pos];
	  $last22 = $pos;
	}
      }
      if ( $last22 > -1 ) {
	push @authors_tmp, $lines_content[$last22+1] if ( $lines_fs[$last22+1] == 9 );
      }
    }
    $title   = join( " ", @title_tmp );
    $authors = join( " ", @authors_tmp );

    # We cannot trust the DOI, might be from another Pub on the same side
    $doi = '';
    return ( $title, $authors, $doi, 6, 0, '' ) if ( $title ne '' and $authors ne '' );
  }

  if ( $JSTOR_flag == 1 ) {
    my @title_tmp   = ();
    my @authors_tmp = ();
    for my $pos ( 0 .. $#lines_content ) {
      if ( $lines_content[$pos] =~ m/^(Author\(s\):\s)(.*)/ ) {
	push @authors_tmp, $2;
	# maybe there are more author lines following
	for (my $j = $pos+1; $j <= $#lines_content; $j++) {
	  last if ( $lines_content[$j] =~ m/^Source/ );
	  push @authors_tmp, $lines_content[$j] if ( $lines_fs[$j] == 11 );
	}
	# everything before that line is considered to be part of the title
	for (my $j = $pos-1; $j >= 0; $j--) {
	  push @title_tmp, $lines_content[$j] if ( $lines_fs[$j] == 11 );
	}
      }
    }
    $title   = join( " ", @title_tmp );
    $authors = join( " ", @authors_tmp );
    return ( $title, $authors, $doi, 6, 0, '' ) if ( $title ne '' and $authors ne '' );
  }

  if ( $Nature_flag == 1 ) {
    my @title_tmp   = ();
    my @authors_tmp = ();
    for my $pos ( 0 .. $#lines_content ) {
      # Title has usually a font size of 24 or 23 and authors
      # start usually just the line below. This strategy
      # does not ensure that all authors are found.
      if ( $lines_fs[$pos] == 24 or $lines_fs[$pos] == 23 ) {
	push @title_tmp, $lines_content[$pos];
	if ( $lines_fs[$pos+1] == 10 ) {
	  push @authors_tmp, $lines_content[$pos+1];
	}
      }
      # if ( $lines_fs[$pos] == 18 and $#title_tmp == -1 ) {
      # 	for my $pos2 ( $pos .. $#lines_content ) {
      # 	  push @title_tmp, $lines_content[$pos2] if ($lines_fs[$pos2] == 18);
      # 	  if ($lines_fs[$pos2] == 9) {
      # 	    push @authors_tmp, $lines_content[$pos2];
      # 	    last;
      # 	  }
      # 	}
      # 	last;
      # }
    }
    $title   = join( " ", @title_tmp );
    $authors = join( " ", @authors_tmp );
    return ( $title, $authors, $doi, 6, 0, '' ) if ( $title ne '' and $authors ne '' );
  }

  #################################################
  # LET'S JOIN THE LINES

  my @final_content        = ();
  my @final_fs             = ();
  my @final_nrsuperscripts = ();
  my @final_nrwords        = ();
  my @final_bad            = ();
  my @final_adress         = ();
  my @final_bold           = ();

  my $last_line_was_a_join = 0;
  my $last_line_diff       = 0;
  my $last_line_lc         = 0;

  if ( $#lines_content == -1 ) {
    NetError->throw( error => 'The PDF does not seem to contain proper text (maybe a scanned paper).' )
      if ( $debug == 0 );
    return ( '', '', '', 4, 0, '' );
  }

  for my $pos ( 0 .. $#lines_content ) {
    my $threshold = ( $y_abstract < $y_intro ) ? $y_abstract : $y_intro;
    if ( $lines_y[$pos] < $threshold ) {
      my $prev = ( $pos > 0 ) ? $pos - 1 : 0;
      $prev = $pos if ( $#final_content == -1 );
      my $flag_new_line = 1;
      my $adress        = 0;

      # if it has the same fontsize as the last one AND
      # the line spacing is the most frequent one for
      # this fontsize, then we join
      # also italic and bold have to fit

      my $lc = ( $lines_content[$pos] =~ tr/[a-z]// );
      my $uc = ( $lines_content[$pos] =~ tr/[A-Z]// );
      $uc = 1 if ( $uc == 0 );

      my $diff        = abs( $lines_y[$prev] - $lines_y[$pos] );
      my $same_fs     = ( $lines_fs[$pos] eq $lines_fs[$prev] ) ? 1 : 0;
      my $same_bold   = ( $lines_bold[$pos] eq $lines_bold[$prev] ) ? 1 : 0;
      my $same_italic = ( $lines_italic[$pos] eq $lines_italic[$prev] ) ? 1 : 0;
      my $same_diff   = 1;
      if ( $last_line_was_a_join == 1 ) {
        $same_diff = 0 if ( $diff != $last_line_diff );
      }

      my $nr_bad_words = _MarkBadWords( $lines_content[$pos] );
      $flag_new_line = 7 if ( $nr_bad_words > 0 );
      $flag_new_line = 0 if ( $same_fs == 1 and $same_bold == 1 and $same_italic == 1 );
      $flag_new_line = 0 if ( $same_fs == 1 and $same_bold == 1 );
      $flag_new_line = 2 if ( $lines_starts_with_superscripts[$pos] == 1 );
      $flag_new_line = 3 if ( $lines_content[$pos] =~ m/^\*/ );
      $flag_new_line = 4 if ( $lines_adress[$pos] >= 1 );
      $flag_new_line = 5 if ( $lines_y[$pos] < $lines_y[$prev] );
      $flag_new_line = 6 if ( $lc / $uc > 0.2 and $last_line_lc == 0 );
      $flag_new_line = 8 if ( $lines_content[$pos] =~ m/^\d+$/ );
      $flag_new_line = 8 if ( $lines_content[$prev] =~ m/Volume\s\d+/
			      and $nr_bad_words == 0);

      # difference to previous line is really hughe
      $flag_new_line = 9 if ( $diff > 50 );
      $flag_new_line = 9 if ( $diff > ($lines_fs[$pos]+$lines_fs[$prev])*1.5 );

      # if the previous line had signs of beeing an adress, we just append
      # if the current one is also an adress line
      $flag_new_line = 0
        if ($lines_adress[$prev] >= 1
        and $lines_adress[$pos] >= 1
        and $flag_new_line == 1 );

      # no join on email-adresses
      $flag_new_line = 7 if ( $lines_content[$pos] =~ m/@\w+\./ );

      # if a line starts with "and" it obviously is connected to the preceeding line
      my $tmp_flag = 0;
      $tmp_flag = 1 if ( $lines_adress[$prev] >= 1 and $lines_adress[$pos] >= 1 );
      $tmp_flag = 1 if ( $lines_adress[$prev] == 0 and $lines_adress[$pos] == 0 );
      $flag_new_line = 0 if ( $lines_content[$pos] =~ m/^and/ and $tmp_flag == 1 );
      # if ( $pos > 0 ) {
      # 	my $nr_bad_words_prev = _MarkBadWords( $lines_content[$pos-1] );
      # 	$flag_new_line = 0 if ( $lines_content[$pos-1] =~ m/,$/ and $tmp_flag == 1
      # 				and $lines_content[$pos] =~ m/^[a-z]/ and
      # 				$nr_bad_words_prev == 0 and
      # 				$nr_bad_words == 0 );
      # 	$flag_new_line = 0 if ( $lines_content[$pos-1] =~ m/\sand$/ and $tmp_flag == 1
      # 				and $lines_content[$pos] =~ m/^[a-z]/ and
      # 				$nr_bad_words_prev == 0 and
      # 				$nr_bad_words == 0 );
      # }

      if ( $flag_new_line >= 1 ) {
        push @final_content,        $lines_content[$pos];
        push @final_fs,             $lines_fs[$pos];
        push @final_nrsuperscripts, $lines_nrsuperscripts[$pos];
        push @final_nrwords,        $lines_nrwords[$pos];
        push @final_bad,            0;
        push @final_adress,         0;
	push @final_bold,           $lines_bold[$pos];
        $last_line_was_a_join = 0;

        # now score the previous one
        if ( $#final_bad > 0 ) {
          $final_bad[ $#final_bad - 1 ] += _MarkBadWords( $final_content[ $#final_bad - 1 ] );
          $final_bad[ $#final_bad - 1 ]++ unless ( $final_content[ $#final_bad - 1 ] =~ /\s/ );
          $final_adress[ $#final_adress - 1 ] +=
            _MarkAdress( $final_content[ $#final_adress - 1 ] );

        }
      } else {
        if ( $#final_bad >= 0 ) {
          $final_content[$#final_content] .= "*J* $lines_content[$pos]";
          $final_nrsuperscripts[$#final_nrsuperscripts] += $lines_nrsuperscripts[$pos];
          $final_nrwords[$#final_nrwords]               += $lines_nrwords[$pos];
          $last_line_was_a_join = 1;
        } else {
          push @final_content,        $lines_content[$pos];
          push @final_fs,             $lines_fs[$pos];
          push @final_nrsuperscripts, $lines_nrsuperscripts[$pos];
          push @final_nrwords,        $lines_nrwords[$pos];
          push @final_bad,            0;
          push @final_adress,         0;
	  push @final_bold,           $lines_bold[$pos];
          $last_line_was_a_join = 0;
        }
      }
      $last_line_diff = $diff;
      $last_line_lc   = $lc;
    }
  }

  # now score the last one
  if ( $#final_bad > -1 ) {
    $final_bad[$#final_bad] += _MarkBadWords( $final_content[$#final_bad] );
    $final_bad[$#final_bad]++ unless ( $final_content[$#final_bad] =~ /\s/ );
    $final_adress[$#final_adress] += _MarkAdress( $final_content[$#final_adress] );
  }

  # now search for authors and title
  for my $i ( 0 .. $#final_content ) {
    $final_content[$i] =~ s/"//g;
    $final_content[$i] =~ s/\x{C6}/,/g;      # replace dots (not points) with commas
    $final_content[$i] =~ s/\x{B7}/,/g;      # replace dots (not points) with commas
    $final_content[$i] =~ s/\x{B4}/,/g;      # replace dots (not points) with commas
    $final_content[$i] =~ s/\s+,\s+/, /g;    # replace unnecessary spaces
    $final_content[$i] =~ s/,\s*$//g;

    # a line must have at least five characters to be considered
    $final_bad[$i]++ if ( length($final_content[$i]) <= 5);

    #$final_content[$i] =~ s/([^[:ascii:]])/sprintf("&#%d;",ord($1))/eg; # to remove none ASCII chars
    if ( $verbose == 1 ) {
      my $tmp_line_for_print = ( length($final_content[$i]) > 80 ) ?
	substr($final_content[$i], 0, 80) . ' ...' : $final_content[$i];
      $tmp_line_for_print =~ s/[^[:ascii:]]+//g;
      print STDERR "LineNumber:$i -- ADR:",$final_adress[$i], " ==> BAD:",$final_bad[$i] ,
	" --> FS:",$final_fs[$i]," --> SUP:",$final_nrsuperscripts[$i]," :: $tmp_line_for_print\n";
    }
  }

  #####################################################
  # EXIT POINT NUMBER TWO
  # Some journal have such wired page setting styles
  # that they cannot be parsed the regular way
  # Here is the first check point if we encounter such
  # a journal
  #####################################################

  # Cell
  if ( $final_content[0] =~ m/^Cell,\sVol\./ or
       $final_content[0] =~ m/^Current\sBiology,\sVol\./ or
       $final_content[0] =~ m/^Current\sBiology\s\d+/ ) {

    # search title
    for my $i ( 0 .. $#final_content ) {
      $title = $final_content[$i] if ( $final_fs[$i] == 18 );
      $title =~ s/\*J\*//g;
    }
    if ( $title =~ m/Letter\sto\s/ ) {
      $title = '';
      for my $i ( 0 .. $#final_content ) {
	$title .= " $final_content[$i]" if ( $final_fs[$i] == 13 );
	$title =~ s/\*J\*//g;
      }
    }
    # now authors
    for my $pos ( 0 .. $#lines_content ) {
      next if ($lines_y[$pos] > 200);
      next if ($lines_x[$pos] > 110);
      next if ($lines_fs[$pos] != 8);
      last if (_MarkAdress($lines_content[$pos]) > 0);
      $authors .= " $lines_content[$pos]";
    }

    return ( $title, $authors, $doi, 0.11, $has_cover_page, $arxiv_id );
  }


  #################### STRATEGY ONE ########################
  # First, we search for an adress line. Usually authors are
  # just above that line, and then come the title
  # This is the most promising strategy and give confident
  # results

  my @adress_lines = ();

  for my $i ( 0 .. $#final_adress ) {
    if ( $final_adress[$i] > 0 ) {
      push @adress_lines, $i;
    }
  }

  # Once we have found and adress line we start to search
  foreach my $adress_line (@adress_lines) {

    # find the previous two lines that do not have bad words
    my $candidate_Authors = -1;
    my $candidate_Title   = -1;
    my $first_line        = -1;
    my $second_line       = -1;
    my $third_line        = -1;
    for ( my $i = $adress_line - 1 ; $i >= 0 ; $i-- ) {
      my $tmp_bad = $final_bad[$i] + $final_adress[$i];
      $tmp_bad-- if ( $final_content[$i] =~ m/(19\d\d|20\d\d)$/ and $final_content[$i] !~ m/(Vol\.|no\.)/i );
      my $bad_flag = _Bad_Author_Words( $final_content[$i] );
      if ( $tmp_bad == 0 and $first_line == -1 and $bad_flag == 0) {
	$first_line  = $i;
	next;
      }
      if ( $tmp_bad == 0 and $first_line != -1 and $second_line == -1) {
	$second_line = $i;
	next;
      }
      if ( $tmp_bad == 0 and $second_line != -1 ) {
	$third_line  = $i;
	last;
      }
    }

    # default
    $candidate_Title   = $second_line;
    $candidate_Authors = $first_line;

    # maybe this pair is better in some cases
    if ( _Bad_Author_Words( $final_content[$second_line] ) == 0 ) {
      if ( $final_fs[$third_line] / $major_fs > 1.2 and
	   $final_fs[$third_line] > $final_fs[$second_line] and
	   $final_nrsuperscripts[$third_line] == 0 ) {
	$candidate_Title   = $third_line;
	$candidate_Authors = $second_line;
      }
    }

    # restore the default
    my $word_count1 = ( $final_content[$third_line] =~ tr/ //);
    my $word_count2 = ( $final_content[$second_line] =~ tr/ //);

    if ( $final_nrsuperscripts[$first_line] > 0 and
	 $final_nrsuperscripts[$second_line] == 0 and
	 $final_nrsuperscripts[$second_line] == 0 ) {
      $candidate_Title   = $second_line;
      $candidate_Authors = $first_line;
    }
    if ( ($third_line == 0 or $third_line == 1) and
	 $final_fs[$third_line] > $final_fs[$second_line]
	 and $word_count1 < 5 and $word_count2 > $word_count1 ) {
      $candidate_Title   = $second_line;
      $candidate_Authors = $first_line;
    }

    next if ( $candidate_Title == -1 or $candidate_Authors == -1 );

    # cleanup PDF-Parsing/UTF-8/special char mess
    ( my $cand_authors_text = $final_content[$candidate_Authors] ) =~ s/(\s[^[:ascii:]]\s)//g;
    ( my $cand_title_text   = $final_content[$candidate_Title] )   =~ s/(\s[^[:ascii:]]\s)//g;

    # remove markers *J* that lines were joined
    $cand_authors_text =~ s/-\s?\*J\*/-/g;
    $cand_authors_text =~ s/\*J\*/,/g;
    $cand_title_text   =~ s/\*J\*//g;

    if ( $verbose == 1) {
      print STDERR "\n============ STRATEGY ONE ==========================\n";
      print STDERR "TITLE:   MFS:$major_fs FS:$final_fs[$candidate_Title] $final_content[$candidate_Title]\n";
      print STDERR "AUTHORS: MFS:$major_fs FS:$final_fs[$candidate_Authors] $final_content[$candidate_Authors]\n";
    }

    # the title is normally B and has a greater fs than the authors
    # the heading is usually much bigger than the rest
    # Note, this is restrictive but gives confident results
    # Quality_Level : 1
    if (  $final_fs[$candidate_Title] > $final_fs[$candidate_Authors]
      and $final_fs[$candidate_Title] / $major_fs > 1.2 ) {
      my $flag = 0;

      # authors have usually more superscripts than titles
      ( $title, $authors, $flag ) = _AuthorLine_by_Superscripts(
        $cand_title_text, $cand_authors_text,
        $final_nrsuperscripts[$candidate_Title],
        $final_nrsuperscripts[$candidate_Authors]
      );
      return ( $title, $authors, $doi, 1.1, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

      # authors usually have a higher comma to word ratio than the title
      ( $title, $authors, $flag ) = _AuthorLine_by_Commas( $cand_title_text, $cand_authors_text );
      return ( $title, $authors, $doi, 1.2, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

      # there could be just TWO authors
      ( $title, $authors, $flag ) =
        _AuthorLine_is_Two_Authors( $cand_title_text, $cand_authors_text );
      return ( $title, $authors, $doi, 1.3, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

      # there could be just ONE authors
      ( $title, $authors, $flag ) =
        _AuthorLine_is_One_Author( $cand_title_text, $cand_authors_text );
      return ( $title, $authors, $doi, 1.4, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

    }

    # they might be of same size, but then we do not take all rules
    if (  $final_fs[$candidate_Title] == $final_fs[$candidate_Authors]
      and $final_fs[$candidate_Title] > $major_fs ) {
      my $flag = 0;

      # authors have usually more superscripts than titles
      ( $title, $authors, $flag ) = _AuthorLine_by_Superscripts(
        $cand_title_text, $cand_authors_text,
        $final_nrsuperscripts[$candidate_Title],
        $final_nrsuperscripts[$candidate_Authors]
      );
      return ( $title, $authors, $doi, 1.91, $has_cover_page, $arxiv_id ) if ( $flag == 1 );
    }

    # they might be of same size, but then we do not take all rules
    if (  $final_fs[$candidate_Title] == $final_fs[$candidate_Authors] ) {
      if ( $final_fs[$candidate_Title] > $major_fs ) {
	my $flag = 0;

	# authors have usually more superscripts than titles
	( $title, $authors, $flag ) = _AuthorLine_by_Superscripts(
        $cand_title_text, $cand_authors_text,
        $final_nrsuperscripts[$candidate_Title],
        $final_nrsuperscripts[$candidate_Authors]
								 );
	return ( $title, $authors, $doi, 1.92, $has_cover_page, $arxiv_id ) if ( $flag == 1 );
      }
      if ( $final_bold[$candidate_Title] == 1 and $final_bold[$candidate_Authors] == 0 ) {
	  my $flag = 0;
	  # authors usually have a higher comma to word ratio than the title
	  ( $title, $authors, $flag ) = _AuthorLine_by_Commas( $cand_title_text, $cand_authors_text );
	  return ( $title, $authors, $doi, 1.94, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

	  # there could be just TWO authors
	  ( $title, $authors, $flag ) =
	    _AuthorLine_is_Two_Authors( $cand_title_text, $cand_authors_text );
	  return ( $title, $authors, $doi, 1.95, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

	  # there could be just ONE authors
	  ( $title, $authors, $flag ) =
	    _AuthorLine_is_One_Author( $cand_title_text, $cand_authors_text );
	  return ( $title, $authors, $doi, 1.96, $has_cover_page, $arxiv_id ) if ( $flag == 1 );
	}
    }

    # Title is larger than Authors, but title is the same as major font size
    if ( $final_fs[$candidate_Title] > $final_fs[$candidate_Authors] ) {
      if ( $final_fs[$candidate_Title] == $major_fs ) {
	# in this case the title has to be all upper case
	(my $title_temp = $cand_title_text) =~ s/([^[:ascii:]])//;
	if ( $title_temp eq uc($title_temp)) {
	  my $flag = 0;

	  # authors have usually more superscripts than titles
	  ( $title, $authors, $flag ) = _AuthorLine_by_Superscripts(
           $cand_title_text, $cand_authors_text,
           $final_nrsuperscripts[$candidate_Title],
           $final_nrsuperscripts[$candidate_Authors] );
	  return ( $title, $authors, $doi, 1.921, $has_cover_page, $arxiv_id ) if ( $flag == 1 );
	}
      }
    }

    # just minimal difference
    if (  $final_fs[$candidate_Title] - $final_fs[$candidate_Authors] == 1 ) {
	my $flag = 0;

	# authors usually have a higher comma to word ratio than the title
	( $title, $authors, $flag ) = _AuthorLine_by_Commas( $cand_title_text, $cand_authors_text );
	return ( $title, $authors, $doi, 1.93, $has_cover_page, $arxiv_id ) if ( $flag == 1 );
    }

    # the order might be changed, but then we do not take all rules
    if (  $final_fs[$candidate_Title] < $final_fs[$candidate_Authors]
      and $final_fs[$candidate_Authors] / $major_fs > 1.2 ) {
      my $swap = $candidate_Title;
      $candidate_Title   = $candidate_Authors;
      $candidate_Authors = $swap;
      ( $cand_authors_text = $final_content[$candidate_Authors] ) =~ s/(\s[^[:ascii:]]\s)//g;
      ( $cand_title_text   = $final_content[$candidate_Title] )   =~ s/(\s[^[:ascii:]]\s)//g;

      # remove markers *J* that lines were joined
      $cand_authors_text =~ s/-\s?\*J\*/-/g;
      $cand_authors_text =~ s/\*J\*/,/g;
      $cand_title_text   =~ s/\*J\*//g;

      my $flag = 0;

      # authors have usually more superscripts than titles
      ( $title, $authors, $flag ) = _AuthorLine_by_Superscripts(
        $cand_title_text, $cand_authors_text,
        $final_nrsuperscripts[$candidate_Title],
        $final_nrsuperscripts[$candidate_Authors]
      );
      return ( $title, $authors, $doi, 1.5, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

      # authors usually have a higher comma to word ratio than the title
      ( $title, $authors, $flag ) = _AuthorLine_by_Commas( $cand_title_text, $cand_authors_text );
      return ( $title, $authors, $doi, 1.6, $has_cover_page, $arxiv_id ) if ( $flag == 1 );
    }

  }

  #################### STRATEGY TWO ########################
  # Once you are here, you know that Strategy 1 did not work.
  # Now we have a look at those lines that do not have "bad
  # words" and see if there are some characteristics

  # let's find all "NONE BAD" lines and the line with the
  # largest font size
  my @IDS                 = ();
  my $max_fs_NONEBAD      = 0;
  my $max_fs_line_NONEBAD = -1;
  my $max_fs_ALL          = 0;
  my $max_fs_line_ALL     = -1;
  my $k                   = -1;

  print STDERR "\n============ STRATEGY TWO PRESELECTION ================\n" if ( $verbose == 1);
  for my $i ( 0 .. $#final_content ) {
    print STDERR "\tBAD:$final_bad[$i] AD:$final_adress[$i] FS:$final_fs[$i] MF:$major_fs $final_content[$i]\n"
      if ( $verbose == 1);
    # a year in the title is okay
    my $year_flag = ( $final_content[$i] =~ m/(18\d\d|19\d\d|20\d\d)/) ? 1 : 0 ;

    if ( $final_bad[$i]-$year_flag == 0 and $final_adress[$i] == 0 and $final_fs[$i] >= $major_fs ) {
      push @IDS, $i;
      $k++;
      if ( $final_fs[$i] > $max_fs_NONEBAD ) {
        $max_fs_NONEBAD      = $final_fs[$i];
        $max_fs_line_NONEBAD = $k;
      }
    }

    if ( $final_fs[$i] > $max_fs_ALL and $final_bad[$i] == 0) {
      $max_fs_ALL      = $final_fs[$i];
      $max_fs_line_ALL = $i;
    }
  }

  #####################################################################################
  # We might just find one line. This happens e.g. if authors have a font
  # size smaller than the major font size
  if ( $#IDS == 0 and $max_fs_line_ALL == $IDS[0] ) {
    # let's find the next line that is none bad
    my $next_good_line = -1;
    for my $i ( $IDS[0] + 1 .. $#final_content ) {
      my $flag = 0;
      $flag = 1 if ( $final_bad[$i] == 0 and $final_adress[$i] == 0 );
      $flag = 1 if ( $final_nrsuperscripts[$i] > 0 and $final_adress[$i] == 0 );
      if ( $flag == 1 ) {
        $next_good_line = $i;
        last;
      }
    }

    # we have found a good line and it is not that far away
    if ( $next_good_line != -1 and abs($next_good_line-$IDS[0]) <= 3) {

      ( my $cand_authors_text = $final_content[$next_good_line] ) =~ s/(\s[^[:ascii:]]\s)//g;
      ( my $cand_title_text   = $final_content[$IDS[0]] ) =~ s/(\s[^[:ascii:]]\s)//g;

      # remove markers *J* that lines were joined
      $cand_authors_text =~ s/-\s?\*J\*/-/g;
      $cand_authors_text =~ s/\*J\*/,/g;
      $cand_authors_text =~ s/,\sand\s/ and /g;
      $cand_title_text   =~ s/\*J\*//g;

      my $flag = 0;
      # authors usually have a higher comma to word ratio than the title
      ( $title, $authors, $flag ) = _AuthorLine_by_Commas( $cand_title_text, $cand_authors_text );
      return ( $title, $authors, $doi, 0.1, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

      # authors have usually more superscripts than titles
      ( $title, $authors, $flag ) = _AuthorLine_by_Superscripts(
            $cand_title_text, $cand_authors_text,
            $final_nrsuperscripts[$IDS[0]],
            $final_nrsuperscripts[$next_good_line] );
      return ( $title, $authors, $doi, 0.2, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

      # there could be just TWO authors
      ( $title, $authors, $flag ) =
	_AuthorLine_is_Two_Authors( $cand_title_text, $cand_authors_text );
      return ( $title, $authors, $doi, 2.3, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

      # there could be just ONE authors
      ( $title, $authors, $flag ) =
	_AuthorLine_is_One_Author( $cand_title_text, $cand_authors_text );
      return ( $title, $authors, $doi, 2.4, $has_cover_page, $arxiv_id ) if ( $flag == 1 );
    }
  }

  ######################################################################################
  # if we find just two lines, then this is a good sign
  print STDERR '======= $#IDS: ',$#IDS," =============\n" if ($verbose == 1);
  if ( $#IDS == 1 ) {
    my $candidate_Authors = $IDS[1];
    my $candidate_Title   = $IDS[0];

    ( my $cand_authors_text = $final_content[$candidate_Authors] ) =~ s/(\s[^[:ascii:]]\s)//g;
    ( my $cand_title_text   = $final_content[$candidate_Title] )   =~ s/(\s[^[:ascii:]]\s)//g;

    # remove markers *J* that lines were joined
    $cand_authors_text =~ s/-\s?\*J\*/-/g;
    $cand_authors_text =~ s/\*J\*/,/g;
    $cand_authors_text =~ s/,\sand\s/, /g;
    $cand_title_text   =~ s/\*J\*//g;

    if ( $verbose == 1 ) {
      print STDERR "\n============ STRATEGY TWO ==========================\n";
      print STDERR "TITLE:   MFS:$major_fs FS:$final_fs[$candidate_Title] $final_content[$candidate_Title]\n";
      print STDERR "AUTHORS: MFS:$major_fs FS:$final_fs[$candidate_Authors] $final_content[$candidate_Authors]\n";
    }

    # if the candidate_Title is also very large
    # then this is a good sign
    if ( ( $final_fs[$max_fs_line_ALL] - $final_fs[$candidate_Title] ) / $major_fs < 0.2 ) {

      # the heading is normally B and has a greater fs than the authors
      if ( $final_fs[$candidate_Title] > $final_fs[$candidate_Authors] ) {
        my $flag = 0;

        # authors have usually more superscripts than titles
        ( $title, $authors, $flag ) = _AuthorLine_by_Superscripts(
          $cand_title_text, $cand_authors_text,
          $final_nrsuperscripts[$candidate_Title],
          $final_nrsuperscripts[$candidate_Authors]
        );
        return ( $title, $authors, $doi, 2.1, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

        # authors usually have a higher comma to word ratio than the title
        ( $title, $authors, $flag ) = _AuthorLine_by_Commas( $cand_title_text, $cand_authors_text );
        return ( $title, $authors, $doi, 2.2, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

        # there could be just TWO authors
        ( $title, $authors, $flag ) =
          _AuthorLine_is_Two_Authors( $cand_title_text, $cand_authors_text );
        return ( $title, $authors, $doi, 2.3, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

        # there could be just ONE authors
        ( $title, $authors, $flag ) =
          _AuthorLine_is_One_Author( $cand_title_text, $cand_authors_text );
        return ( $title, $authors, $doi, 2.4, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

        # if Title directly preceeds Authors and Title seems to be really hughe
        if (  $candidate_Title == $candidate_Authors - 1
          and $final_fs[$candidate_Title] / $major_fs > 1.3 ) {
          $authors = $cand_authors_text;
          $title   = $cand_title_text;
          return ( $title, $authors, $doi, 2.9, $has_cover_page, $arxiv_id );
        }
      }

      if ( $final_fs[$candidate_Title] == $final_fs[$candidate_Authors] and
	   $final_fs[$candidate_Title] / $major_fs > 1.3 ) {
	# same fontsize but at least title is bold
	if ( $final_bold[$candidate_Title] == 1 and $final_bold[$candidate_Authors] == 0 ) {
	  my $flag = 0;
	  # authors usually have a higher comma to word ratio than the title
	  ( $title, $authors, $flag ) = _AuthorLine_by_Commas( $cand_title_text, $cand_authors_text );
	  return ( $title, $authors, $doi, 2.21, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

	  # there could be just TWO authors
	  ( $title, $authors, $flag ) =
	    _AuthorLine_is_Two_Authors( $cand_title_text, $cand_authors_text );
	  return ( $title, $authors, $doi, 2.31, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

	  # there could be just ONE authors
	  ( $title, $authors, $flag ) =
	    _AuthorLine_is_One_Author( $cand_title_text, $cand_authors_text );
	  return ( $title, $authors, $doi, 2.41, $has_cover_page, $arxiv_id ) if ( $flag == 1 );
	}
      }
    }

    #################################################################
    # the order might be changed, but then we do not take all rules
    if (  $final_fs[$candidate_Title] < $final_fs[$candidate_Authors]
      and $final_fs[$candidate_Authors] / $major_fs > 1.2 ) {
      my $swap = $candidate_Title;
      $candidate_Title   = $candidate_Authors;
      $candidate_Authors = $swap;
      ( $cand_authors_text = $final_content[$candidate_Authors] ) =~ s/(\s[^[:ascii:]]\s)//g;
      ( $cand_title_text   = $final_content[$candidate_Title] )   =~ s/(\s[^[:ascii:]]\s)//g;

      # remove markers *J* that lines were joined
      $cand_authors_text =~ s/-\s?\*J\*/-/g;
      $cand_authors_text =~ s/\*J\*/,/g;
      $cand_title_text   =~ s/\*J\*//g;

      my $flag = 0;

      # authors have usually more superscripts than titles
      ( $title, $authors, $flag ) = _AuthorLine_by_Superscripts(
        $cand_title_text, $cand_authors_text,
        $final_nrsuperscripts[$candidate_Title],
        $final_nrsuperscripts[$candidate_Authors]
      );
      return ( $title, $authors, $doi, 2.5, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

      # authors usually have a higher comma to word ratio than the title
      ( $title, $authors, $flag ) = _AuthorLine_by_Commas( $cand_title_text, $cand_authors_text );
      return ( $title, $authors, $doi, 2.6, $has_cover_page, $arxiv_id ) if ( $flag == 1 );
    }

    # if there are just two lines left and the have the same font size. As seen on scanned
    # papers from Oxford journals.
    if ( $final_fs[$candidate_Title] == $final_fs[$candidate_Authors] ) {
      my $flag = 0;

      # authors have usually more superscripts than titles
      ( $title, $authors, $flag ) = _AuthorLine_by_Superscripts(
        $cand_title_text, $cand_authors_text,
        $final_nrsuperscripts[$candidate_Title],
        $final_nrsuperscripts[$candidate_Authors]
      );
      return ( $title, $authors, $doi, 2.71, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

      # authors usually have a higher comma to word ratio than the title
      ( $title, $authors, $flag ) = _AuthorLine_by_Commas( $cand_title_text, $cand_authors_text );
      return ( $title, $authors, $doi, 2.72, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

      # there could be just TWO authors
      ( $title, $authors, $flag ) =
        _AuthorLine_is_Two_Authors( $cand_title_text, $cand_authors_text );
      return ( $title, $authors, $doi, 2.73, $has_cover_page, $arxiv_id ) if ( $flag == 1 );
    }
  }

  # there are more than two lines left
  if ( $#IDS > 1 ) {

    return ( $title, $authors, $doi, 4, $has_cover_page, $arxiv_id )
      if ( $max_fs_line_NONEBAD + 1 > $#IDS );

    my $candidate_Authors = $IDS[ $max_fs_line_NONEBAD + 1 ];
    my $candidate_Title   = $IDS[$max_fs_line_NONEBAD];

    ( my $cand_authors_text = $final_content[$candidate_Authors] ) =~ s/(\s[^[:ascii:]]\s)//g;
    ( my $cand_title_text   = $final_content[$candidate_Title] )   =~ s/(\s[^[:ascii:]]\s)//g;

    # remove markers *J* that lines were joined
    $cand_authors_text =~ s/-\s?\*J\*/-/g;
    $cand_authors_text =~ s/\*J\*/,/g;
    $cand_title_text   =~ s/\*J\*//g;

    #print "$final_fs[$max_fs_line_ALL] - $final_fs[$candidate_Title] ) / $major_fs\n";
    if ( ( $final_fs[$max_fs_line_ALL] - $final_fs[$candidate_Title] ) / $major_fs < 0.2 ) {

      # the heading is normally B and has a greater fs than the authors
      if ( $final_fs[$candidate_Title] > $final_fs[$candidate_Authors] ) {
        my $flag = 0;

        # authors have usually more superscripts than titles
        ( $title, $authors, $flag ) = _AuthorLine_by_Superscripts(
          $cand_title_text, $cand_authors_text,
          $final_nrsuperscripts[$candidate_Title],
          $final_nrsuperscripts[$candidate_Authors]
        );
        return ( $title, $authors, $doi, 3.1, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

        # authors usually have a higher comma to word ratio than the title
        ( $title, $authors, $flag ) = _AuthorLine_by_Commas( $cand_title_text, $cand_authors_text );
        return ( $title, $authors, $doi, 3.2, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

        # there could be just TWO authors
        ( $title, $authors, $flag ) =
          _AuthorLine_is_Two_Authors( $cand_title_text, $cand_authors_text );
        return ( $title, $authors, $doi, 3.3, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

        # there could be just ONE authors
        ( $title, $authors, $flag ) =
          _AuthorLine_is_One_Author( $cand_title_text, $cand_authors_text );
        return ( $title, $authors, $doi, 3.4, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

        # if Title directly preceeds Authors and Title seems to be really hughe
        if (  $candidate_Title == $candidate_Authors - 1
          and $final_fs[$candidate_Title] / $major_fs > 1.3 ) {
          $authors = $cand_authors_text;
          $title   = $cand_title_text;
          return ( $title, $authors, $doi, 3.9, $has_cover_page, $arxiv_id );
        }
      }
      if ( $final_fs[$candidate_Title] == $final_fs[$candidate_Authors] and
	   $final_fs[$candidate_Title] / $major_fs > 1.3 ) {
	# same fontsize but at least title is bold
	if ( $final_bold[$candidate_Title] == 1 and $final_bold[$candidate_Authors] == 0 ) {
	  my $flag = 0;
	  # authors usually have a higher comma to word ratio than the title
	  ( $title, $authors, $flag ) = _AuthorLine_by_Commas( $cand_title_text, $cand_authors_text );
	  return ( $title, $authors, $doi, 2.211, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

	  # there could be just TWO authors
	  ( $title, $authors, $flag ) =
	    _AuthorLine_is_Two_Authors( $cand_title_text, $cand_authors_text );
	  return ( $title, $authors, $doi, 2.311, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

	  # there could be just ONE authors
	  ( $title, $authors, $flag ) =
	    _AuthorLine_is_One_Author( $cand_title_text, $cand_authors_text );
	  return ( $title, $authors, $doi, 2.411, $has_cover_page, $arxiv_id ) if ( $flag == 1 );
	}
      }
    } else {

      # very last chance to become a good hit
      my $count_spaces = ( $cand_title_text =~ tr/ // );    # rough estimate of words
      if ( $final_fs[$candidate_Title] / $major_fs > 1.5 and $count_spaces > 5 ) {

        # the heading is normally B and has a greater fs than the authors
        if ( $final_fs[$candidate_Title] > $final_fs[$candidate_Authors] ) {
          my $flag = 0;

          # authors have usually more superscripts than titles
          ( $title, $authors, $flag ) = _AuthorLine_by_Superscripts(
            $cand_title_text, $cand_authors_text,
            $final_nrsuperscripts[$candidate_Title],
            $final_nrsuperscripts[$candidate_Authors]
          );
          return ( $title, $authors, $doi, 5.1, $has_cover_page, $arxiv_id ) if ( $flag == 1 );

          # authors usually have a higher comma to word ratio than the title
          ( $title, $authors, $flag ) =
            _AuthorLine_by_Commas( $cand_title_text, $cand_authors_text );
          return ( $title, $authors, $doi, 5.2, $has_cover_page, $arxiv_id ) if ( $flag == 1 );
        }
      }
    }
  }

  return ( $title, $authors, $doi, 4, $has_cover_page, $arxiv_id );
}

1;
