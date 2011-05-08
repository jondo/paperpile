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

package Paperpile::PdfExtract::JSTOR;
use Mouse;

sub parse {

  my ( $self, $l, $verbose ) = @_;

  my $flag        = 0;
  my $author_flag = -1;
  foreach my $i ( 0 .. $#{$l} ) {
    $flag = 1 if ( $l->[$i]->{content} =~ m/Your\suse\sof\sthe\sJSTOR\sarchive\sindicates/i );
    $author_flag = $i if ( $l->[$i]->{content} =~ m/^Author\(s\):/ );
  }

  return ( undef, undef ) if ( $flag == 0 );

  my ( $title, $authors );

  if ( $author_flag > -1 ) {
    my @title_tmp   = ();
    my @authors_tmp = ();
    $l->[$author_flag]->{content} =~ s/^(Author\(s\):\s)(.*)/$2/;
    push @authors_tmp, $l->[$author_flag]->{content};
    for ( my $j = $author_flag + 1 ; $j <= $#{$l} ; $j++ ) {
      last if ( $l->[$j]->{content} =~ m/^Source/ );
      push @authors_tmp, $l->[$j]->{content};
    }
    for ( my $j = $author_flag - 1 ; $j >= 0 ; $j-- ) {
      unshift @title_tmp, $l->[$j]->{content};
    }

    $title   = join( " ", @title_tmp );
    $authors = join( " ", @authors_tmp );
  } else {
    my @title_tmp   = ();
    my @authors_tmp = ();
    for ( my $j = 0 ; $j <= $#{$l} ; $j++ ) {
      if ( $l->[$j]->{xMin} > 50 ) {
        $author_flag = $j;
        last;
      }
      push @title_tmp, $l->[$j]->{content};
    }
    for ( my $j = $author_flag ; $j <= $#{$l} ; $j++ ) {
      last if ( $l->[$j]->{nr_bad_words} > 0 );
      push @authors_tmp, $l->[$j]->{content};
    }
    $title   = join( " ", @title_tmp );
    $authors = join( " ", @authors_tmp );
    $authors =~ s/;/,/g;
  }

  return ( $title, $authors );
}

1;
