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

package Paperpile::PdfExtract::NPG;
use Mouse;

sub parse {

  my ( $self, $l, $verbose ) = @_;

  my $flag = 0;
  foreach my $i ( 0 .. $#{$l} ) {
    $flag = 1 if ( $l->[$i]->{content} =~ m/Nature\sPublishing\sGroup/i );
    $flag = 1 if ( $l->[$i]->{content} =~ m/Nature\sAmerica\sInc\./ );
    $flag = 1 if ( $l->[$i]->{content} =~ m/http:\/\/[a-z]+\.nature\.com/ );
    $flag = 1 if ( $l->[$i]->{content} =~ m/www\.nature\.com/ );
    $flag = 1 if ( $l->[$i]->{content} =~ m/doi:\s?10\.1038/i );
  }

  return ( undef, undef ) if ( $flag == 0 );

  my ( $title, $authors );

  # pairs of font sizes for title and authors
  my @combinations = (
    [ 32, 9 ], [ 28, 11 ], [ 24, 12 ], [ 24, 11 ], [ 22, 12 ], [ 22, 11 ],
    [ 22, 10 ], [ 18, 11 ], [ 18, 10 ], [ 18, 9 ], [ 17, 8 ]
  );

  foreach my $entry (@combinations) {
    last if ( defined $title and defined $authors );
    my @t      = ();
    my @a      = ();
    my $last_t = -1;
    my $xMin   = 10e6;
    my $xMax   = 0;
    ( my $font_t, my $font_a ) = @{$entry};

    # first find the title
    foreach my $i ( 0 .. $#{$l} ) {
      if ( $l->[$i]->{fs} == $font_t ) {
	next if ( $l->[$i]->{content} =~ m/ARTICLES/ );
        push @t, $l->[$i]->{content};
        $last_t = $i;
        $xMin   = $l->[$i]->{xMin} if ( $l->[$i]->{xMin} < $xMin );
        $xMax   = $l->[$i]->{xMax} if ( $l->[$i]->{xMax} > $xMax );
      }
    }

    if ( $#t > -1 ) {

      # now search for lines below the last title line
      # that are in the xMin-xMax span of title
      # and match the author font size
      my $last_a;
      foreach my $i ( 0 .. $#{$l} ) {
        last if ( $l->[$i]->{content} =~ m/^Abstract/ );
        next if ( $l->[$i]->{xMax} < $xMin );
        next if ( $l->[$i]->{xMin} > $xMax );
        next if ( $l->[$i]->{yMin} < $l->[$last_t]->{yMin} );
        next if ( $l->[$i]->{fs} != $font_a );
        last if ( $l->[$i]->{yMin} - $l->[$last_t]->{yMin} > 300 );
        next if ( length( $l->[$i]->{content} ) < 5 );
        if (  $xMin - 20 < $l->[$i]->{xMin}
          and $l->[$i]->{xMax} < $xMax + 100 ) {

          last
            if ( $l->[$i]->{nr_bad_words} > 0
            or $l->[$i]->{nr_bad_author_words} > 0
            or $l->[$i]->{'adress_count'} > 0 );

	  if ( $i > $last_t+1 ) {
	    last if ( $l->[$i]->{nr_common_words} > 0);
	  }
          if ( defined $last_a ) {
            last if ( $l->[$i]->{yMin} - $l->[$last_a]->{yMin} > 30 );
          }

          push @a, $l->[$i]->{content};
          $last_a = $i;
        }
      }
    }
    $title   = join( " ", @t ) if ( $#t > -1 );
    $authors = join( ",", @a ) if ( $#a > -1 );
  }

  return ( $title, $authors );
}

1;
