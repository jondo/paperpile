
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

package Paperpile::MetaCrawler::Targets::Default;
use Moose;
use Paperpile::Formats::HTML;
use Paperpile::Plugins::Import::PubMed;
use Paperpile::Utils;

extends 'Paperpile::MetaCrawler::Targets';

sub convert {

  my ( $self, $content ) = @_;

  my $pub;

  # Let's try to find some meta tags or
  my $f = new Paperpile::Formats::HTML;
  $f->content($content);
  $pub = $f->read();

  # If we are on a site with frames, we might have not
  # actually parsed what we wanted to. So we search
  # for frame tags and parse each frame individually.
  if ( !$pub->title ) {

    # We parse the HTML via TreeBuilder
    my $tree = HTML::TreeBuilder->new;
    $tree->utf8_mode(1);
    $tree->parse_content($content);

    # Get a browser
    my $browser = Paperpile::Utils->get_browser;

    # let's screen for frame tags and follow the links
    my @tags = $tree->look_down( '_tag' => 'frame' );
    foreach my $tag (@tags) {
      if ( $tag->{src} =~ m/^http/ ) {
        my $response = $browser->get( $tag->{src} );
	$f->content($response->content);
	$pub = $f->read();
	last if ( $pub->title );
      }
    }
  }

  # If we have found a pubmed ID we call the pubmed interface
  if ( $pub->pmid() ) {
    my $PubMedPlugin = Paperpile::Plugins::Import::PubMed->new();
    return $PubMedPlugin->_fetch_by_pmid( $pub->pmid() );
  }

  # Once the CrossRef is active, we can parse
  # for a DOI and call it then

  # Important: admit defeat if we still don't have a title.
  if (!$pub->title) {
      return undef;
  }

  return $pub;
}
