# Copyright 2009, 2010 Paperpile
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


package Paperpile::MetaCrawler::Targets::IEEE;
use Moose;
use Paperpile::Utils;
use Paperpile::Formats::HTML;

extends 'Paperpile::MetaCrawler::Targets';

sub convert {

  my ( $self, $content, $url ) = @_;

  my $pub;
  my $arnumber;

  # IEEE has nice Bibtex export, but it does not work off-campus
  # We screen the HTML page for Meta-tags first
  # and then call the Bibtex export if we failed

  if ( $url =~ m/(.*arnumber=)(\d+)(.*)/ ) {
    $arnumber = $2;
  }

  # Not all results pages conatin meta-tags
  if ( $url !~ m/freeabs_all\.jsp/ ) {
    my $newurl     = 'http://ieeexplore.ieee.org/xpl/' .
      'freeabs_all.jsp?arnumber=' . $arnumber;
    my $browser    = Paperpile::Utils->get_browser;
    my $response   = $browser->get($newurl);
    $content = $response->content();
  }

  my $f = new Paperpile::Formats::HTML;
  $f->content($content);
  $pub = $f->read();

  # The abstract is still missing
  my $tree = HTML::TreeBuilder->new;
  $tree->utf8_mode(1);
  $tree->parse_content($content);

  my @tags = $tree->look_down(
    '_tag'  => 'div',
    'class' => 'abstract'
  );

  if ( $tags[0] ) {
    my $abstract = $tags[0]->as_text;
    $abstract =~ s/(.*\sAbstract)(.*)/$2/;
    $pub->abstract($abstract);
  }
  $tree->delete;

  if ( ! $pub->title() ){
    my $bibtexurl =
        'http://ieeexplore.ieee.org/xpl/downloadCitations'
      . '?recordIds='
      . $arnumber
      . '&fromPageName=searchabstract&citations-format='
      . 'citation-abstract&download-format=download-bibtex';
    my $browser    = Paperpile::Utils->get_browser;
    my $response   = $browser->get($bibtexurl);
    my $bibcontent = $response->content();
    if ( $bibcontent !~ m/<html>/ ) {
       my $f2 = Paperpile::Formats->new( format => 'BIBTEX' );
       $pub = $f2->read_string($bibcontent);
    }
  }

  return $pub;
}

1;
