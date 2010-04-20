
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

package Paperpile::MetaCrawler::Targets::LAPress;
use Moose;
use HTML::TreeBuilder;
use Paperpile::Utils;
use Paperpile::Formats;

extends 'Paperpile::MetaCrawler::Targets';

sub convert {

  my ( $self, $content ) = @_;

  # We parse the HTML via TreeBuilder
  my $tree = HTML::TreeBuilder->new;
  $tree->utf8_mode(1);
  $tree->parse_content($content);

  # let's get the Endnote export link
  my @tags = $tree->look_down( '_tag' => 'a', 'class' => 'endnote' );
  my $export_link = 'http://la-press.com/' . $tags[0]->{href};

  # Get abrowser and follow the export URL
  my $browser  = Paperpile::Utils->get_browser;
  my $response = $browser->get($export_link);

  my $f = Paperpile::Formats->new( format => 'RIS' );
  my $pub = $f->read_string( $response->content );

  # the information is not of high quality and we parse the rest from the HTML
  @tags = $tree->look_down( '_tag' => 'div', 'class' => 'journalListingAuthor' );

  my $tmp = $tags[$#tags]->as_text();
  if ( $tmp =~ m/(.*\d{4}:)(\d+)\s(\d+-\d+)/ ) {
    $pub->[0]->volume($2);
    $pub->[0]->pages($3);
  }

  $tree->delete;

  return $pub->[0];
}

1;
