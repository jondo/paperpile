
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


package Paperpile::MetaCrawler::Targets::Bibtex;
use Moose;
extends 'Paperpile::MetaCrawler::Targets';

use Paperpile::Formats::Bibtex;
use File::Temp qw(tempfile);

sub convert {

  my ( $self, $content ) = @_;

  my $pub;
  my $f = Paperpile::Formats::Bibtex->new( );

  # If the BIBTEX entry is embedded in HTML, we try to
  # parse it from the HTML
  if ( $content =~ m/<html>/ ) {
    my @tmp = split( //, $content );
    my $bibtex = '';
    foreach my $i ( 0 .. $#tmp - 8 ) {

      my $word = '';
      for my $k ( $i .. $i + 7 ) {
        $word .= $tmp[$k];
      }

      # let's see if we can find the article tag
      if ( uc($word) eq '@ARTICLE' ) {

        # we now count curly brackets
        my $count_opening = 0;
        my $count_closing = 0;
        $bibtex = $word;
        for my $k ( $i + 8 .. $#tmp ) {
          $count_opening++ if ( $tmp[$k] eq '{' );
          $count_closing++ if ( $tmp[$k] eq '}' );
          $bibtex .= $tmp[$k];
          last if ( $count_opening == $count_closing );
        }
        last;
      }
    }
    if ( $bibtex ne '' ) {
      my ( $fh, $file_name ) = tempfile();
      print $fh $bibtex;
      close($fh);

      $f->file($file_name);

      $pub = $f->read();
      unlink($file_name);
    }
  } else {

    # regular case, we just parse the content
    my ( $fh, $file_name ) = tempfile();
    print $fh $content;
    close($fh);

    $f->file($file_name);

    $pub = $f->read();
    unlink($file_name);
  }

  return $pub->[0];
}
