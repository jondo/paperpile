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

package Paperpile::PdfExtract::Biopolymers;
use Mouse;

sub parse {

  my ( $self, $l, $verbose ) = @_;

  my $flag = 0;
  foreach my $i ( 0 .. $#{$l} ) {
    $flag = 1 if ( $l->[$i]->{content} =~ m/^Biopolymers,\sVol\.\s\d+/i );
  }

  return ( undef, undef ) if ( $flag == 0 );

  my ( $title, $authors );

  my @title_tmp   = ();
  my @authors_tmp = ();
  for ( my $j = 0 ; $j <= $#{$l} ; $j++ ) {
    push @title_tmp, $l->[$j]->{content} if ( $l->[$j]->{fs} == 18 );
    last if ( $l->[$j]->{content} =~ m/^Abstract:/ );
  }
  for ( my $j = 0 ; $j <= $#{$l} ; $j++ ) {
    push @authors_tmp, $l->[$j]->{content} if ( $l->[$j]->{fs} == 11 );
    last if ( $l->[$j]->{address_count} > 0 );
  }

  $title   = join( " ", @title_tmp );
  $authors = join( ", ", @authors_tmp );

  return ( $title, $authors );
}

1;
