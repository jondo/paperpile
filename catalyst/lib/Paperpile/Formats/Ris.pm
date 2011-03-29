# Copyright 2009-2011 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.  You should have received a
# copy of the GNU General Public License along with Paperpile.  If
# not, see http://www.gnu.org/licenses.

package Paperpile::Formats::Ris;
use Moose;
use Data::Dumper;
use IO::File;
use Switch;
use Encode;

extends 'Paperpile::Formats';

sub BUILD {
    my $self = shift;
    $self->format('RIS');
    $self->readable(1);
    $self->writable(1);
}

sub read {
  my ($self) = @_;

  my @output;
  my @ris;    # array (references) of arrays (tags)
  my $tmp_note = '';

  # map of ris types to paperpile types
  my %types = (
    'JOUR' => 'ARTICLE',
    'JFUL' => 'ARTICLE',
    'MGZN' => 'ARTICLE',
    'ABST' => 'ARTICLE',
    'BOOK' => 'BOOK',
    'CHAP' => 'INBOOK',
    'CONF' => 'PROCEEDINGS',
    'THES' => 'PHDTHESIS',
    'RPRT' => 'TECHREPORT',
    'UNPB' => 'UNPUBLISHED'
  );

  my $fh = new IO::File $self->file, "r";

  my $line = '';      # get a whole tag
  my @tmp  = ();      # collect tags of current ref
  my @data = <$fh>;

  # Decode data. Not the most efficient way in terms of memory but
  # passing the whole data at once increases the chances to guess the
  # right encoding.
  my $decoded_data = Paperpile::Utils->decode_data( join( '', @data ) );
  @data = split( /\n/, $decoded_data );

  for ( my $i = 0 ; $i <= $#data ; $i++ ) {
    $data[$i] =~ s/\s+$//g;
    if ( $data[$i] =~ /ER\s+\-\s*/ ) {
      push @tmp, $line;    # keep last tag
      push @ris, [@tmp];   # store previous ref
      @tmp  = ();
      $line = '';
    } elsif ( $data[$i] =~ /^\S+\s+\-\s*/ ) {
      if ( $line eq '' ) {
        $line = $data[$i];    # initialise/read tag
      } else {
        push @tmp, $line;     # store previously read tag
        $line = $data[$i];    # init next round
      }
    } elsif ( $data[$i] =~ /\S/ ) {    # entry over several lines
      $line .= $data[$i];
    }
  }

  # don't forget last one
  if ( $line ne '' ) {
    push @tmp, $line;
    push @ris, [@tmp];
    @tmp  = ();
    $line = '';
  }

  # now we have to parse each tag
  foreach my $ref (@ris) {    # each reference
    my $data     = {};        # hash_ref to data
    my @authors  = ();
    my @editors  = ();
    my @keywords = ();
    my ( $start_page, $end_page );
    my ( $city, $address ) = ( '', '' );
    my $sn;
    my @urls       = ();
    my @pdfs       = ();
    my @full_texts = ();
    my ( $journal_full_name, $journal_short_name );

    foreach my $tag ( @{$ref} ) {

      # tags have actually length 2
      # however, we have seen longer ones, e.g. DOI in real life data
      $tag =~ /^(\S+)\s+\-\s(.+)/;
      my $t = $1;    # tag
      my $d = $2;    # data

      switch ($t) {
        case 'TY' {
          if ( exists $types{$d} ) {
            $data->{pubtype} = $types{$d};
          } else {
            $data->{pubtype} = 'MISC';
          }
        }
        case 'T1' {    # primary title
          $data->{title} = $d;
        }
        case 'TI' {    # TODO: some title, don't know what TI stands for
          if ( !exists $data->{title} ) {
            $data->{title} = $d;
          }
        }
        case 'CT' {    # TODO: chapter title?
          if ( !exists $data->{title} ) {
            $data->{title} = $d;
          }
        }
        case 'BT' {    # book title
          $data->{booktitle} = $d;
        }
        case 'T2' {    # secondary title
          if ( !exists $data->{title} ) {
            $data->{title} = $d;
          } else {
            $data->{title} .= " - " . $d;
          }

          if ( $data->{pubtype} eq 'INBOOK' || $data->{pubtype} eq 'BOOK' ) {
            $data->{booktitle} = $d;
          }
        }
        case 'T3' {    # series title
          $data->{series} = $d;
        }
        case 'A1' {    # primary author
          push @authors, $d;
        }
        case 'AU' {    # primary author
          push @authors, $d;
        }
        case 'A2' {    # secondary author
          push @editors, $d;
        }
        case 'ED' {    # secondary author (editor)
          push @editors, $d;
        }
        case 'A3' {    # tertiary author, TODO: purpose?
          push @authors, $d;
        }
        case 'Y1' {    # primary date
          _handle_dates( $data, $d );
        }
        case 'PY' {    # primary date (year)
          _handle_dates( $data, $d );
        }
        case 'Y2' {    # secondary date, TODO: purpose?
          _handle_dates( $data, $d );
        }
        case 'N1' {    # notes can be different things...
          if ( _is_doi($d) ) {
            $data->{doi} = $d;
          } elsif ( _is_abstract($d) ) {
            $data->{abstract} = $d;
          }
        }
        case 'AB' {    # abstract
          $data->{abstract} = $d;
        }
        case 'N2' {    # often abstract
          if ( _is_abstract($d) ) {
            $data->{abstract} = $d;
          } else {
            print STDERR "Warning: could not parse field '$t', content='$d'!\n";
          }
        }
        case 'KW' {    # keywords
          push @keywords, $d;
        }

        # we ignore the RP tag, its not needed
        # http://www.refman.com/support/risformat_tags_04.asp

        case 'JF' {    # journal full name
          $journal_full_name = $d;
        }
        case 'JO' {    # journal full name, alternative
          $journal_full_name = $d;
        }
        case 'JA' {    # journal short name
          $journal_short_name = $d;
        }

        case 'VL' {    # volume
          $data->{volume} = $d;
        }
        case 'IS' {    # issue
          $data->{issue} = $d;
        }
        case 'CP' {    # issue, alternative
          $data->{issue} = $d;
        }
        case 'SP' {    # start page number
          $start_page = $d;
        }
        case 'EP' {    # end page number
          $end_page = $d;
        }
        case 'CY' {    # city
          $city = $d;
        }
        case 'AD' {    # address
          $address = $d;
        }
        case 'PB' {    # publisher
          $data->{publisher} = $d;
        }
        case 'SN' {    # issn OR isbn
          $sn = $d;
        }

        # TODO:
        # http://www.refman.com/support/risformat_tags_07.asp
        # AV, U1-5 probably add them to notes?  or
        # should we try to parse them and figure out what they are?

        case 'M1' {
          if ( _is_doi($d) ) {
            $data->{doi} = $d;
          } else {
            print STDERR "Warning: could not parse field '$t', content='$d'!\n";
          }
        }
        case 'M2' {
          if ( _is_doi($d) ) {
            $data->{doi} = $d;
          } else {
            print STDERR "Warning: could not parse field '$t', content='$d'!\n";
          }
        }
        case 'M3' {
          if ( _is_doi($d) ) {
            $data->{doi} = $d;
          } else {
            print STDERR "Warning: could not parse field '$t', content='$d'!\n";
          }
        }
        case 'UR' {    # URL, one per tag or comma seperated list
          if ( $d !~ /;/ ) {
            push @urls, $d;
          } else {
            @urls = split /;/, $d;
          }
        }

        case 'L1' {

          # link to PDF
          # one per tag or comma seperated list
          if ( $d !~ /\;/ ) {
            push @pdfs, $d;
          } else {
            @pdfs = split /\;/, $d;
          }
        }

        case 'L2' {

          # link to full-text
          # probably our linkout field?
          if ( $d !~ /\;/ ) {
            push @full_texts, $d;
          } else {
            @full_texts = split /\;/, $d;
          }
        }

        # this are non-standard tags
        # which we unfortunately have been seen in real live data
        case 'DOI' {
          _set_doi( $data, $d, $t );
        }

        case 'DO' {
          _set_doi( $data, $d, $t );
        }

        else {
          print STDERR "Warning: field '$t' ignored, content='$d'!\n";
        }
      }
    }

    $data->{authors}  = join( ' and ', @authors )  if (@authors);
    $data->{editors}  = join( ' and ', @editors )  if (@editors);
    $data->{keywords} = join( ';',     @keywords ) if (@keywords);

    # set journal, try to keep full name, otherwise short name
    if ($journal_full_name) {
      $data->{journal} = $journal_full_name;
    } elsif ($journal_short_name) {
      $data->{journal} = $journal_short_name;
    }
    if ( defined $data->{journal} ) {
      $data->{journal} =~ s/\s+$//g;
      $data->{journal} = $data->{journal};
    }

    # set page numbers
    # if both, then join
    # otherwise keep single entry
    if ( $start_page && $end_page ) {
      $data->{pages} = $start_page . '-' . $end_page;
    } elsif ($start_page) {
      $data->{pages} = $start_page;
    } elsif ($end_page) {
      $data->{pages} = $end_page;
    }

    # set address
    if ($address) {    # if possible keep full address, otherwise only city
      $data->{address} = $address;
    } elsif ($city) {    # no address but city
      $data->{address} = $city;
    }

    # issn OR isbn?
    if ( _is_issn($sn) ) {
      $data->{issn} = $sn;
    } else {
      $data->{isbn} = $sn;
    }

    # simply keep the first URL
    $data->{url} = $urls[0] if (@urls);

    # simply keep the first PDF link
    $data->{_pdf_url} = $pdfs[0] if (@pdfs);

    # simply keep the first full-text link
    $data->{linkout} = $full_texts[0] if (@full_texts);

    # TODO:
    # L3 = related records
    # L4 = images

    push @output, Paperpile::Library::Publication->new($data);
  }

  Paperpile::Utils->uniquify_pubs( [@output] );

  return [@output];
}

# write ris data to file
sub write {
  my ($self) = @_;

  # map of paperpile types to ris types
  my %types = (
    'ARTICLE'     => 'JOUR',
    'BOOK'        => 'BOOK',
    'INBOOK'      => 'CHAP',
    'PROCEEDINGS' => 'CONF',
    'PHDTHESIS'   => 'THES',
    'TECHREPORT'  => 'RPRT',
    'UNPUBLISHED' => 'UNPB'
  );

  open( OUT, ">" . $self->file )
    || FileWriteError->throw( error => "Could not write to file " . $self->file );

  foreach my $pub ( @{ $self->data } ) {
    my @output;    # collect output data
                   # nested array (array of arrays)
                   # each entry is a key/value pair

    # pubtype
    push @output, [ 'TY', $types{ $pub->{pubtype} } ]
      if ( $pub->{pubtype} && exists $types{ $pub->{pubtype} } );

    # title
    push @output, [ 'T1', $pub->{title} ]
      if ( $pub->{title} );

    # booktitle instead of T2
    push @output, [ 'BT', $pub->{booktitle} ]
      if ( $pub->{booktitle} );

    # series title
    push @output, [ 'T3', $pub->{series} ]
      if ( $pub->{series} );

    # authors
    if ( $pub->{authors} ) {
      my @auth = split / and /, $pub->{authors};
      foreach my $name (@auth) {
        push @output, [ 'AU', $name ];
      }
    }

    # editors
    if ( $pub->{editors} ) {
      my @edit = split / and /, $pub->{editors};
      foreach my $name (@edit) {
        push @output, [ 'ED', $name ];
      }
    }

    # date, as YYYY/MM/DD
    my $date = '';
    $date .= $pub->{year}        if ( $pub->{year} );
    $date .= '/' . $pub->{month} if ( $pub->{month} );
    $date .= '/' . $pub->{day}   if ( $pub->{day} );
    push @output, [ 'Y1', $date ] if ( $date ne '' );

    # note
    push @output, [ 'N1', $pub->{note} ] if ( $pub->{note} );

    # abstract
    push @output, [ 'AB', $pub->{abstract} ] if ( $pub->{abstract} );

    # keywords
    if ( $pub->{keywords} ) {
      my @kw = split /;/, $pub->{keywords};
      foreach my $keyw (@kw) {
        push @output, [ 'KW', $keyw ];
      }
    }

    # journal
    # TODO: probably try to recognize short name
    # e.g. if it contains a dot, it could be the short name etc
    #
    # however, e.g. science exports both fields (JF and JO) at once
    # I don't know why
    if ( $pub->{journal} ) {
      push @output, [ 'JF', $pub->{journal} ];
      push @output, [ 'JO', $pub->{journal} ];
    }

    # volume
    push @output, [ 'VL', $pub->{volume} ] if ( $pub->{volume} );

    #issue
    push @output, [ 'IS', $pub->{issue} ] if ( $pub->{issue} );

    # pages
    if ( $pub->{pages} =~ /(.+)--*(.+)/ ) {    # start and end
      push @output, [ 'SP', $1 ] if ( $pub->{pages} );
      push @output, [ 'EP', $2 ] if ( $pub->{pages} );
    }    # a single number must be the start page
    else {
      push @output, [ 'SP', $pub->{pages} ] if ( $pub->{pages} );
    }

    # since paperpile publication objects do not have a city field
    # we can only parse the address tag.
    # in case of books ect, we should actually output CY (=city) instead of AD
    if ( $pub->{address} ) {
      if ( $pub->{pubtype} eq 'BOOK' || $pub->{pubtype} eq 'INBOOK' ) {
        push @output, [ 'CY', $pub->{address} ];
      } else {
        push @output, [ 'AD', $pub->{address} ];
      }
    }

    # publisher
    push @output, [ 'PB', $pub->{publisher} ] if ( $pub->{publisher} );

    # issn/isbn
    push @output, [ 'SN', $pub->{issn} ] if ( $pub->{issn} );
    push @output, [ 'SN', $pub->{isbn} ] if ( $pub->{isbn} );

    # url
    push @output, [ 'UR', $pub->{url} ] if ( $pub->{url} );

    # pdf-url
    push @output, [ 'L1', $pub->{_pdf_url} ] if ( $pub->{_pdf_url} );

    # pdf-url
    push @output, [ 'L2', $pub->{linkout} ] if ( $pub->{linkout} );

    # now we have all data and can output them
    _print_ris( \*OUT, \@output );
  }

  close OUT;
}

# helper to handle alternative Ris-DOI tags
sub _set_doi {
  my $data_ptr = shift;
  my $doi      = shift;
  my $field    = shift;

  if ( _is_doi($doi) ) {
    $data_ptr->{doi} = $doi;
  } else {
    print STDERR "Warning: could not parse field '$field', content='$doi'!\n";
  }
}

# dates are "complicated", since we have different date tags in ris
# e.g.
# Y1  - 1990///6th Annual
# Y2  - 1990/6/20
# but it can also happen that Y1 and Y2 contain different dates.
sub _handle_dates {
    my $data_ptr = shift;
    my $date     = shift;

    my ( $tmp_year, $tmp_month, $tmp_day, $tmp_note ) = _parse_date($date);
    my $newdate = '';
    $newdate .= $tmp_year        if ($tmp_year);
    $newdate .= '/' . $tmp_month if ($tmp_month);
    $newdate .= '/' . $tmp_day   if ($tmp_day);

    my $olddate = '';
    $olddate .= $data_ptr->{year}        if ( $data_ptr->{year} );
    $olddate .= '/' . $data_ptr->{month} if ( $data_ptr->{month} );
    $olddate .= '/' . $data_ptr->{day}   if ( $data_ptr->{day} );

    if ( length $newdate > length $olddate ) {    #is the new one more complete?
        $data_ptr->{year}  = $tmp_year if ($tmp_year);
        $data_ptr->{month} = $tmp_month if ($tmp_month);
        $data_ptr->{day}   = $tmp_day if ($tmp_day);
    }

    _add_to_note( $data_ptr, $tmp_note )
      if ( $tmp_note ne '' );
}

# just an output routine
# takes the data which we have collected in an array of arrays
# and prints them using a given filehandle
sub _print_ris {
    my $fh = shift;    # the filehandle
    my $a  = shift;    # the nested array

    foreach my $entry ( @{$a} ) {    # for each tag/value pair
        print $fh $entry->[0] . '  - ' . $entry->[1] . "\n";
    }
    print $fh "ER  - \n\n";          # end tag, must always be written
}

# test if argument is an issn
# an issn is a 4 digit number, followed by '-', and then 3 digits, followed by a digit or an X
sub _is_issn {
    my $no = shift;
    if ($no) {
        if ( $no =~ /\d\d\d\d\-\d\d\d[\dX]/ ) {
            return 1;
        }
    }

    return 0;

}

# we assume that a huge text with many words is an abstract
sub _is_abstract {
    my $s         = shift;
    my $min_words = 7;

    my @words = split /\s+/, $s;
    if ( scalar(@words) > $min_words ) {
        return 1;
    }
    else {
        return 0;
    }
}

# checks whether a string is a DOI or not
# TODO: the tests are probably too weak
sub _is_doi {
    my $s = shift;
    if ( $s =~ /^http:\/\/dx\.doi\.org/ || $s =~ /^\d\d\.\d+\/\S+/ ) {
        return 1;
    }
    else {
        return 0;
    }
}

# add the text $note to the note field of the data hash
sub _add_to_note {
    my ( $data_ptr, $note ) = @_;

    if ( exists $data_ptr->{note} ) {
        $data_ptr->{note} .= '; ' . $note;
        print STDERR $data_ptr->{note};
    }
    else {
        $data_ptr->{note} = $note;
    }
}

# get year, month, day, and special free text field
sub _parse_date {
    my $string = shift;

    my @ret;
    if ( @ret = split /\//, $string ) {
        for ( my $i = 0 ; $i <= 3 ; $i++ ) {    # don't return undef
            if ( !$ret[$i] ) {
                $ret[$i] = '';
            }
        }
        return (@ret);
    }
    else {    # at least try to get single year
        $string =~ /^(\d\d\d\d)/;
        my $year = $1;
        return ( $year, '', '', '' );
    }
}

1;

