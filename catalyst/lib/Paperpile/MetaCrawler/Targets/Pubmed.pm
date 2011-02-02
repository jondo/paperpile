
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


package Paperpile::MetaCrawler::Targets::Pubmed;
use Moose;
use Paperpile::Plugins::Import::PubMed;

extends 'Paperpile::MetaCrawler::Targets';

sub convert {

  my ($self, $content, $url) = @_;

  if ( $url =~ m/http:\/\/www\.ncbi\.nlm\.nih\.gov\/pubmed\/(\d+)(\D.*)?/ ) {
    my $PubMedPlugin = Paperpile::Plugins::Import::PubMed->new();
    return $PubMedPlugin->_fetch_by_pmid($1);
  }
  if ( $url =~ m/http:\/\/www\.ncbi\.nlm\.nih\.gov\/pubmed\?term=(\d+)\D*/ ) {
    my $PubMedPlugin = Paperpile::Plugins::Import::PubMed->new();
    return $PubMedPlugin->_fetch_by_pmid($1);
  }
  if ( $url =~ m/http:\/\/www\.ncbi\.nlm\.nih\.gov\/sites\/entrez\/(\d+)(\D.*)?/ ) {
    my $PubMedPlugin = Paperpile::Plugins::Import::PubMed->new();
    return $PubMedPlugin->_fetch_by_pmid($1);
  }
  if ( $url =~ m/.*pubmed\/(\d+)$/ ) {
    my $PubMedPlugin = Paperpile::Plugins::Import::PubMed->new();
    return $PubMedPlugin->_fetch_by_pmid($1);
  }
  if ( $url =~ m/.*\.ncbi\.nlm\.nih\.gov\/pmc\/articles\/(PMC\d+)\// ) {
    my $PubMedPlugin = Paperpile::Plugins::Import::PubMed->new();
    return $PubMedPlugin->_fetch_by_pmid($1);
  }
  if ( $url =~ m/.*ukpmc\.ac\.uk\/articles\/(PMC\d+)/ ) {
    my $PubMedPlugin = Paperpile::Plugins::Import::PubMed->new();
    return $PubMedPlugin->_fetch_by_pmid($1);
  }

  return undef;
}
