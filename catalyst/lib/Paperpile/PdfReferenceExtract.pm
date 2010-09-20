package Paperpile::PdfReferenceExtract;

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
  system("$PDF2XML -noImage -q $PDFfile $tmpfile 2>/dev/null");
  if ( !-e $tmpfile ) {
    NetError->throw( error => 'PDF to XML conversion failed.' ) if ( $debug == 0 );
    return;
  }

  my (
    $output_ref,   $x_coords_ref, $y_coords_ref,
    $fontsize_ref, $pages_nr_ref, $flag_reference_heading,
    $counter_hash, $nr_pages,     $x_ends_ref
  ) = _parseXML($tmpfile);

  # remove temp file
  unlink("$tmpfile");

  return undef if ( !$output_ref );

  my $reference_strings = _parse_refereces(
    $output_ref,   $x_coords_ref, $y_coords_ref,
    $fontsize_ref, $pages_nr_ref, $flag_reference_heading,
    $counter_hash, $nr_pages,     $x_ends_ref
  );

  return $reference_strings;
}

sub _parse_refereces {
  my $output_ref             = $_[0];
  my $x_coords_ref           = $_[1];
  my $y_coords_ref           = $_[2];
  my $fontsize_ref           = $_[3];
  my $pages_nr_ref           = $_[4];
  my $flag_reference_heading = $_[5];
  my $counter_hash           = $_[6];
  my $nr_pages               = $_[7];
  my $x_ends_ref             = $_[8];

  ( my $split_by_numbers_forward, my $split_by_numbers_backward, my $max_split_by_numbers ) =
    _split_by_numbers_counting($output_ref);
  ( my $split_by_braces ) = _split_by_braces_counting($output_ref);
  ( my $count_indention, my $x_start_pos ) =
    _split_by_indention_counting( $output_ref, $x_coords_ref, $y_coords_ref );
  ( my $split_spacing_min, my $split_spacing_max, my $split_spacing_counts ) =
    _split_by_yspacing_counting( $output_ref, $x_coords_ref, $y_coords_ref );

  #print STDERR "split_by_numbers: $split_by_numbers_forward/$split_by_numbers_backward\n";
  #print STDERR "count_braces $split_by_braces\n";
  #print STDERR "count_indention $count_indention\n";
  #print STDERR "split_spacing_counts $split_spacing_counts\n";

  if ( $split_by_braces > $max_split_by_numbers ) {
    my $tmp = _split_by_braces( $output_ref );
    return $tmp if ( $#{$tmp} > -1 );
  }

  if ( $flag_reference_heading == 1 ) {
    if ( $max_split_by_numbers > 2 and $count_indention < $max_split_by_numbers ) {
      my $tmp = _split_by_numbers( $output_ref, $split_by_numbers_forward, $split_by_numbers_backward,
				   $max_split_by_numbers, $counter_hash, $nr_pages, $x_coords_ref, $y_coords_ref );
      return $tmp if ( $#{$tmp} > -1 );
    } elsif ( $max_split_by_numbers > 5 and $max_split_by_numbers > $count_indention * 0.25  ) {
      my $tmp = _split_by_numbers( $output_ref, $split_by_numbers_forward, $split_by_numbers_backward,
				   $max_split_by_numbers, $counter_hash, $nr_pages, $x_coords_ref, $y_coords_ref );
      return $tmp if ( $#{$tmp} > -1 );
    }
  } else {
    if ( $max_split_by_numbers > 2 ) {
      my $tmp = _split_by_numbers( $output_ref, $split_by_numbers_forward, $split_by_numbers_backward,
				   $max_split_by_numbers, $counter_hash, $nr_pages, $x_coords_ref, $y_coords_ref );
      return $tmp if ( $#{$tmp} > -1 );
    }
  }

  my $doit = ( $count_indention <= 5 and $split_spacing_counts > 5 ) ? 0 : 1;

  if ( $count_indention > 2 and $flag_reference_heading == 1 and $doit == 1 ) {
    my $tmp = _split_by_indention( $output_ref, $x_coords_ref, $x_start_pos, $y_coords_ref );
    return $tmp if ( $#{$tmp} > -1 );
  } elsif ( $count_indention > 5 ) {
    my $tmp = _split_by_indention( $output_ref, $x_coords_ref, $x_start_pos, $y_coords_ref );
    return $tmp if ( $#{$tmp} > -1 );
  }

  if ( $flag_reference_heading == 1 ) {
    my $tmp =
      _split_by_yspacing( $output_ref, $y_coords_ref, $split_spacing_min, $split_spacing_max, $x_ends_ref );
    return $tmp if ( $#{$tmp} > -1 );
  }

  return [];
}


sub stop_words {
  my $line = $_[0];

  my $flag = 0;
  $flag = 1 if ( $line =~ m/^http:\/\// );
  $flag = 1 if ( $line =~ m/Received\s\d+\s[A-Z]+\s\d{4}/i );
  $flag = 1 if ( $line =~ m/Accepted\s\d+\s[A-Z]+\s\d{4}/i );
  $flag = 1 if ( $line =~ m/^Edited\sby\s[A-Z]/ );
  $flag = 1 if ( $line =~ m/^Web\ssite\sreferences/ );
  $flag = 1 if ( $line =~ m/^Appendix/i );
  $flag = 1 if ( $line =~ m/^Acknowledgements/ );

  return $flag;
}

sub _parseXML {
  my $file = $_[0];

  my $xml = new XML::Simple;
  my $data = $xml->XMLin( $file, ForceArray => 1 );

  my $nr_pages = $#{ $data->{PAGE} } + 1;

  return undef if ( $nr_pages == 0 );

  my @output       = ();
  my @x_coords     = ();
  my @y_coords     = ();
  my @fontsize     = ();
  my @pages_nr     = ();
  my @x_ends       = ();
  my $flag         = 0;
  my $ref_x        = 0;
  my $ref_y        = 0;
  my %counter_hash = ();

  for ( my $page = $nr_pages - 1 ; $page >= 0 ; $page-- ) {
    my @lines = @{ $data->{PAGE}->[$page]->{TEXT} } if ( defined $data->{PAGE}->[$page]->{TEXT} );

    for ( my $j = $#lines ; $j >= 0 ; $j-- ) {
      my @words         = @{ $lines[$j]->{TOKEN} };
      my @tmp           = ();
      my %hash_y        = ();
      my %hash_fontsize = ();
      my $x_end         = ();
      foreach my $i ( 0 .. $#words ) {
        next if ( !$words[$i]->{content} );
        $hash_y{ $words[$i]->{'y'} }++;
        $hash_fontsize{ $words[$i]->{'font-size'} }++;
        push @tmp, $words[$i]->{content};
        $x_end = $words[$i]->{'x'} + $words[$i]->{'width'};
      }
      my $line = join( " ", @tmp );
      $line =~ s/\x{2013}/-/g;
      $line =~ s/\x{B1}/-/g;

      $counter_hash{$line}++;
      my $y   = 0;
      my $max = 0;

      for my $key ( keys %hash_y ) {
        if ( $hash_y{$key} > $max ) {
          $y   = $key;
          $max = $hash_y{$key};
        }
      }

      my $fs = 0;
      $max = 0;
      for my $key ( keys %hash_fontsize ) {
        if ( $hash_fontsize{$key} > $max ) {
          $fs  = $key;
          $max = $hash_fontsize{$key};
        }
      }

      ( my $tmp_line = $line ) =~ s/\s+//g;
      $flag = 1 if ( $tmp_line =~ m/^references$/i );
      $flag = 1 if ( $tmp_line =~ m/^\d+\.?references$/i );
      $flag = 1 if ( $line     =~ m/^References\sand\srecommended\sreading$/i );
      $flag = 1 if ( $line     =~ m/^Notes\sand\sreferences$/i );
      $flag = 1 if ( $line     =~ m/^LITERATURE\sCITED$/i );
      $flag = 1 if ( $line     =~ m/^REFERENCES\sCITED$/i );
      $flag = 1 if ( $line     =~ m/^References\sand\sNotes$/ );
      $flag = 1 if ( $line     =~ m/^\d+.\sReferences$/ );
      $flag = 1 if ( $line     =~ m/^Bibliography$/ );
      $flag = 1 if ( $line     =~ m/^r\se\sf\se\sr\se\sn\sc\se\ss$/i );
      $flag = 1 if ( $line     =~ m/^References:$/i );

      if ( $flag == 1 ) {
        $ref_x = $lines[$j]->{'x'};
        $ref_y = $y;
        last;
      }
      push @output,   $line;
      push @x_coords, $lines[$j]->{'x'};
      push @y_coords, $y;
      push @fontsize, $fs;
      push @pages_nr, $page;
      push @x_ends,   $x_end;
    }
  }
  @output   = reverse(@output);
  @x_coords = reverse(@x_coords);
  @y_coords = reverse(@y_coords);
  @fontsize = reverse(@fontsize);
  @pages_nr = reverse(@pages_nr);
  @x_ends   = reverse(@x_ends);

  # NOW GET RID OF EVERYTHING THAT SEEMS TO BE ABOVE THE REFERENCE
  # use $ref_x and $ref_y for that

  # We go here if we did not find a reference heading
  # to limit the output we have to parse
  if ( $flag == 0 ) {
    my $last_ref;
    my @tmp = ();
    for ( my $i = $#output ; $i >= 0 ; $i-- ) {
      ( my $forparsing = $output[$i] ) =~ s/\s//g;
      my $parsing_flag = ( $forparsing =~ m/^\d+$/ ) ? 0 : 1;
      if ( $output[$i] =~ m/^\[?(\d+)(\]|\.|\s).*/ and $parsing_flag == 1 ) {
        if ( !$last_ref ) {
          $last_ref = $1 if ( $1 < 1000 );
          next;
        }
        $last_ref = $1 if ( $1 == $last_ref - 1 );
      }
      push @tmp, $output[$i];
      if ($last_ref) {
        last if ( $last_ref == 1 );
      }
    }
    if ($last_ref) {
      @output = reverse(@tmp) if ( $last_ref == 1 );
    }
  }

  return (
    \@output, \@x_coords,     \@y_coords, \@fontsize, \@pages_nr,
    $flag,    \%counter_hash, $nr_pages,  \@x_ends
  );
}


sub _split_by_numbers_counting {

  my $output = $_[0];

  # Let's first see if references are numbered
  my $split_by_numbers_forward = 0;
  my $last_pos                 = 0;
  for ( my $i = 0 ; $i <= $#{$output} ; $i++ ) {
    if ( $output->[$i] =~ m/^\[?(\d+)(\]|\.|\s).*/ ) {
      if ( !$split_by_numbers_forward ) {
        $split_by_numbers_forward = $1 if ( $1 == $split_by_numbers_forward + 1 );
        $last_pos = $i;
        next;
      }
      if ( $1 == $split_by_numbers_forward + 1 and $i - $last_pos < 10 ) {
        $split_by_numbers_forward = $1;
        $last_pos                 = $i;
      }
    }
  }

  my $split_by_numbers_backward = 0;
  my $tmp_counter               = -1;
  my $start_line                = -1;
  my $runs                      = 0;
  while (1) {
    $runs++;
    my $end_pos = ( $start_line > -1 ) ? $start_line - 1 : $#{$output};
    $split_by_numbers_backward = 0;
    $tmp_counter               = -1;
    for ( my $i = $end_pos ; $i >= 0 ; $i-- ) {
      if ( $output->[$i] =~ m/^\[?(\d+)(\]|\.|\s).*/ ) {
        if ( $tmp_counter == -1 and $1 < 1000 ) {
          $tmp_counter               = $1;
          $split_by_numbers_backward = 1;
          $start_line                = $i;
          next;
        }
        if ( $tmp_counter - 1 == $1 ) {
          $tmp_counter = $1;
          $split_by_numbers_backward++;
        }
      }
    }
    last if ( $tmp_counter == 1 );
    last if ( $runs >= 3 );
  }

  my $max_split_by_numbers =
    ( $split_by_numbers_forward < $split_by_numbers_backward )
    ? $split_by_numbers_backward
    : $split_by_numbers_forward;

  return ( $split_by_numbers_forward, $split_by_numbers_backward, $max_split_by_numbers );
}

sub _split_by_braces_counting {

  my $output = $_[0];

  my $counts = 0;

  for ( my $i = 0 ; $i <= $#{$output} ; $i++ ) {
    $counts++ if ( $output->[$i] =~ m/^\[.{3,10}\]/ );
  }

  return $counts;

}


sub _split_by_indention_counting {

  my $output   = $_[0];
  my $x_coords = $_[1];
  my $y_coords = $_[2];

  my $threshold = 5;

  # If references are not number, we look if there
  # are some characteristsics in spacing of the lines
  my $count_indention = 0;
  my $x_start_pos     = {};

  for ( my $i = 0 ; $i <= $#{$output} ; $i++ ) {
    if ( $x_coords->[$i] - $x_coords->[ $i - 1 ] >= $threshold and $y_coords->[$i] > $y_coords->[ $i - 1 ] ) {
      $count_indention++;
      $x_start_pos->{ $x_coords->[ $i - 1 ] }++;
    }
  }

  return ($count_indention, $x_start_pos);
}

sub _split_by_yspacing_counting {

  my $output   = $_[0];
  my $x_coords = $_[1];
  my $y_coords = $_[2];

  my $threshold = 5;

  # If references are not number, we look if there
  # are some characteristsics in spacing of the lines
  my $count_indention = 0;
  my %diffs           = ();

  for ( my $i = 0 ; $i < $#{$output} ; $i++ ) {
    if ( $y_coords->[ $i + 1 ] > $y_coords->[$i] ) {
      my $diff = $y_coords->[ $i + 1 ] - $y_coords->[$i];
      next if ( $diff <= $threshold );
      $diffs{$diff}++;
    }
  }

  # find the diff with most counts
  my $regular_spacing        = 0;
  my $regular_spacing_counts = 0;
  while ( my ( $key, $value ) = each(%diffs) ) {
    if ( $value > $regular_spacing_counts ) {
      $regular_spacing_counts = $value;
      $regular_spacing        = $key;
    }
  }

  my $split_spacing        = 0;
  my $split_spacing_counts = 0;
  while ( my ( $key, $value ) = each(%diffs) ) {
    if ( $value > $split_spacing_counts and $key > $regular_spacing + 1 ) {
      $split_spacing_counts = $value;
      $split_spacing        = $key;
    }
  }

  my $split_spacing_min = $split_spacing;
  my $split_spacing_max = $split_spacing;

  if ( $diffs{ $split_spacing - 1 } ) {
    $split_spacing_min = $split_spacing - 1
      if ( $diffs{ $split_spacing - 1 } > $diffs{$split_spacing} * 0.3 );
  }
  if ( $diffs{ $split_spacing + 1 } ) {
    $split_spacing_max = $split_spacing + 1
      if ( $diffs{ $split_spacing + 1 } > $diffs{$split_spacing} * 0.3 );
  }

  if ( $split_spacing_min == $regular_spacing ) {
    $split_spacing_min = $split_spacing_min + 1;
  }

  return ( $split_spacing_min, $split_spacing_max, $split_spacing_counts );
}

sub _split_by_numbers {

  my $output                    = $_[0];
  my $split_by_numbers_forward  = $_[1];
  my $split_by_numbers_backward = $_[2];
  my $max_split_by_numbers      = $_[3];
  my $counter_hash              = $_[4];
  my $nr_pages                  = $_[5];
  my $x_coords                  = $_[6];
  my $y_coords                  = $_[7];

  my @reference_strings = ();

  # we have to find the kick-off first in most cases it is trivial
  my $kickoff_position = 0;
  for ( my $i = 0 ; $i <= $#{$output} ; $i++ ) {
    if ( $output->[$i] =~ m/^\[?(\d+)(\]|\.|\s)(.*)/ ) {
      next if ( $3 =~ m/^\d/ );
      if ( $1 == 1 ) {
        my $max_pos = ( $i + 10 > $#{$output} ) ? $#{$output} : $i + 10;
        my $flag = 0;
        for ( my $j = $i + 1 ; $j <= $max_pos ; $j++ ) {
          if ( $output->[$j] =~ m/^\[?(\d+)(\]|\.|\s).*/ ) {
            $flag = 1 if ( $1 == 2 );
            $flag = 2 if ( $1 == 3 and $flag == 1 );
            $flag = 3 if ( $1 == 4 and $flag == 2 );
          }
        }
        if ( $flag == 3 ) {
          $kickoff_position = $i;
          last;
        }
      }
    }
  }

  my @tmp       = ();
  my $current   = 0;
  my $current_x = 0;
  my $current_y = 0;
  for ( my $i = $kickoff_position ; $i <= $#{$output} ; $i++ ) {
    my $counts = $counter_hash->{ $output->[$i] };
    if ( $counts > 1 ) {
      next
        if (length( $output->[$i] ) > 15
        and $counts > $nr_pages * 0.5
        and $output->[$i] !~ m/^\[?(\d+)(\]|\.|\s).*/ );
    }

    if ( $output->[$i] =~ m/^\[?(\d+)(\]|\.|\s).*/ ) {
      if ( $current + 1 == $1 ) {
        $current = $1;
        if ( $#tmp > -1 and $current > 1 ) {
          push @reference_strings, join( " ", @tmp );
        }
        @tmp       = ();
        $current_x = $x_coords->[$i];
        $current_y = $y_coords->[$i];
      } else {
        push @tmp, $output->[$i] if ( $current > 1 );
        $current_x = $x_coords->[$i];
        $current_y = $y_coords->[$i];
        next;
      }
    }

    next if ( $current == 0 );

    # let's check if the string is really the next one to come
    my $diff_y = $y_coords->[$i] - $current_y;
    my $diff_x = abs( $current_x - $x_coords->[$i] );
    next if ( $diff_y > 50 );
    next if ( $diff_x > 50 );

    if ( $current < $max_split_by_numbers ) {
      push @tmp, $output->[$i];
      $current_x = $x_coords->[$i];
      $current_y = $y_coords->[$i];
    } else {
      if ( stop_words( $output->[$i] ) == 1 ) {
        push @reference_strings, join( " ", @tmp );
        @tmp = ();
        last;
      } else {
        push @tmp, $output->[$i];
        $current_x = $x_coords->[$i];
        $current_y = $y_coords->[$i];
      }
    }
  }
  if ( $#tmp != -1 ) {
    my $tmp = join( " ", @tmp );
    push @reference_strings, $tmp if ( $tmp =~ m/^\[?(\d+)(\]|\.|\s).*/ );
  }

  return \@reference_strings;
}

sub _split_by_braces {

  my $output = $_[0];

  my @reference_strings = ();

  my @tmp     = ();
  my $x_first = 0;
  for ( my $i = 0 ; $i <= $#{$output} ; $i++ ) {
    if ( $output->[$i] =~ m/^\[.{3,10}\]/ ) {
      if ( $#tmp != -1 ) {
        push @reference_strings, join( " ", @tmp );
      }
      @tmp = ();
    }
    push @tmp, $output->[$i];
  }
  if ( $#tmp != -1 ) {
    push @reference_strings, join( " ", @tmp );
  }

  return \@reference_strings;
}

sub _split_by_indention {

  my $output      = $_[0];
  my $x_coords    = $_[1];
  my $x_start_pos = $_[2];
  my $y_coords    = $_[3];

  my @reference_strings = ();

  my $max_count = 0;

  foreach my $pos ( keys %{$x_start_pos} ) {
    my $counts = ( $x_start_pos->{$pos} ) ? $x_start_pos->{$pos} : 0;
    if ( $counts > 0 ) {
      my $counts_plus_one  = ( $x_start_pos->{ $pos + 1 } ) ? $x_start_pos->{ $pos + 1 } : 0;
      my $counts_minus_one = ( $x_start_pos->{ $pos - 1 } ) ? $x_start_pos->{ $pos - 1 } : 0;
      $counts += $counts_plus_one + $counts_minus_one;
    }
    $max_count = $counts if ( $counts > $max_count );
  }

  my @tmp     = ();
  my $x_first = 0;
  for ( my $i = 0 ; $i <= $#{$output} ; $i++ ) {
    my $counts = ( $x_start_pos->{ $x_coords->[$i] } ) ? $x_start_pos->{ $x_coords->[$i] } : 0;
    if ( $counts > 0 ) {
      my $counts_plus_one =
        ( $x_start_pos->{ $x_coords->[$i] + 1 } ) ? $x_start_pos->{ $x_coords->[$i] + 1 } : 0;
      my $counts_minus_one =
        ( $x_start_pos->{ $x_coords->[$i] - 1 } ) ? $x_start_pos->{ $x_coords->[$i] - 1 } : 0;
      $counts += $counts_plus_one + $counts_minus_one;
    }
    last if ( stop_words( $output->[$i] ) == 1 );

    my $start_new_one = 0;
    if ( $counts >= 2 ) {
      my $x_before = ( $i > 0 ) ? $x_coords->[ $i - 1 ] : $x_coords->[$i];
      $start_new_one = 1 if ( $x_coords->[$i] < $x_before );
    }

    $start_new_one = 1 if ( $counts == $max_count );

    if ( $start_new_one == 1 ) {
      if ( $#tmp != -1 ) {
        push @reference_strings, join( " ", @tmp );
      }
      @tmp = ();
      push @tmp, $output->[$i];
    } else {
      if ( stop_words( $output->[$i] ) == 1 ) {
        push @reference_strings, join( " ", @tmp );
        @tmp = ();
        last;
      } else {
        push @tmp, $output->[$i];
      }
    }
  }
  if ( $#tmp != -1 ) {
    push @reference_strings, join( " ", @tmp );
  }

  return \@reference_strings;
}

sub _split_by_yspacing {

  my $output            = $_[0];
  my $y_coords          = $_[1];
  my $split_spacing_min = $_[2];
  my $split_spacing_max = $_[3];
  my $x_ends_ref        = $_[4];

  my @reference_strings = ();

  my @tmp = ();
  for ( my $i = 0 ; $i <= $#{$output} ; $i++ ) {
    my $diff_forward  = ( $i < $#{$output} ) ? $y_coords->[ $i + 1 ] - $y_coords->[$i] : 0;
    my $diff_backward = ( $i > 0 )           ? $y_coords->[$i] - $y_coords->[ $i - 1 ] : 0;
    my $do_split      = 0;
    $do_split = 1
      if ( $diff_forward >= $split_spacing_min and $diff_forward <= $split_spacing_max );
    if ( $i > 0 and $#tmp != -1 ) {
      $do_split = 1 if ( $x_ends_ref->[$i] < $x_ends_ref->[ $i - 1 ] * 0.9 );
      $do_split = 1
        if ( $x_ends_ref->[$i] < $x_ends_ref->[ $i - 1 ] * 0.95 and $output->[$i] =~ m/\d\.?$/ );
    }

    if ( $do_split == 1 ) {
      if ( $#tmp != -1 ) {
        push @tmp, $output->[$i];
        push @reference_strings, join( " ", @tmp );
      }
      @tmp = ();
      next;
    }
    if ( $diff_forward < -100 ) {

      # we jumped to the top of the page again
      # At the moment we are conservative and say to start a new one
      if ( $#tmp != -1 and $output->[$i] =~ m/\.$/ ) {
        push @tmp, $output->[$i];
        push @reference_strings, join( " ", @tmp );
        @tmp = ();
        next;
      }
    }

    push @tmp, $output->[$i];
  }

  return \@reference_strings;
}




1;
