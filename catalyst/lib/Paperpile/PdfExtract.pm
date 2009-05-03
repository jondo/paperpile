package Paperpile::PdfExtract;

use Moose;
use Paperpile::Library::Publication;
use Data::Dumper;

has 'file'    => ( is => 'rw', isa => 'Str' );
has 'pub'     => ( is => 'rw', isa => 'PaperPile::Library::Publication' );
has 'pdftoxml' => ( is => 'rw', isa => 'Str' );

#( my $title, my $authors, my $doi, my $level ) = ParsePDF( $ARGV[0] );

#print "LEVEL:$level\nTITLE:$title\nAUTHORS:$authors\nDOI:$doi\n";

sub parsePDF {

  my $self =shift;

  my $PDFfile = $self->file;
  my $PDF2XML = $self->pdftoxml;

  # create and read XML file
  system("$PDF2XML $PDFfile -noImage -f 1 -l 2 2>/dev/null");
  my $PDFxml = ( $PDFfile =~ m/(.*)(\.pdf)$/ ) ? "$1.xml" : "$PDFfile.xml";
  my $xml    = new XML::Simple;
  my $data   = $xml->XMLin( "$PDFxml", ForceArray => 1 );

  my @page0   = @{ $data->{PAGE}->[0]->{TEXT} } if ( defined $data->{PAGE}->[0]->{TEXT} );
  my $doi     = '';
  my $title   = '';
  my $authors = '';
  my $level   = -1;

  if ( $#page0 > -1 ) {
    ( $title, $authors, $doi, $level ) = _ParseXML( \@page0 );
  }

  # maybe the first page is a strange cover page (Cold Spring Harbour Press)
  if ( $title eq '' and $authors eq '' and $doi eq '' ) {
    my @page1 = @{ $data->{PAGE}->[1]->{TEXT} } if ( defined $data->{PAGE}->[1]->{TEXT} );
    if ( $#page1 > -1 ) {
      ( $title, $authors, $doi, $level ) = _ParseXML( \@page1 );
    }
  }

  # let's do some sane checking
  my $wrong = 0;
  $wrong = 1 if ( $title =~ m/MAtERIALS And MEtHOdS/i );
  $wrong = 1 if ( $title =~ m/^MEtHOdS$/i );
  $wrong = 1 if ( $title =~ m/^Introduction$/i );
  $wrong = 1 if ( $title =~ m/^Results$/i );
  $wrong = 1 if ( _Bad_Author_Words($authors) == 1 );

  if ( $wrong == 1 ) {
    $authors = '';
    $title   = '';
    $level   = -2;
  }

  return ( $title, $authors, $doi, $level );
}

sub _Bad_Author_Words {
  my $line = $_[0];

  my $flag = 0;
  $flag = 1 if ( $line =~ m/\sthis\s/i );
  $flag = 1 if ( $line =~ m/\sthat\s/i );
  $flag = 1 if ( $line =~ m/\shere\s/i );
  $flag = 1 if ( $line =~ m/\swhere\s/i );
  $flag = 1 if ( $line =~ m/\sstudy\s/i );
  $flag = 1 if ( $line =~ m/\sabout\s/i );
  $flag = 1 if ( $line =~ m/\swhat\s/i );
  $flag = 1 if ( $line =~ m/\swhich/i );

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

  if ( $commas_authors / $words_authors > $commas_title / $words_title ) {
    $authors = $candidate_authors;
    $title   = $candidate_title;
    $flag    = 1;
  }

  return ( $title, $authors, $flag );
}

sub _AuthorLine_is_Two_Authors {
  my $candidate_title   = $_[0];
  my $candidate_authors = $_[1];
  my $title             = '';
  my $authors           = '';
  my $flag              = 0;

  my @temp_authors = split( / and /, $candidate_authors );

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

  my $spaces = ( $candidate_title =~ tr/ // );
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
  $bad++ if ( $tmp_line =~ m/articles?$/i );
  $bad++ if ( $tmp_line =~ m/paper$/i );
  $bad++ if ( $tmp_line =~ m/review$/i );
  $bad++ if ( $tmp_line =~ m/^(research)?report$/i );
  $bad++ if ( $tmp_line =~ m/^(Short)?Communication$/i );
  $bad++ if ( $tmp_line =~ m/^originalresearch$/i );
  $bad++ if ( $tmp_line =~ m/originalarticle/i );
  $bad++ if ( $tmp_line =~ m/^Letters$/i );
  $bad++ if ( $tmp_line =~ m/^(short)?(scientific)?reports?$/i );
  $bad++ if ( $tmp_line =~ m/^ORIGINALINVESTIGATION$/i );

  # years
  $bad++ if ( $tmp_line =~ m/20\d\d/ );
  $bad++ if ( $tmp_line =~ m/19\d\d/ );

  # other stuff like doi,...
  $bad++ if ( $tmp_line =~ m/doi/i );
  $bad++ if ( $tmp_line =~ m/vol\.\d+/i );
  $bad++ if ( $tmp_line =~ m/keywords/i );
  $bad++ if ( $tmp_line =~ m/openaccess$/i );
  $bad++ if ( $tmp_line =~ m/ScienceDirect/i );
  $bad++ if ( $tmp_line =~ m/Blackwell/i );
  $bad++ if ( $tmp_line =~ m/journalhomepage/i );
  $bad++ if ( $tmp_line =~ m/e-?mail/i );
  $bad++ if ( $tmp_line =~ m/journal/i );
  $bad++ if ( $tmp_line =~ m/ISSN/i );
  $bad++ if ( $tmp_line =~ m/http:\/\// );
  $bad++ if ( $tmp_line =~ m/\.html/i );
  $bad++ if ( $tmp_line =~ m/Copyright/i );
  $bad++ if ( $tmp_line =~ m/BioMedCentral/i );
  $bad++ if ( $tmp_line =~ m/BMC/ );
  $bad++ if ( $tmp_line =~ m/corresponding/i );
  $bad++ if ( $tmp_line =~ m/author/i );
  $bad++ if ( $tmp_line =~ m/Abbreviations/i );
  $bad++ if ( $tmp_line =~ m/@/i );
  $bad++ if ( $tmp_line =~ m/Hindawi/i );
  $bad++ if ( $tmp_line =~ m/Pages\d+/i );
  $bad++ if ( $tmp_line =~ m/\.{5,}/i );            # more than five dots in a row
  $bad++ if ( $tmp_line =~ m/\d\d+-\d\d+/i );       # pages
  $bad++ if ( $tmp_line =~ m/\[\d+\]/i );           # citations
  $bad++ if ( $tmp_line =~ m/\[\d+-\d+\]/i );       # citations

  # if it starts with superscripts or a number
  $bad++ if ( $tmp_line =~ m/^%SC_S%/ );
  $bad++ if ( $tmp_line =~ m/^\*/ );
  $bad++ if ( $tmp_line =~ m/^\d+$/ );

  #print "$bad $orig<br>\n";

  return $bad;
}

sub _MarkAdress {
  my $orig = $_[0];
  ( my $tmp_line = $orig ) =~ s/\s//g;
  my $adress = 0;

  # lines that have author's affiliations
  $adress++ if ( $tmp_line =~ m/Universi[t|d]/i );
  $adress++ if ( $tmp_line =~ m/Department/i );
  $adress++ if ( $tmp_line =~ m/D.partement/i );
  $adress++ if ( $tmp_line =~ m/Dept\./i );
  $adress++ if ( $tmp_line =~ m/Center(for)?(of)?/i );
  $adress++ if ( $tmp_line =~ m/Centre(for)?(of)?/i );
  $adress++ if ( $tmp_line =~ m/Laboratory/i );
  $adress++ if ( $tmp_line =~ m/division(of)?/i );
  $adress++ if ( $tmp_line =~ m/Institut/i );
  $adress++ if ( $tmp_line =~ m/Science Division/i );
  $adress++ if ( $tmp_line =~ m/(current)?(present)?address/i );
  $adress-- if ( $tmp_line =~ m/addressed/i );
  $adress++ if ( $tmp_line =~ m/school/i );
  $adress++ if ( $tmp_line =~ m/Faculty/i );
  $adress++ if ( $tmp_line =~ m/P\.O\.Box/i );
  $adress++ if ( $tmp_line =~ m/POBox/i );
  $adress++ if ( $tmp_line =~ m/GeneralHospital/i );
  $adress++ if ( $tmp_line =~ m/Hospitalof/i );
  $adress++ if ( $tmp_line =~ m/Facultad/i );

  return $adress;

}

sub _ParseDOI {
  my $doi = $_[0];

  # now we try to parse the doi in a more elaborate regexp
  # there is a bug in pdf2xml and pdf2text: sometimes the loose
  # a slash in an URL; but this regexp should be able to handel it

  # there might be a strange minus sign (unicode &#8211; --> \x{2013}
  $doi =~ s/\s\x{2013}\s/-/g;
  if ( $doi =~ m/\D(10\.\d{4})/ ) {
    $doi =~ s/(.*)(10\.\d{4})(\/?\s*)(\S+)(.*)/$2\/$4/;
    $doi =~ s/\(*\)*//g;
  } else {
    $doi = '';
  }

  # DOIs do not have commas
  $doi =~ s/,//g;

  return $doi;
}

sub _ParseXML {
  my @lines = @{ $_[0] };

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

  my %seen_fontsizes = ();
  my $doi            = '';
  my $title          = '';
  my $authors        = '';
  my $min_x          = 100000;
  my $max_x          = 0;
  my $first_y        = 0;
  my $y_abstract     = 1000;
  my $y_intro        = 1000;

  ###########################################
  # read in all the elements
  ###########################################

  # @lines holds all TEXT elements (TEXT -> one line)

  my @tmp   = ();
  my $count = 0;
  foreach my $j ( 0 .. $#lines ) {

    # TOKEN elements are the words
    my @words = @{ $lines[$j]->{TOKEN} };
    my $y     = $lines[$j]->{'y'};
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
    my $angle_flag    = 0;
    foreach my $i ( 0 .. $#words ) {

      if ( $words[$i]->{angle} != 0 )    # we do not want watermarks and all that stuff
      {
        $angle_flag = 1;
        last;
      }

      if ( $words[$i]->{content} ) {
        $first_y = $words[$i]->{'y'} if ( $first_y == 0 );
        $hash_fontsize{ $words[$i]->{'font-size'} }++;
        ( $words[$i]->{'bold'}   eq 'yes' ) ? $bold_yes++   : $bold_no++;
        ( $words[$i]->{'italic'} eq 'yes' ) ? $italic_yes++ : $italic_no++;
      }
    }
    next if ( $angle_flag == 1 );

    $nr_words = $#words + 1;
    $bold     = 1 if ( $bold_yes / $nr_words > 0.5 );
    $italic   = 1 if ( $italic_yes / $nr_words > 0.5 );

    # now determine the fontsize for the line
    for my $key ( keys %hash_fontsize ) {
      $fs = $key if ( $hash_fontsize{$key} / $nr_words > 0.5 );
      $seen_fontsizes{$key} += $hash_fontsize{$key};
    }

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

        #$word  =~ s/([^[:ascii:]])/sprintf("&#%d;",ord($1))/eg; # to remove none ASCII chars

        if ( $words[$i]->{'font-size'} < $fs ) {
          $count++;

          #$word = "%SC_S$count%$word%SC_E$count%";
          $word = '';
          $nr_superscripts++;
          $starts_with_superscript = 1 if ( $i == 0 );
        }

        # let's screen for special chars that mark authors
        if ( $word =~ m/\x{2021}/ ) {
          $word =~ s/\x{2021}//g;
          $nr_superscripts++;
        }
        if ( $word =~ m/\*/ ) {
          $word =~ s/\*//g;
          $nr_superscripts++;
        }
        push @content, $word if ( $word ne '' );
      }
    }

    my $content_line     = join( " ", @content );
    my $content_line_tmp = join( "",  @content );

    $y_abstract = $y if ( $content_line_tmp =~ m/Abstract$/i );
    $y_abstract = $y if ( $content_line_tmp =~ m/^Abstract/i );
    $y_intro    = $y if ( $content_line_tmp =~ m/^(\d\.?)?Introduction$/i and $y < $y_intro );
    $y_intro    = $y if ( $content_line_tmp =~ m/^(\d\.?)?Results$/i and $y < $y_intro );
    $y_intro    = $y if ( $content_line_tmp =~ m/^(\d\.?)?Background$/i and $y < $y_intro );
    $y_intro    = $y if ( $content_line_tmp =~ m/^(\d\.?)?Methods$/i and $y < $y_intro );
    $y_intro    = $y if ( $content_line_tmp =~ m/^(\d\.?)?Summary$/i and $y < $y_intro );

    # now we can search for the DOI
    if ( $doi eq '' or $doi =~ m/\/$/ ) {

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

        #print "######### $content_line $first_y\n";
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

  #################################################3
  # LET'S JOIN THE LINES

  my @final_content        = ();
  my @final_fs             = ();
  my @final_nrsuperscripts = ();
  my @final_nrwords        = ();
  my @final_bad            = ();
  my @final_adress         = ();

  my $last_line_was_a_join = 0;
  my $last_line_diff       = 0;
  my $last_line_lc         = 0;

  for my $pos ( 0 .. $#lines_content ) {
    my $threshold = ( $y_abstract < $y_intro ) ? $y_abstract : $y_intro;
    if ( $lines_y[$pos] < $threshold ) {
      my $prev = $pos - 1;
      $prev = $pos if ( $#final_content == -1 );
      my $flag_new_line = 1;
      my $adress        = 0;

      # if it has the same fontsize as the last one AND
      # the line spacing is the most frequent one for
      # this fontsize, then we join
      # also italic and bold have to fit

      my $lc = ( $lines_content[$pos] =~ tr/[a-z]// );

      my $diff        = abs( $lines_y[$prev] - $lines_y[$pos] );
      my $same_fs     = ( $lines_fs[$pos] eq $lines_fs[$prev] ) ? 1 : 0;
      my $same_bold   = ( $lines_bold[$pos] eq $lines_bold[$prev] ) ? 1 : 0;
      my $same_italic = ( $lines_italic[$pos] eq $lines_italic[$prev] ) ? 1 : 0;
      my $same_diff   = 1;
      if ( $last_line_was_a_join == 1 ) {
        $same_diff = 0 if ( $diff != $last_line_diff );
      }

      $flag_new_line = 7 if ( _MarkBadWords( $lines_content[$pos] ) > 0 );
      $flag_new_line = 0 if ( $same_fs == 1 and $same_bold == 1 and $same_italic == 1 );
      $flag_new_line = 2 if ( $lines_starts_with_superscripts[$pos] == 1 );
      $flag_new_line = 3 if ( $lines_content[$pos] =~ m/^\*/ );
      $flag_new_line = 4 if ( $lines_adress[$pos] >= 1 );
      $flag_new_line = 5 if ( $lines_y[$pos] < $lines_y[$prev] );
      $flag_new_line = 6 if ( $lc > 0 and $last_line_lc == 0 );
      $flag_new_line = 0
        if ( $lines_adress[$prev] == 1 and $lines_adress[$pos] == 1 and $flag_new_line == 1 );
      $flag_new_line = 0 if ( $lines_content[$pos] =~ m/^and/ );

      #print "$flag_new_line $lines_adress[$pos] $lines_content[$pos] $lc<br>\n";

      if ( $flag_new_line >= 1 ) {
        push @final_content,        $lines_content[$pos];
        push @final_fs,             $lines_fs[$pos];
        push @final_nrsuperscripts, $lines_nrsuperscripts[$pos];
        push @final_nrwords,        $lines_nrwords[$pos];
        push @final_bad,            0;
        push @final_adress,         0;
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
          $final_content[$#final_content] .= " $lines_content[$pos]";
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
          $last_line_was_a_join = 0;
        }
      }
      $last_line_diff = $diff;
      $last_line_lc   = $lc;
    }
  }

  # now score the last one
  $final_bad[$#final_bad] += _MarkBadWords( $final_content[$#final_bad] );
  $final_bad[$#final_bad]++ unless ( $final_content[$#final_bad] =~ /\s/ );
  $final_adress[$#final_adress] += _MarkAdress( $final_content[$#final_adress] );

  # now search for authors and title
  for my $i ( 0 .. $#final_content ) {
    $final_content[$i] =~ s/\x{C6}/,/g;      # replace dots (not points) with commas
    $final_content[$i] =~ s/\x{B7}/,/g;      # replace dots (not points) with commas
    $final_content[$i] =~ s/\s+,\s+/, /g;    # replace unnecessary spaces
      #$final_content[$i] =~ s/([^[:ascii:]])/sprintf("&#%d;",ord($1))/eg; # to remove none ASCII chars
  }

  #################### STRATEGY ONE ########################
  # First, we search for an adress line. Usually authors are
  # just above that line, and then come the title
  # This is the most promising strategy and give confident
  # results

  my $adress_line = -1;
  for my $i ( 0 .. $#final_adress ) {
    if ( $final_adress[$i] > 0 ) {
      $adress_line = $i;
      last;
    }
  }

  # Once we have found and adress line we start to search
  if ( $adress_line > -1 ) {

    # find the previous two lines that do not have bad words
    my $candidate_Authors = -1;
    my $candidate_Title   = -1;
    for ( my $i = $adress_line - 1 ; $i >= 0 ; $i-- ) {
      my $tmp_bad = $final_bad[$i] + $final_adress[$i];
      if ( $tmp_bad == 0 and $candidate_Authors == -1 ) {

        # some simple checking that we do not get normal text
        my $flag = _Bad_Author_Words( $final_content[$i] );

        if ( $flag == 0 ) {
          $candidate_Authors = $i;
        }
      } else {
        $candidate_Title = $i if ( $tmp_bad == 0 and $candidate_Title == -1 );
      }

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
        $final_content[$candidate_Title],        $final_content[$candidate_Authors],
        $final_nrsuperscripts[$candidate_Title], $final_nrsuperscripts[$candidate_Authors]
      );
      return ( $title, $authors, $doi, 1.1 ) if ( $flag == 1 );

      # authors usually have a higher comma to word ratio than the title
      ( $title, $authors, $flag ) = _AuthorLine_by_Commas( $final_content[$candidate_Title],
        $final_content[$candidate_Authors] );
      return ( $title, $authors, $doi, 1.2 ) if ( $flag == 1 );

      # there could be just TWO authors
      ( $title, $authors, $flag ) = _AuthorLine_is_Two_Authors( $final_content[$candidate_Title],
        $final_content[$candidate_Authors] );
      return ( $title, $authors, $doi, 1.3 ) if ( $flag == 1 );

      # there could be just ONE authors
      ( $title, $authors, $flag ) = _AuthorLine_is_One_Author( $final_content[$candidate_Title],
        $final_content[$candidate_Authors] );
      return ( $title, $authors, $doi, 1.4 ) if ( $flag == 1 );

    }

    # they might be of same size, but then we do not take all rules
    if (  $final_fs[$candidate_Title] == $final_fs[$candidate_Authors]
      and $final_fs[$candidate_Title] > $major_fs ) {
      my $flag = 0;

      # authors have usually more superscripts than titles
      ( $title, $authors, $flag ) = _AuthorLine_by_Superscripts(
        $final_content[$candidate_Title],        $final_content[$candidate_Authors],
        $final_nrsuperscripts[$candidate_Title], $final_nrsuperscripts[$candidate_Authors]
      );
      return ( $title, $authors, $doi, 1.9 ) if ( $flag == 1 );

    }

    # the order might be changed, but then we do not take all rules
    if (  $final_fs[$candidate_Title] < $final_fs[$candidate_Authors]
      and $final_fs[$candidate_Authors] / $major_fs > 1.2 ) {
      my $swap = $candidate_Title;
      $candidate_Title   = $candidate_Authors;
      $candidate_Authors = $swap;

      my $flag = 0;

      # authors have usually more superscripts than titles
      ( $title, $authors, $flag ) = _AuthorLine_by_Superscripts(
        $final_content[$candidate_Title],        $final_content[$candidate_Authors],
        $final_nrsuperscripts[$candidate_Title], $final_nrsuperscripts[$candidate_Authors]
      );
      return ( $title, $authors, $doi, 1.5 ) if ( $flag == 1 );

      # authors usually have a higher comma to word ratio than the title
      ( $title, $authors, $flag ) = _AuthorLine_by_Commas( $final_content[$candidate_Title],
        $final_content[$candidate_Authors] );
      return ( $title, $authors, $doi, 1.6 ) if ( $flag == 1 );
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
  for my $i ( 0 .. $#final_content ) {

    #print "$final_bad[$i] $final_adress[$i] $final_fs[$i] $major_fs $final_content[$i]\n";
    if ( $final_bad[$i] == 0 and $final_adress[$i] == 0 and $final_fs[$i] >= $major_fs ) {
      push @IDS, $i;
      $k++;
      if ( $final_fs[$i] > $max_fs_NONEBAD ) {
        $max_fs_NONEBAD      = $final_fs[$i];
        $max_fs_line_NONEBAD = $k;
      }
    }

    if ( $final_fs[$i] > $max_fs_ALL ) {
      $max_fs_ALL      = $final_fs[$i];
      $max_fs_line_ALL = $i;
    }
  }

  # if we find just two lines, then this is a good sign
  if ( $#IDS == 1 ) {
    my $candidate_Authors = $IDS[1];
    my $candidate_Title   = $IDS[0];

    # if the candidate_Title is also very large
    # then this is a good sign
    if ( ( $final_fs[$max_fs_line_ALL] - $final_fs[$candidate_Title] ) / $major_fs < 0.2 ) {

      # the heading is normally B and has a greater fs than the authors
      if ( $final_fs[$candidate_Title] > $final_fs[$candidate_Authors] ) {
        my $flag = 0;

        # authors have usually more superscripts than titles
        ( $title, $authors, $flag ) = _AuthorLine_by_Superscripts(
          $final_content[$candidate_Title],        $final_content[$candidate_Authors],
          $final_nrsuperscripts[$candidate_Title], $final_nrsuperscripts[$candidate_Authors]
        );
        return ( $title, $authors, $doi, 2.1 ) if ( $flag == 1 );

        # authors usually have a higher comma to word ratio than the title
        ( $title, $authors, $flag ) = _AuthorLine_by_Commas( $final_content[$candidate_Title],
          $final_content[$candidate_Authors] );
        return ( $title, $authors, $doi, 2.2 ) if ( $flag == 1 );

        # there could be just TWO authors
        ( $title, $authors, $flag ) = _AuthorLine_is_Two_Authors( $final_content[$candidate_Title],
          $final_content[$candidate_Authors] );
        return ( $title, $authors, $doi, 2.3 ) if ( $flag == 1 );

        # there could be just ONE authors
        ( $title, $authors, $flag ) = _AuthorLine_is_One_Author( $final_content[$candidate_Title],
          $final_content[$candidate_Authors] );
        return ( $title, $authors, $doi, 2.4 ) if ( $flag == 1 );

        # if Title directly preceeds Authors and Title seems to be really hughe
        if (  $candidate_Title == $candidate_Authors - 1
          and $final_fs[$candidate_Title] / $major_fs > 1.3 ) {
          $authors = $final_content[$candidate_Authors];
          $title   = $final_content[$candidate_Title];
          return ( $title, $authors, $doi, 2.9 );
        }
      }

    }
  }

  # there are more than two lines left
  if ( $#IDS > 1 ) {
    my $candidate_Authors = $IDS[ $max_fs_line_NONEBAD + 1 ];
    my $candidate_Title   = $IDS[$max_fs_line_NONEBAD];

#print "$candidate_Title $candidate_Authors $final_content[$candidate_Title] $final_content[$candidate_Authors]\n";

    if ( ( $final_fs[$max_fs_line_ALL] - $final_fs[$candidate_Title] ) / $major_fs < 0.2 ) {

      # the heading is normally B and has a greater fs than the authors
      if ( $final_fs[$candidate_Title] > $final_fs[$candidate_Authors] ) {
        my $flag = 0;

        # authors have usually more superscripts than titles
        ( $title, $authors, $flag ) = _AuthorLine_by_Superscripts(
          $final_content[$candidate_Title],        $final_content[$candidate_Authors],
          $final_nrsuperscripts[$candidate_Title], $final_nrsuperscripts[$candidate_Authors]
        );
        return ( $title, $authors, $doi, 3.1 ) if ( $flag == 1 );

        # authors usually have a higher comma to word ratio than the title
        ( $title, $authors, $flag ) = _AuthorLine_by_Commas( $final_content[$candidate_Title],
          $final_content[$candidate_Authors] );
        return ( $title, $authors, $doi, 3.2 ) if ( $flag == 1 );

        # there could be just TWO authors
        ( $title, $authors, $flag ) = _AuthorLine_is_Two_Authors( $final_content[$candidate_Title],
          $final_content[$candidate_Authors] );
        return ( $title, $authors, $doi, 3.3 ) if ( $flag == 1 );

        # there could be just ONE authors
        ( $title, $authors, $flag ) = _AuthorLine_is_One_Author( $final_content[$candidate_Title],
          $final_content[$candidate_Authors] );
        return ( $title, $authors, $doi, 3.4 ) if ( $flag == 1 );

        # if Title directly preceeds Authors and Title seems to be really hughe
        if (  $candidate_Title == $candidate_Authors - 1
          and $final_fs[$candidate_Title] / $major_fs > 1.3 ) {
          $authors = $final_content[$candidate_Authors];
          $title   = $final_content[$candidate_Title];
          return ( $title, $authors, $doi, 3.9 );
        }
      }

    }

  }

  return ( $title, $authors, $doi, 4 );

}

1;
