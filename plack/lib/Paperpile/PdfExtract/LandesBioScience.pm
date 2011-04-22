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

package Paperpile::PdfExtract::LandesBioScience;
use Mouse;

sub parse {

  my ( $self, $lines, $verbose ) = @_;

  my $flag = 0;
  foreach my $line ( @{$lines} ) {
    $flag = 1 if ( $line->{content} =~ m/Landes Bioscience/ );
  }

  return ( undef, undef ) if ( $flag == 0 );

  my ( $title, $authors );

  my @t = ();
  my @a = ();
  foreach my $line ( @{$lines} ) {
    push @t, $line->{content} if ( $line->{fs} == 24 );
    push @a, $line->{content}
      if ($line->{fs} == 12
      and abs( 37 - $line->{xMin} ) <= 7
      and $line->{content} =~ m/,$/ );
  }

  if ( $#a == -1 ) {
    foreach my $line ( @{$lines} ) {
      push @a, $line->{content}
        if ($line->{fs} == 10
        and abs( 37 - $line->{xMin} ) <= 7
        and $line->{content} =~ m/,$/
        and $line->{yMin} < 200 );
    }
  }

  $title   = join( " ", @t );
  $authors = join( ",", @a );

  return ( $title, $authors );
}

1;
