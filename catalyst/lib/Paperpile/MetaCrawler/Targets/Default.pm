
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

extends 'Paperpile::MetaCrawler::Targets';

sub convert {

  my ($self, $content) = @_;

  # Let's try to find some meta tags or
  my $f = new Paperpile::Formats::HTML;
  $f->content($content);
  my $pub = $f->read();

  # If we have found a pubmed ID we call the pubmed interface
  if ( $pub->pmid() ) {
     my $PubMedPlugin = Paperpile::Plugins::Import::PubMed->new();
    return $PubMedPlugin->_fetch_by_pmid(  $pub->pmid() );
  }

  # Once the CrossRef is active, we can parse
  # for a DOI and call it then


  return $pub;
}
