# Copyright 2009, 2010 Paperpile
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
    my @entries;    # array of ris text blocks
    my @ris;        # array (references) of arrays (tags)
    my $tmp_note = '';

    # map of ris types to paperpile types
    my %types = (
        'JOUR' => 'ARTICLE',
        'JFUL' => 'ARTICLE',
        'MGZN' => 'ARTICLE',
        'BOOK' => 'BOOK',
        'CHAP' => 'INBOOK',
        'CONF' => 'PROCEEDINGS',
        'THES' => 'PHDTHESIS',
        'RPRT' => 'TECHREPORT',
        'UNPB' => 'UNPUBLISHED'
    );

    my $fh = new IO::File $self->file, "r";

    my $line = '';    # get a whole tag
    my @tmp;          # collect tags of current ref
    my @data = <$fh>;
    for ( my $i = 0 ; $i <= $#data ; $i++ ) {
        if ( $data[$i] =~ /ER  -\s*/ ) {
            chomp $line;
            push @tmp, $line;
            push @ris, [@tmp];    # store previous ref
            @tmp  = ();
            $line = '';
        }
        elsif ( $data[$i] =~ /^\S\S\s\s\- / ) {
            if ( $line eq '' ) {
                $line = $data[$i];    # initialise/read tag
            }
            else {
                chomp $line;
                push @tmp, $line;     # store previously read tag
                $line = $data[$i];    # init next round
            }
        }
        elsif ( $data[$i] =~ /\S/ ) {    # entry over several lines
            $line .= $data[$i];
        }
        else {

            # print STDERR "skipped line: \'$data[$i]\'\n";
        }
    }

    # don't forget last one
    if ( $line ne '' ) {
        chomp $line;
        push @tmp, $line;
        push @ris, [@tmp];
    }

    # now we have to parse each tag
    foreach my $ref (@ris) {    # each reference
        my $data    = {};       # hash_ref to data
        my @authors = ();
        my @editors = ();
        foreach my $tag ( @{$ref} ) {    # each tag of reference
            $tag =~ /^(\S\S)\s\s\-\s(.+)/;
            my $t = $1;                  # tag
            my $d = $2;                  # data

            switch ($t) {
                case 'TY' {
                    if ( exists $types{$d} ) {
                        $data->{pubtype} = $types{$d};
                    }
                    else {
                        $data->{pubtype} = 'MISC';
                    }
                }
                case 'T1' {              # primary title
                    $data->{title} = $d;
                }
                case 'TI' {    # TODO: some title, don't know what TI stands for
                    $data->{title} = $d;
                }
                case 'CT' {    # TODO: chapter title?
                    $data->{title} = $d;
                }
                case 'BT' {    # book title
                    $data->{booktitle} = $d;
                }
                case 'T2' {    # secondary title
                    if ( !exists $data->{title} ) {
                        $data->{title} = $d;
                    }
                    else {
                        $data->{title} .= " - " . $d;
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
                    ( $data->{year}, $data->{month}, $data->{day}, $tmp_note ) =
                      _parse_date($d);
                    _add_to_note( $data, $tmp_note ) if ( $tmp_note ne '' );

                }
                case 'PY' {    # primary date (year)
                    ( $data->{year}, $data->{month}, $data->{day}, $tmp_note ) =
                      _parse_date($d);
                    _add_to_note( $data, $tmp_note ) if ( $tmp_note ne '' );
                }
                case 'Y2' {    # secondary date, TODO: purpose?
                    ( $data->{year}, $data->{month}, $data->{day}, $tmp_note ) =
                      _parse_date($d);
                    _add_to_note( $data, $tmp_note ) if ( $tmp_note ne '' );
                }
                case 'N1' {    # notes can be different things...
                    if ( _test_for_doi($d) ) {
                        $data->{doi} = $d;
                    }
                    elsif ( _test_for_abstract($d) ) {
                        $data->{abstract} = $d;
                    }
                }
                case 'AB' {    # abstract
                    $data->{abstract} = $d;
                }
                case 'N2' {    # abstract
                    $data->{abstract} = $d;
                }
            }
        }

        $data->{authors} = join( ' and ', @authors ) if (@authors);
        $data->{editors} = join( ' and ', @editors ) if (@editors);

        push @output, Paperpile::Library::Publication->new($data);
    }

    return [@output];
}

# we assume that a huge text with many words is an abstract
sub _test_for_abstract {
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
sub _test_for_doi {
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
	print STDERR  $data_ptr->{note};
    }
    else {
        $data_ptr->{note} = $note;
    }
}

# get year, month, day, and special free text field
sub _parse_date {
    my $string = shift;

    my @ret;
    if ( $string =~ /(.*)\/(.*)\/(.*)\/(.*)/ ) {    # full date
        ( $ret[0], $ret[1], $ret[2], $ret[3] ) = ( $1, $2, $3, $4 );
        for ( my $i = 0 ; $i <= $#ret ; $i++ ) {
            if ( ! $ret[$i] ) {
                $ret[$i] = '';                      # don't return undef
            }
        }
        return (@ret);
    }
    else {    # at least try to get single year
        $string =~ /^(\d\d\d\d)/;
        my $year = $1;
        return ($year, '', '', '');
    }
}

1;

