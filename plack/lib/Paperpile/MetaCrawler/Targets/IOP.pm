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

package Paperpile::MetaCrawler::Targets::IOP;
use Mouse;
extends 'Paperpile::MetaCrawler::Targets';

use Paperpile::Formats;
use Paperpile::Formats::HTML;
use Paperpile::Formats::Bibtex;

sub convert {

  my ( $self, $content, $content_URL ) = @_;

  # Let'sparse for metatags first
  my $f = new Paperpile::Formats::HTML;
  $f->content($content);
  my $fullpub = $f->read();
  $fullpub->abstract('');

  # Then follow the bibtex export, to be sure to get all data
  if ( $content_URL =~ m/(.*iop\.org\/)([\w|\-|\/]+)(.*)/ ) {
    my $base = $1;
    (my $id = $2) =~ s/\/$//;
    my $bibtexurl = $base."export\?articleId=".$id."&exportFormat=iopexport_bib&exportType=abs";
    my $browser    = Paperpile::Utils->get_browser;
    my $response   = $browser->get($bibtexurl);
    $content = $response->content();

    my $pub;
    my $f = Paperpile::Formats::Bibtex->new();
    $pub = $f->read_string($content);
    my $newpub = $pub->[0];
    foreach my $key ( keys %{ $fullpub->as_hash } ) {
      $fullpub->$key( $newpub->$key ) if ( $newpub->$key );
    }
  }

  return $fullpub;
}

1;
