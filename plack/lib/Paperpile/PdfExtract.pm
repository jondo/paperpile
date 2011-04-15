# Copyright 2009-2011 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public License for more details.  You should have
# received a copy of the GNU Affero General Public License along with
# Paperpile.  If not, see http://www.gnu.org/licenses.

package Paperpile::PdfExtract;

use Mouse;
use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Data::Dumper;
use Paperpile::Formats::XMP;

has 'file'     => ( is => 'rw', isa => 'Str' );
has 'pub'      => ( is => 'rw', isa => 'Paperpile::Library::Publication' );

sub parsePDF {

  my $self = shift;

  my $verbose = 0;

  my ( $title, $authors, $doi, $arxivid );

  # Read XMP data if present in PDF file
  my $xmp_parser = Paperpile::Formats::XMP->new();
  $xmp_parser->file( $self->file );
  my $xmp_pub = $xmp_parser->read();

  # immediate return if we get a more or less complete entry
  if ( $xmp_pub->title and $xmp_pub->authors and $xmp_pub->doi ) {
    return $xmp_pub;
  }

  # call extpdf
  my $arguments = {
    'command' => 'WORDLIST',
    'page'    => 0,
    'inFile'  => $self->file
  };
  my $output = Paperpile::Utils->extpdf($arguments);

  # extpdf output is grouped into lines and features
  # are calculated for each line
  my $metadata = _parse_extpdf_info( $output, $arguments );
  my ( $lines, $words_rotated ) = _parse_extpdf_output($output);

  # usually extpdf gives the lines in the order one would read it,
  # but there are some weird cases where it is totally wrong
  # we try to sort lines here
  $lines = _sort_lines( $lines, $metadata );

  # search for a DOI
  $doi = _search_for_DOI($lines);

  # search for an ArXiv ID
  $arxivid = _search_for_arXivid( $lines, $words_rotated );

  # check if it seems that this page is a cover page
  if ( _check_for_cover_page($lines) and $metadata->{numPages} > 1 ) {
    $arguments->{'page'} = 1;
    $output = Paperpile::Utils->extpdf($arguments);
    $metadata = _parse_extpdf_info( $output, $arguments );
    ( $lines, $words_rotated ) = _parse_extpdf_output($output);
    $lines = _sort_lines( $lines, $metadata );
    $doi = _search_for_DOI($lines) if ( !defined $doi );
    $arxivid = _search_for_arXivid( $lines, $words_rotated ) if ( !defined $arxivid );
  }

  if ( $verbose == 1 ) {
    print STDERR "******************* LINES *********************\n";
    foreach my $i ( 0 .. $#{$lines} ) {
      print "L$i: ", _sprintf_line_or_group( $lines->[$i] );
    }
  }

  # call text parser
  ( $title, $authors ) = _parse_text( $lines, $verbose );

  # if text parsing did not return values, we take
  # the metadata values if there are any
  $title   = $metadata->{title} if ( !$title   and $metadata->{title} );
  $doi     = $metadata->{doi}   if ( !$doi     and $metadata->{doi} );
  $arxivid = $metadata->{arxiv} if ( !$arxivid and $metadata->{arxivid} );

  $title   = $xmp_pub->title   if ( !$title   and $xmp_pub->title );
  $authors = $xmp_pub->authors if ( !$authors and $xmp_pub->authors );
  $doi     = $xmp_pub->doi     if ( !$doi     and $xmp_pub->doi );
  $arxivid = $xmp_pub->arxiv   if ( !$arxivid and $xmp_pub->arxivid );

  # We can now create the publication object and return it
  my $pub = Paperpile::Library::Publication->new( pubtype => 'MISC' );
  $pub->title($title)     if $title;
  $pub->authors($authors) if $authors;
  $pub->arxivid($arxivid) if $arxivid;
  $pub->doi($doi)         if $doi;

  return $pub;
}

sub _sort_lines {
  my $lines    = $_[0];
  my $metadata = $_[1];

  my @newlines = ();
  my %hash     = ();
  my ( $width, $height ) = split( /\s+/, $metadata->{size} );
  $hash{ $_->{xMin} }++ foreach @{$lines};

  my ( $onecolumn, $twocolumns )  = ( 1 , 0 );

  # for a two column layout, we split it
  foreach my $key ( sort { $a <=> $b } keys %hash ) {
    if ( $key > $width / 2 - 10 and $hash{$key} / $#{$lines} > 0.1 ) {
      $twocolumns = 1;
      $onecolumn  = 0;
    }
  }

  if ( $onecolumn == 1 ) {
    my @tmp = sort { $a->{yMin} <=> $b->{yMin} } @{$lines};
    $lines = \@tmp;
  }
  if ( $twocolumns == 1 ) {
    my @col1 = ();
    my @col2 = ();
    foreach my $line ( @{$lines} ) {
      if ( $line->{xMin} <= $width / 2 - 10 ) {
        push @col1, $line;
      } else {
        push @col2, $line;
      }
    }

    # now sort col1 and then append sorted col2
    @col1 = sort { $a->{yMin} <=> $b->{yMin} } @col1;
    @col2 = sort { $a->{yMin} <=> $b->{yMin} } @col2;
    $lines = [];
    push @{$lines}, $_ foreach @col1;
    push @{$lines}, $_ foreach @col2;
  }

  return $lines;
}


sub _parse_text {
  my $lines = $_[0];
  my $verbose = $_[1];

  my ( $title, $authors );

  my $most_abundant_fs = _most_abundant_fontsize($lines);

  ( $title, $authors ) = _parse_JSTOR( $lines );

  # group lines
  my $groups = _build_groups( $lines, $most_abundant_fs, $verbose );

  if ( $verbose == 1 ) {
    print STDERR "******************* GROUPS *********************\n";
    foreach my $i ( 0 .. $#{$groups} ) {
      #$groups->[$i]->{content} =~ s/([^[:ascii:]])/sprintf("&#%d;",ord($1))/eg;
      print STDERR "G$i: ", _sprintf_line_or_group( $groups->[$i] );
    }
  }

  if ( not defined $title and not defined $authors ) {
    ( $title, $authors ) = _strategy_one( $groups, $most_abundant_fs, $verbose );
  }
  if ( not defined $title and not defined $authors ) {
    ( $title, $authors ) = _strategy_two( $groups, $most_abundant_fs, $verbose );
  }

  if ( defined $title and defined $authors ) {
    $title =~ s/,\s*$//;
    $title =~ s/\.$//;
    $title =~ s/^(Research\sarticle)//i;
    $title =~ s/^(Short\sarticle)//i;
    $title =~ s/^(Report)//i;
    $title =~ s/^Articles?//i;
    $title =~ s/^(Review\s)//i;
    $title =~ s/^([A-Z]*\sMinireview)//i;
    $title =~ s/^SURVEY\sAND\sSUMMARY\s//i;
    $title =~ s/^(Letter:?)//i;
    $authors = _clean_and_format_authors($authors);
  }

  return ( $title, $authors );
}

sub _clean_and_format_authors {
  my $string = $_[0];

  $string =~ s/,+/ , /g;
  $string =~ s/,\s*$//;
  $string =~ s/\x{2019}//g;
  $string =~ s/\x{2018}//g;
  $string =~ s/\x{2C7}//g; # Hatschek
  $string =~ s/\x{A8}//g;
  $string =~ s/\d//g;
  $string =~ s/\$//g;
  $string =~ s/'//g;
  $string =~ s/\./. /g;
  $string =~ s/^\s*,//;
  $string =~ s/\sand,/ and /g;
  $string =~ s/,\sand\s/ and /g;
  $string =~ s/` //g;
  $string =~ s/\s?\x{B4}//g;
  $string =~ s/^(by\s)//gi;
  $string =~ s/\s+/ /g;

  my @tmp = ( );
  foreach my $i ( split( /(?:\sand\s|\s&\s|,)/i, $string ) ) {
    $i =~ s/(\s[^[:ascii:]]\s)//g;
    $i =~ s/\s+$//;
    $i =~ s/^\s+//;
    $i =~ s/-\s+/-/g;
    next if ( length($i) < 3 );
    if ( $i =~ m/^(\S+)\s(.\.)$/ ) {
      $i = "$2 $1";
    }
    if ( $i =~ m/^(\S+)\s(.\.\s.\.)$/ ) {
      $i = "$2 $1";
    }
    #$i =~ s/([^[:ascii:]])/sprintf("&#%d;",ord($1))/eg;
    #print "\t|$i|\n";
    push @tmp, Paperpile::Library::Author->new()->parse_freestyle($i)->bibtex();
  }


  return join( ' and ', @tmp );
}


# First, we search for an adress line. Usually authors are
# just above that line, and then comes the title
# This is the most promising strategy and gives confident
# results
sub _strategy_one {
  my $groups           = $_[0];
  my $most_abundant_fs = $_[1];
  my $verbose          = $_[2];

  my ( $title, $authors );

  my @adress_lines = ();
  my $fs_adress    = 0;
  foreach my $i ( 0 .. $#{$groups} ) {
    my $t = $groups->[$i]->{adress_count};
    $t += $groups->[$i]->{starts_with_superscript};
    if ( $t > 0 ) {
      push @adress_lines, $i;
      $fs_adress = $groups->[$i]->{fs};
    }
  }

  foreach my $j (@adress_lines) {

    # find the previous lines that do not have bad words
    my @n      = ();
    my $max_fs = 0;
    for ( my $i = $j - 1 ; $i >= 0 ; $i-- ) {
      next if ( length( $groups->[$i]->{content} ) < 2 );
      next if ( $groups->[$i]->{content} !~ m/\s/ );
      next if ( $groups->[$i]->{nr_words} >= 100 and
		$groups->[$i]->{nr_bad_author_words} > 1 );
      my $cur = $groups->[$i];
      my $tmp = $cur->{adress_count};
      $tmp += $cur->{nr_bad_words};
      if ( $tmp == 0 ) {
        $max_fs = $cur->{fs} if ( $cur->{fs} > $max_fs );

        # let's see if there is already an entry in @n
        # that has the same yMin coordinates
        # if so, we rather append then adding a new entry
        my $h = -1;
        foreach my $k ( 0 .. $#n ) {
          $h = $k if ( $n[$k]->{yMin} == $groups->[$i]->{yMin} );
        }
        if ( $h == -1 ) {
          push @n, _deep_copy($cur);
        } else {
          my $t = $cur->{content} . ' , ' . $n[$h]->{content};
          $n[$h]->{content} = $t;
        }
      }
    }

    next if ( $#n <= 0 );

    my ( $cand_au, $cand_ti ) = ( undef, undef );

    if ( $verbose == 1 ) {
      foreach my $i ( 0 .. $#n ) {
	print "S1|$i: ", _sprintf_line_or_group( $n[$i] );
      }
    }

    if ( $#n == 1 ) {
      ( $cand_ti, $cand_au ) =
	( $n[0]->{fs} > $n[1]->{fs} ) ? ( $n[0], $n[1] ) : ( $n[1], $n[0] );
    } else {

      # let's see if we remove lines with the same fontsize that
      # was observed for adress lines, only two lines are left then
      my @c = ();
      foreach my $i ( 0 .. $#n ) {
        push @c, $i if ( $n[$i]->{fs} != $fs_adress
          and $n[$i]->{fs} >= $most_abundant_fs );
      }
      if ( $#c == 1 ) {
        ( $cand_ti, $cand_au ) =
          ( $n[0]->{fs} > $n[1]->{fs} ) ? ( $n[0], $n[1] ) : ( $n[1], $n[0] );
      }
      print STDERR "Au/Ti selection 1 failed.\n" if ( ! $cand_ti and $verbose );

      # let's see if we remove lines with a smaller fontsize than
      # the most abundant fs, only two lines are left
      @c = ();
      foreach my $i ( 0 .. $#n ) {
        push @c, $i if ( $n[$i]->{fs} < $most_abundant_fs );
      }
      if ( $#c == 1 ) {
        ( $cand_ti, $cand_au ) =
          ( $n[0]->{fs} > $n[1]->{fs} ) ? ( $n[0], $n[1] ) : ( $n[1], $n[0] );
      }
      print STDERR "Au/Ti selection 2 failed.\n" if ( ! $cand_ti and $verbose );

      # if not successful so far, we search for the largest fs
      if ( not defined $cand_ti ) {
        @c = ();
        foreach my $i ( 0 .. $#n ) {
          push @c, $i if ( $n[$i]->{fs} == $max_fs );
        }
        if ( $#c == 0 ) {
          if ( $c[0] - 1 >= 0 ) {
            $cand_ti = $n[ $c[0] ];
            $cand_au = $n[ $c[0] - 1 ];
          }
        }
      }
      print STDERR "Au/Ti selection 3 failed.\n" if ( ! $cand_ti and $verbose );
    }

    next if ( not defined $cand_au or not defined $cand_ti );

    if ( $verbose == 1 ) {
      print STDERR "cand_ti:$cand_ti->{content}\ncand_au:$cand_au->{content}\n";
    }

    # font size of title is larger than that of the authors
    # and 1.2 times larger than the most abundant font size
    if (  $cand_ti->{fs} > $cand_au->{fs}
      and $cand_ti->{fs} / $most_abundant_fs >= 1.2 ) {
      ( $title, $authors, my $flag ) = _evaluate_pair( $cand_ti, $cand_au );
      return ( $title, $authors ) if ( $flag > 0 );
    }

    # authors and title have the same font size, but at least
    # both are larger than the most abundant font size
    if (  $cand_ti->{fs} == $cand_au->{fs}
      and $cand_ti->{fs} > $most_abundant_fs ) {
      ( $title, $authors, my $flag ) = _evaluate_pair( $cand_ti, $cand_au );
      return ( $title, $authors ) if ( $flag == 1 );

      # the title is bold, while authors are not
      if ( $cand_ti->{bold} == 1 and $cand_au->{bold} == 0 ) {
        ( $title, $authors, my $flag ) = _evaluate_pair( $cand_ti, $cand_au );
        return ( $title, $authors ) if ( $flag > 0 );
      }
    }
    if (  $cand_ti->{fs} == $cand_au->{fs}
      and $cand_au->{nr_bad_author_words} == 0 ) {
      ( $title, $authors, my $flag ) = _evaluate_pair( $cand_ti, $cand_au );
      return ( $title, $authors ) if ( $flag > 0 );
    }
  }

  return ( $title, $authors );

}

# Now we have a look at those lines that do not have "bad
# words" and see if there are some characteristics
sub _strategy_two {
  my $groups           = $_[0];
  my $most_abundant_fs = $_[1];
  my $verbose          = $_[2];

  my ( $title, $authors );

  my @n                  = ();
  my $line_with_max_font_size = -1;
  my $max_font_size           = 0;
  foreach my $i ( 0 .. $#{$groups} ) {
    next if ( length( $groups->[$i]->{content} ) < 2 );
    my $nr_letters = ( $groups->[$i]->{content} =~ tr/[A-Za-z]// );
    next if ( $nr_letters <= 3 );
    next if ( $groups->[$i]->{content} !~ m/\s/ );
    next if ( $groups->[$i]->{nr_words} >= 100 and
	      $groups->[$i]->{nr_bad_author_words} > 1 );
    my $cur = $groups->[$i];
    my $tmp = $cur->{adress_count};
    $tmp += $cur->{nr_bad_words};
    if ( $tmp == 0 ) {
      my $h = -1;
      foreach my $k ( 0 .. $#n ) {
        $h = $k if ( $n[$k]->{yMin} == $groups->[$i]->{yMin} );
      }
      if ( $h == -1 ) {
        push @n, _deep_copy($cur);
        if ( $n[$#n]->{fs} > $max_font_size ) {
          $max_font_size           = $n[$#n]->{fs};
          $line_with_max_font_size = $#n;
        }
      } else {
        my $t = $cur->{content} . ' , ' . $n[$h]->{content};
        $n[$h]->{content} = $t;
        if ( $n[$h]->{fs} > $max_font_size ) {
          $max_font_size           = $n[$h]->{fs};
          $line_with_max_font_size = $h;
        }
      }
    }
  }

  next if ( $#n <= 0 );

  if ( $verbose == 1 ) {
    foreach my $i ( 0 .. $#n ) {
      print "S2|$i: ", _sprintf_line_or_group( $n[$i] );
    }
  }

  my ( $cand_au, $cand_ti ) = ( undef, undef );

  if ( $#n == 1 ) {
    if ( $n[0]->{nr_bad_author_words} == 0 and
	 $n[0]->{fs} < $n[1]->{fs} ) {
      $cand_au = $n[0];
      $cand_ti = $n[1];
    } elsif ( $n[1]->{nr_bad_author_words} == 0 ) {
      $cand_au = $n[1];
      $cand_ti = $n[0];
    } else {
      return ( undef, undef );
    }

    if ( $verbose == 1 ) {
      print STDERR "cand_ti:$cand_ti->{content}\ncand_au:$cand_au->{content}\n";
    }

    if ( $cand_ti->{fs} > $cand_au->{fs} ) {
      ( $title, $authors, my $flag ) = _evaluate_pair( $cand_ti, $cand_au );
      return ( $title, $authors ) if ( $flag > 0 );
    }

    if ( $cand_ti->{fs} == $cand_au->{fs} ) {

      # at least the title is bold
      if ( $cand_ti->{bold} == 1 and $cand_au->{bold} == -1 ) {
        ( $title, $authors, my $flag ) = _evaluate_pair( $cand_ti, $cand_au );
        return ( $title, $authors ) if ( $flag > 0 );
      }

      # at least title is really larger than the rest
      if ( $cand_ti->{fs} / $most_abundant_fs > 1.3 ) {
        ( $title, $authors, my $flag ) = _evaluate_pair( $cand_ti, $cand_au );
        return ( $title, $authors ) if ( $flag > 0 );
      }
    }

  } else {

    return ( undef, undef ) if ( $line_with_max_font_size + 1 > $#n );
    if ( $n[ $line_with_max_font_size + 1 ]->{nr_bad_author_words} == 0 ) {
      $cand_au = $n[ $line_with_max_font_size + 1 ];
      $cand_ti = $n[$line_with_max_font_size];
    } else {
      return ( undef, undef );
    }

    if ( $verbose == 1 ) {
      print STDERR "cand_ti:$cand_ti->{content}\ncand_au:$cand_au->{content}\n";
    }

    if ( $cand_ti->{fs} > $cand_au->{fs} ) {
      ( $title, $authors, my $flag ) = _evaluate_pair( $cand_ti, $cand_au );
      return ( $title, $authors ) if ( $flag > 0 );
    }
    if ( $cand_ti->{fs} == $cand_au->{fs} ) {

      # at least the title is bold
      if ( $cand_ti->{bold} == 1 and $cand_au->{bold} == -1 ) {
        ( $title, $authors, my $flag ) = _evaluate_pair( $cand_ti, $cand_au );
        return ( $title, $authors ) if ( $flag > 0 );
      }

      # at least title is really larger than the rest
      if ( $cand_ti->{fs} / $most_abundant_fs > 1.3 ) {
        ( $title, $authors, my $flag ) = _evaluate_pair( $cand_ti, $cand_au );
        return ( $title, $authors ) if ( $flag > 0 );
      }
    }

  }

  return ( $title, $authors );

}

sub _evaluate_pair {
  my $cand_ti = $_[0];
  my $cand_au = $_[1];

  if ( $cand_au->{nr_superscripts} > $cand_ti->{nr_superscripts} ) {
    return ( $cand_ti->{content}, $cand_au->{content}, 1 );
  }

  my $commas_title   = ( $cand_ti->{content} =~ tr/,// );
  my $commas_authors = ( $cand_au->{content} =~ tr/,// );
  my $words_title    = ( $cand_ti->{content} =~ tr/ // );
  my $words_authors  = ( $cand_au->{content} =~ tr/ // );
  if ( $words_title > 0 and $words_authors > 0 ) {
    if ( $commas_authors / $words_authors > $commas_title / $words_title ) {
      return ( $cand_ti->{content}, $cand_au->{content}, 2 );
    }
  }

  my @temp_authors = split( /(?:\sand\s|\s&\s)/i, $cand_au->{content} );
  if ( $#temp_authors == 1 ) {
    my $spaces0 = ( $temp_authors[0] =~ tr/ // );
    my $spaces1 = ( $temp_authors[1] =~ tr/ // );
    if ( $spaces0 <= 3 and $spaces1 <= 3 ) {
      return ( $cand_ti->{content}, $cand_au->{content}, 3 );
    }
  }

  my $spaces = ( $cand_au->{content} =~ tr/ // );
  if ( $spaces <= 3 ) {
    return ( $cand_ti->{content}, $cand_au->{content}, 4 );
  }

  return ( undef, undef, 0 );
}


sub _build_groups {
  my $lines            = $_[0];
  my $most_abundant_fs = $_[1];

  my $y_abstract_or_intro  = _get_abstract_or_intro_pos($lines);
  my $last_line_was_a_join = 0;
  my $last_line_diff       = 0;
  my $last_line_lc         = 0;
  my @groups               = ();
  push @groups, new_line_or_group();

  foreach my $i ( 0 .. $#{$lines} ) {

    # skip the entry if we are past the Abstract or Introduction
    next if ( $lines->[$i]->{'yMin'} >= $y_abstract_or_intro );

    # consider only lines with a minimal length of 2 chars
    next if ( length( $lines->[$i]->{'content'} ) <= 1 );

    # current and previous lines
    my $pre_i = ( $i > 0 ) ? $i - 1 : 0;
    my $c   = $lines->[$i];
    my $p   = $lines->[$pre_i];

    # calculate some features for the current and previous line
    my $diff        = abs( $p->{yMin} - $c->{yMin} );
    my $same_fs     = ( $c->{fs} == $p->{fs} ) ? 1 : 0;
    my $same_bold   = ( $c->{bold} == $p->{bold} ) ? 1 : 0;
    my $same_italic = ( $c->{italic} == $p->{italic} ) ? 1 : 0;
    my $lc          = ( $c->{content} =~ tr/[a-z]// );
    my $uc          = ( $c->{content} =~ tr/[A-Z]// );
    $uc = 1 if ( $uc == 0 );    # pseudo-count

    my $same_diff = 1;
    if ( $last_line_was_a_join == 1 ) {
      $same_diff = 0 if ( $diff != $last_line_diff );
    }

    # if sng (start_new_group) is assigned a value of 1 or higher
    # than a new group is started
    my $sng = 1;

    $sng = 2 if ( $c->{nr_bad_words} > 0 );
    $sng = 0 if ( $same_fs == 1 and $same_bold == 1 and $same_italic == 1 );
    $sng = 0 if ( $same_fs == 1 and $same_bold == 1 );
    $sng = 3 if ( $c->{starts_with_superscript} == 1 );
    $sng = 4 if ( $c->{adress_count} >= 1 );

    # sometimes titles span two lines and have a foot note
    # we only start a new line if we see more than two superscripts
    # and the previous line did not have one
    $sng = 5 if ( $c->{nr_superscripts} > 1 and $p->{nr_superscripts} == 0 );
    $sng = 8 if ( $c->{content} =~ m/^\d+$/ );
    $sng = 9 if ( $p->{content} =~ m/Volume\s\d+/
      and $c->{nr_bad_words} == 0 );

    # difference to previous line is really hughe
    $sng = 10 if ( $diff > 50 );
    $sng = 11 if ( $diff > ( $c->{fs} + $p->{fs} ) * 1.5 );

    if ( $sng == 0 ) {
      $sng = 7 if ( $c->{nr_bad_words} > 0 and $p->{nr_bad_words} == 0 );
    }

    #print STDERR "$sng --> $c->{content}\n";

    if ( $sng >= 1 ) {
      push @groups, new_line_or_group();
      update_line_or_group( $c, $groups[$#groups] );

    } else {
      update_line_or_group( $c, $groups[$#groups] );
    }
  }

  foreach my $group (@groups) {
    calculate_line_features($group);
  }

  return \@groups;
}


sub _MarkBadWords {
  my $tmp_line = $_[0];
  my $bad      = 0;

  $bad++ if ( $tmp_line =~ m/^\(.+\)$/ );

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
    'letters?to',                      'BRIEFCOMMUNICATIONS'
  );
  foreach my $type (@badTypes) {
    $bad++ if ( $tmp_line =~ m/$type/i );
  }

  # years and numbers
  my @badNumbers = (
    '2(1|2|3|4|5|6|7|8|9)\d\d', '20\d\d',
    '1(0|1|2|3|4|5|6|7|8)\d\d', '\d{5,}',

    '(3|4|5|6|7|8|9)\d\d\d', '19\d\d',
    '\d\d\/\d\d\/\d\d',      '\d\d+-\d\d+',
    '\[\d+-\d+\]', '\[\d+\]', '^\d+$',
    '(January|February|March|April|May|June|July|August|September|October|November|December)\s*\d+\s*,\s*\d{4}'
  );

  foreach my $number (@badNumbers) {
    $bad++ if ( $tmp_line =~ m/$number/i );
  }

  # words that are not supposed to appear in title or authors
  my @badWords = (
    'doi',           'vol\.\d+',               'keywords',        'openaccess$',
    'ScienceDirect', 'Blackwell',              'journalhomepage', 'e-?mail',
    'journal',       'ISSN',                   'http:\/\/',       '\.html',
    'Copyright',     'BioMedCentral',          'BMC',             'corresponding',
    'author',        'Abbreviations',          '@',               'Hindawi',
    'Pages\d+',      '\.{5,}',                 '^\*',             'NucleicAcidsResearch',
    'Printedin',     'Receivedforpublication', 'Received:',       'Accepted:',
    'Tel:',          'Fax:', 'VOLUME\d+'
  );

  foreach my $word (@badWords) {
    $bad++ if ( $tmp_line =~ m/$word/i );
  }

  return $bad;
}

sub _Bad_Author_Words {
  my $line = $_[0];

  my $flag = 0;

  my @badWords = (
    'this',  'that',     'here',  'where', 'study',     'about',
    'what',  'which',    'from',  'are',   'some',      'few',
    'there', 'above',    'below', 'under', 'Fig\.\s\d', 'false',
    'value', 'negative', 'positive'
  );
  foreach my $word (@badWords) {
    $flag++ if ( $line =~ m/(\s|\.|,)$word(\s|\.|,)/i );
  }

  return $flag;
}

sub _get_abstract_or_intro_pos {
  my $lines = $_[0];

  my ( $y_a, $y_i )  = ( 10000, 10000 );

  foreach my $i ( 0 .. $#{$lines} ) {
    my $t = $lines->[$i]->{'condensed_content'};
    my $y = $lines->[$i]->{'yMin'};

    $y_a = $y if ( $t =~ m/Abstract$/i );
    $y_a = $y if ( $t =~ m/^Abstract/i );
    $y_i = $y if ( $t =~ m/^(\d\.?)?Introduction$/i and $y < $y_i );
    $y_i = $y if ( $t =~ m/^(\d\.?)?Results$/i and $y < $y_i );
    $y_i = $y if ( $t =~ m/^(\d\.?)?Background$/i and $y < $y_i );
    $y_i = $y if ( $t =~ m/^Background:/i and $y < $y_i );
    $y_i = $y if ( $t =~ m/^(\d\.?)?Methods$/i and $y < $y_i and $y > 100 );
    $y_i = $y if ( $t =~ m/^(\d\.?)?MaterialsandMethods$/i and $y < $y_i and $y > 100 );
    $y_i = $y if ( $t =~ m/^(\d\.?)?Summary$/i and $y < $y_i );
    $y_i = $y if ( $t =~ m/^Addresses$/i and $y < $y_i );
    $y_i = $y if ( $t =~ m/^KEYWORDS:/i and $y < $y_i );
    $y_i = $y if ( $t =~ m/^SUMMARY/i and $y < $y_i );
    $y_i = $y if ( $t =~ m/^SYNOPSIS$/i and $y < $y_i );
  }

  return ( $y_a < $y_i ) ? $y_a : $y_i;
}


sub _most_abundant_fontsize {
  my $lines = $_[0];

  # determine most abundant fontsize
  my %tmp = ();
  $tmp{ $_->{fs} }++ foreach @{$lines};

  my ( $most_abundant_fs, $max ) = ( 0, 0 );

  for my $fs ( keys %tmp ) {
    if ( $tmp{$fs} > $max ) {
      $most_abundant_fs = $fs;
      $max              = $tmp{$fs};
    }
  }

  return $most_abundant_fs;
}


sub _check_for_cover_page {
  my $lines = $_[0];

  # some publishers like 'Cold Spring Harbor Laboratory Press' or
  # 'Oxford Journals' have a kind of cover page.

  my @phrases = (
    'top right corner of the article',
    'This article cites \d+ articles',
    'rsbl\.royalsocietypublishing\.org',
    'PLEASE SCROLL DOWN FOR ARTICLE/',
    'Reprints of this article can be ordered at',
    '\d+ article\(s\) on the ISI Web of Science',
    'Receive free email alerts when new articles cite this article',
    'Please scroll down to see the full text article',
    'This Provisional PDF corresponds to the article as it appeared',
    'This reprint is provided for personal and noncommercial use'
  );

  foreach my $i ( 0 .. $#{$lines} ) {
    foreach my $phrase (@phrases) {
      return 1 if ( $lines->[$i]->{'content'} =~ m/$phrase/i );
    }
  }

  return 0;
}

sub _parse_extpdf_info {
  my $output    = $_[0];
  my $arguments = $_[1];

  my %md = (
    'title'    => undef,
    'authors'  => undef,
    'doi'      => undef,
    'arxivid'  => undef,
    'numPages' => 1,
    'size'     => undef
  );

  return \%md if ( not defined $output->{'info'} );
  my $tmp = $output->{'info'};

  if (  $tmp->{'page'} =~ m/^ARRAY/ ) {
    if ( defined $tmp->{'page'}->[ $arguments->{page} ]->{'size'} ) {
      $md{size} = $tmp->{'page'}->[ $arguments->{page} ]->{'size'};
    }
  } elsif ( $tmp->{'page'} =~ m/^HASH/ ) {
     $md{size} = $tmp->{'page'}->{'size'};
  }

  $md{numPages} = $tmp->{'numPages'} if ( defined $tmp->{'numPages'} );

  if ( defined $tmp->{'Title'} ) {
    $md{title} = $tmp->{'Title'};

    if ( $md{title} =~ m/^doi:(10\.\d{4}\S+)/ ) {
      $md{doi}   = $1;
      $md{title} = '';
    }
    if ( $md{title} =~ m/^(10\.\d{4}\S+)/ ) {
      $md{doi}   = $1;
      $md{title} = '';
    }
    if ( $md{title} =~ m/^arXiv:\s?(\S+)/i ) {
      $md{arxivid} = $1;
      $md{title}   = '';
    }

    my $flag = 1;
    $flag = 0 if ( $md{title} =~ m/(\.doc|\.tex|\.dvi|\.e?ps|\.pdf)/ );
    $flag = 0 if ( $md{title} =~ m/(\.rtf|\.qxd|\.fm)$/ );
    $flag = 0 if ( $md{title} =~ m/^\s*$/ );
    $flag = 0 if ( $md{title} =~ m/^Microsoft/ );
    $flag = 0 if ( $md{title} =~ m/^gk[a-z]\d+/i );
    $flag = 0 if ( $md{title} =~ m/\d/ and $md{title} !~ m/\s/ );
    $flag = 0 if ( $md{title} =~ m/^PII:/ );
    $flag = 0 if ( $md{title} =~ m/^\d+\s/ );
    $flag = 0 if ( $md{title} =~ m/\d+\s*\.+\s*\d+$/ );
    $flag = 0 if ( $md{title} =~ m/Vol\.?\s\d+/i );
    $md{title} = '' if ( $flag == 0 );
    $md{title} =~ s/\s+/ /g;
    $md{title} =~ s/^\s+//g;
    $md{title} =~ s/\s+$//g;
    my $count_spaces = ( $md{title} =~ tr/ // );
    $md{title} = undef if ( $count_spaces < 3 );
  }
  if ( $tmp->{'Author'} ) {

  }

  return \%md;
}


sub _parse_extpdf_output {
  my $output = $_[0];

  return ([],[]) if ( not defined $output->{'word'} );

  my @words = @{ $output->{'word'} };

  return ([],[]) if ( $#words <= 1 );

  foreach my $i ( 0 .. $#words ) {
    ( my $xMin, my $yMin, my $xMax, my $yMax ) = split( /\s+/, $words[$i]->{'bbox'} );
    $words[$i]->{xMin} = sprintf( "%.0f", $xMin );
    $words[$i]->{yMin} = sprintf( "%.0f", $yMin );
    $words[$i]->{xMax} = sprintf( "%.0f", $xMax );
    $words[$i]->{yMax} = $words[$i]->{yMin} + $words[$i]->{size};
  }

  # in a first step we want to group words into lines
  my @lines = ();
  my @words_rotated = ( );
  # kick-off lines with the first non-rotated word
  my $start = 0;
  foreach my $i ( 0 .. $#words ) {
    if ( $words[$i]->{'rotation'} ) {
      push @words_rotated, $words[$i];
      next;
    } else {
      push @lines, new_line_or_group();
      update_line_or_group( $words[$i], $lines[$#lines] );
      $start = $i+1;
      last;
    }
  }

  foreach my $i ( $start .. $#words ) {

    # let's have a look if we should append to the last entry.
    # @lines stores the yMin and yMax values that have
    # the broadest span; if a word has its yMin or yMax values
    # within that span it will be added to the current line
    # bounding box usually seems to be greater than the font size
    # if bounding boxes overlap, a new line is only started if
    # less than 25% of the word are covered by the last bounding box

    my $inrange = 0;
    my $span_i  = $words[$i]->{'yMax'} - $words[$i]->{'yMin'};
    if ( $words[$i]->{'rotation'} ) {
      push @words_rotated, $words[$i];
      next;
    }

    if (  $lines[$#lines]->{'yMin'} <= $words[$i]->{'yMin'}
      and $words[$i]->{'yMax'} <= $lines[$#lines]->{'yMax'} ) {
      $inrange = 1;
    } elsif ( $lines[$#lines]->{'yMin'} <= $words[$i]->{'yMax'}
      and $words[$i]->{'yMax'} <= $lines[$#lines]->{'yMax'} ) {
      my $span = $words[$i]->{'yMax'} - $lines[$#lines]->{'yMin'};
      $inrange = 1 if ( $span / $span_i > 0.25 );
    } elsif ( $lines[$#lines]->{'yMin'} <= $words[$i]->{'yMin'}
      and $words[$i]->{'yMin'} <= $lines[$#lines]->{'yMax'} ) {
      my $span = $lines[$#lines]->{'yMax'} - $words[$i]->{'yMin'};
      $inrange = 1 if ( $span / $span_i > 0.25 );
    }

    push @lines, new_line_or_group() if ( $inrange == 0 );
    update_line_or_group( $words[$i], $lines[$#lines] );
  }

  my @filtered_lines = ( );
  foreach my $line (@lines) {
    calculate_line_features($line,1);
    push @filtered_lines, $line if ( $line->{fs} > 3 );
  }

  return ( \@filtered_lines, \@words_rotated);
}

sub _search_for_arXivid {
  my $lines = $_[0];
  my $words_rotated = $_[1];
  
  my $arxivid;
  foreach my $i ( 0 .. $#{$lines} ) {
    if (  $lines->[$i]->{'content'} =~ m/arxiv:\s?(\S+)/i ) {
      $arxivid = $1;
    }
  }
  foreach my $i ( 0 .. $#{$words_rotated} ) {
    if (  $words_rotated->[$i]->{'content'} =~ m/arxiv:\s?(\S+)/i ) {
      $arxivid = $1;
    }
  }

  return $arxivid;
}

sub _search_for_DOI {
  my $lines = $_[0];

  my $doi = '';
  foreach my $i ( 0 .. $#{$lines} ) {
    my $tmp = $lines->[$i]->{'content'};
    if ( $tmp =~ m/(10\.\d{4})/i ) {
      $doi = _ParseDOI($tmp);
    }
    # the DOI may be split into two lines
    if ( $doi eq '' and $i < $#{$lines} ) {
      $tmp = $lines->[$i]->{'content'}.$lines->[$i+1]->{'content'};
      $doi = _ParseDOI($tmp);
    }
    # if the DOI seems to be too short
    if ( $doi ne '' and length($doi) <= 10 ) {
      if ( $tmp =~ m/($doi)\s+(\S+)/i ) {
	$doi = _ParseDOI($1.$2);
      }
    }

    last if ( $doi ne '' and length($doi) > 10 );
  }

  $doi = undef if ( $doi eq '' );

  return $doi;
}

sub _ParseDOI {
  my $line = $_[0];
  my $doi  = $line;

  # there might be a strange minus sign (unicode &#8211; --> \x{2013}
  $doi =~ s/\s\x{2013}\s/-/g;

  if ( $doi =~ m/\D?(10\.\d{4})/ ) {
    $doi =~ s/(.*)(10\.\d{4})(\/?\s*)(\S+)(.*)/$2\/$4/;
    $doi =~ s/\(*\)*//g;
  } else {
    $doi = '';
  }

  # clean DOI
  $doi =~ s/,//g;
  $doi =~ s/\.$//;
  $doi =~ s/;$//;
  $doi =~ s/\x{35E}//g;
  $doi =~ s/\x{354}//g;

  # check for minimal length
  if ( $doi =~ m/(10\.\d{4}\/)(.*)/ ) {
    $doi = '' if ( length($2) < 5 );
  }

  #$doi =~ s/([^[:ascii:]])/sprintf("&#%d;",ord($1))/eg;

  return $doi;
}

sub calculate_line_features {
  my $in = $_[0];
  my $sort_flag = ( defined $_[1] ) ? $_[1] : 0;

  if ( $sort_flag == 1 ) {
    my @tmpa = sort { $a->{xMin} <=> $b->{xMin} } @{ $in->{'words'} };
    $in->{'words'} = \@tmpa;
  }

  foreach my $word ( @{ $in->{'words'} } ) {
    $in->{'bold_count'}++   if ( $word->{'bold'} );
    $in->{'italic_count'}++ if ( $word->{'italic'} );
    $in->{'fs_freqs'}->{ $word->{'size'} }++;
    $in->{'nr_words'}++;
    $in->{'xMin'} = $word->{'xMin'} if ( $word->{'xMin'} < $in->{'xMin'} );
  }

  # determine the major font size for the line
  for my $key ( keys %{ $in->{fs_freqs} } ) {
    $in->{'fs'} = $key if ( $in->{fs_freqs}->{$key} / $in->{nr_words} > 0.5 );
  }

  # if we have not set a font size for the line yet,
  # we take the largest one
  if ( not defined $in->{'fs'} ) {
    $in->{'fs'} = 0;
    for my $key ( keys %{ $in->{fs_freqs} } ) {
      $in->{'fs'} = $key if ( $key > $in->{'fs'} );
    }
  }

  if ( $in->{nr_words} > 0 ) {
    $in->{bold}   = 1 if ( $in->{bold_count} / $in->{nr_words} >= 0.5 );
    $in->{italic} = 1 if ( $in->{italic_count} / $in->{nr_words} >= 0.9 );
  }

  # parse for superscripts
  my $i = -1;
  foreach my $word ( @{ $in->{'words'} } ) {
    $i++;
    if ( $word->{'size'} < $in->{'fs'} ) {

      # do not make SMALL CAPS superscripts
      next if ( $word->{content} =~ m/^[A-Z]+$/ );
      next if ( $word->{content} =~ m/^10\.\d{4}/ );
      next if ( length($word->{content}) > 10 );
      $word->{'content'} = ',';
      $in->{'nr_superscripts'}++;
      $in->{'starts_with_superscript'} = 1 if ( $i == 0 );
      next;
    }

    # screen for special chars that mark authors
    my $special_chars = "\x{A0}|\x{A7}|\x{204E}|\x{2021}|";
    $special_chars .= "\x{2020}|\x{B9}|\x{B2}|\\*";
    while ( $word->{'content'} =~ m/(.*)($special_chars)(.*)/ ) {
      $word->{'content'} = $1 . ',' . $3;
      $in->{'nr_superscripts'}++;
      $in->{'starts_with_superscript'} = 1 if ( $i == 0 );
    }
  }

  # build the line content
  my @content = ();

  foreach my $i ( 0 .. $#{ $in->{'words'} } ) {

    # if words are in the same line, but separated by
    # a hughe region, we addd a comma
    my $c = $in->{'words'}->[$i];
    if ( $i > 0 ) {
      my $d = $c->{xMin} - $in->{'words'}->[ $i - 1 ]->{xMax};

      #print "$c->{'content'} $d\n";
      $c->{'content'} = ', ' . $c->{'content'} if ( $d > 20 );
    }

    # do not add e-mail adresses
    next if ( $c->{'content'} =~ m/\S+@\S+/ );
    push @content, $c->{'content'};
  }

  $in->{'content'} = join( " ", @content );

  # clean content
  if ( $in->{'content'} =~ m/(.{10,})(\s[\.\-_]{5,}.*)/ ) {
     $in->{'content'} = $1;
  }

  # repair common OCR errors and other stuff
  my %OCRerrors = (
    '\x{FB00}' => 'ff',
    '\x{FB01}' => 'fi',
    '\x{2013}' => '-',
    '\x{2032}' => "'",
    '\x{A8} o' => "\x{F6}",
    '\x{A8} a' => "\x{E4}",
    '\x{A8} u' => "\x{FC}",
    'o \x{A8}' => "\x{F6}",
    'a \x{A8}' => "\x{E4}",
    'u \x{A8}' => "\x{FC}",
    '\x{C6}'   => ',',
    '\x{B7}'   => ',',
    '\x{B4}'   => ','
  );
  while ( my ( $key, $value ) = each(%OCRerrors) ) {
    $in->{'content'} =~ s/$key/$value/g;
  }

  # some cleaning
  $in->{'content'} =~ s/\s+,/,/g;
  $in->{'content'} =~ s/,+/,/g;
  $in->{'condensed_content'} = $in->{'content'};
  $in->{'condensed_content'} =~ s/\s+//g;

  # screen for adress words
  my @adressWords = (
    'Universi[t|d]',          'College',
    'school',                 'D[aeiou]part[aeiou]?ment',
    'Dept\.',                 'Institut',
    'Lehrstuhl',              'Chair\sfor',
    'Faculty',                'Facultad',
    'Center',                 'Centre',
    'Laboratory',             'Laboratoirede',
    'division\sof',           'Science\sDivision',
    'Research\sOrganisation', 'section\sof',
    'address',                'P\.?O\.?Box',
    'General\sHospital',      'Hospital\sof',
    'Polytechnique',          'Molecular\sStructure\sSection',
    'Ltd\.',                  'U\.S\.A\.'
  );

  foreach my $word (@adressWords) {
    $in->{'adress_count'}++ if ( $in->{'content'} =~ m/$word/i );
  }

  # count bad words
  $in->{'nr_bad_words'}        = _MarkBadWords( $in->{'condensed_content'} );
  $in->{'nr_bad_author_words'} = _Bad_Author_Words( $in->{'content'} );
}

sub update_line_or_group {
  my $in      = $_[0];
  my $hashref = $_[1];

  # check if we add a word or a line
  if ( defined $in->{condensed_content} ) {

    # take each word and add it
    foreach my $word ( @{ $in->{words} } ) {
      push @{ $hashref->{'words'} }, $word;
    }

    # update yMax and yMin
    my $span_w = $in->{'yMax'} - $in->{'yMin'};
    my $span_l = $hashref->{'yMax'} - $hashref->{'yMin'};
    if ( $span_w > $span_l ) {
      $hashref->{'yMax'} = $in->{'yMax'};
      $hashref->{'yMin'} = $in->{'yMin'};
    }
  } else {
    return if ( not defined $in->{'content'} );
    return if ( $in->{content} =~ m/^\x{A8}$/ );
    return if ( $in->{content} =~ m/^\x{B4}$/ );

    my $span_w = $in->{'yMax'} - $in->{'yMin'};
    my $span_l = $hashref->{'yMax'} - $hashref->{'yMin'};
    if ( $span_w > $span_l ) {
      $hashref->{'yMax'} = $in->{'yMax'};
      $hashref->{'yMin'} = $in->{'yMin'};
    }

    # no further checks required if it is the first one
    if ( $#{ $hashref->{'words'} } == -1 ) {
      push @{ $hashref->{'words'} }, $in;
      return;
    }

    # append instead of add, if very close by
    my $lastone = $hashref->{'words'}->[ $#{ $hashref->{'words'} } ];
    my $d       = abs( $in->{xMin} - $lastone->{xMax} );
    if (  $d <= 1
      and $lastone->{size} == $in->{size} ) {
      $lastone->{xMax} = $in->{xMax};
      $lastone->{content} .= $in->{content};
      return;
    }

    # append if we see small caps
    if (  $d == 0
      and $lastone->{content} !~ m/^[a-z]$/
      and $in->{content} !~ m/^[a-z]+$/ ) {
      if ( $in->{content} =~ m/[A-Z]/ ) {
	$lastone->{xMax} = $in->{xMax};
	$lastone->{content} .= $in->{content};
	return;
      }
    }

    # we often see problems with umlaute
    # they are often encoded by two chars at the same position
    # we only add a word if it does not overlap
    # with any other word seen so far
    my $flag = 1;
    foreach my $other ( @{ $hashref->{'words'} } ) {

      if ( $other->{xMin} < $in->{xMin} and $in->{xMin} < $other->{xMax} ) {
        $flag = 0;
        last;
      }
      if ( $other->{xMin} < $in->{xMax} and $in->{xMax} < $other->{xMax} ) {
        $flag = 0;
        last;
      }
    }
    $flag = 1 if ( $in->{'content'} =~ m/10\.\d{4}/ );

    push @{ $hashref->{'words'} }, $in if ( $flag == 1 );
  }

  return;
}

sub new_line_or_group {

  my $hashref = {
    'words'                   => [],
    'nr_words'                => 0,
    'yMin'                    => 0,
    'yMax'                    => 0,
    'xMin'                    => 10e6,
    'fs_freqs'                => {},
    'bold_count'              => 0,
    'italic_count'            => 0,
    'bold'                    => 0,
    'italic'                  => 0,
    'nr_superscripts'         => 0,
    'starts_with_superscript' => 0,
    'fs'                      => undef,
    'content'                 => '',
    'condensed_content'       => '',
    'adress_count'            => 0,
    'nr_bad_words'            => 0,
    'nr_bad_author_words'     => 0
  };

  return $hashref;
}

# some helper functions
sub _deep_copy {
  my $in  = $_[0];
  my $out = new_line_or_group();

  foreach my $key ( keys %{$in} ) {
    if ( $key eq 'words' ) {
      foreach my $entry ( @{ $in->{$key} } ) {
        my $new_word = {};
        foreach my $key2 ( keys %{$entry} ) {
          $new_word->{$key2} = $entry->{$key2};
        }
        push @{ $out->{$key} }, $new_word;
      }
    } elsif ( $key eq 'fs_freqs' ) {
      foreach my $key2 ( %{ $in->{$key} } ) {
        $out->{$key}->{key2} = $in->{$key}->{key2};
      }
    } else {
      $out->{$key} = $in->{$key};
    }
  }

  return $out;
}

sub _sprintf_line_or_group {
  my $in = $_[0];

  my $s = "yMin:$in->{yMin} ";
  $s .= "fs:$in->{fs} ";
  $s .= "bad:$in->{nr_bad_words} ";
  $s .= "bold:$in->{bold} ";
  $s .= "sup:$in->{nr_superscripts}\n";
  $s .= "\t$in->{content}\n";

  return $s;
}


# Specific parsing routines for some journals

sub _parse_JSTOR {
  my $lines   = $_[0];
  my $verbose = $_[1];

  my $flag = 0;
  foreach my $line ( @{$lines} ) {
    $flag = 1 if ( $line->{content} =~ m/Your use of the JSTOR archive/ );
  }

  return ( undef, undef ) if ( $flag == 0 );

  my ( $title, $authors );

  return ( $title, $authors );
}

sub _parse_NPG {
  my $lines   = $_[0];
  my $verbose = $_[1];

  my $flag = 0;
  foreach my $line ( @{$lines} ) {
    $flag = 1 if ( $line->{content} =~ m/Your use of the JSTOR archive/ );
  }

  return ( undef, undef ) if ( $flag == 0 );

  my ( $title, $authors );

  return ( $title, $authors );
}

sub _parse_ScienceMag {
  my $lines   = $_[0];
  my $verbose = $_[1];

  my $flag = 0;
  foreach my $line ( @{$lines} ) {
    $flag = 1 if ( $line->{content} =~ m/Your use of the JSTOR archive/ );
  }

  return ( undef, undef ) if ( $flag == 0 );

  my ( $title, $authors );

  return ( $title, $authors );
}


1;
