
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


package Paperpile::MetaCrawler::Targets::Lancet;
use Moose;
use HTML::TreeBuilder;
use Paperpile::Utils;
use Paperpile::Formats;

extends 'Paperpile::MetaCrawler::Targets';

sub convert {

  my ( $self, $content ) = @_;

  my (
    $title,   $authors,    $journal,  $issue,     $volume,    $year, $month,
    $ISSN,    $pages,      $doi,      $abstract,  $booktitle, $url,  $pmid,
    $arxivid, $start_page, $end_page, $publisher, $series
  );


  # We parse the HTML via TreeBuilder
  my $tree = HTML::TreeBuilder->new;
  $tree->utf8_mode(1);
  $tree->parse_content($content);

  # title
  my @tags = $tree->look_down( '_tag' => 'h1', );
  $title = $tags[0]->as_text();

  # authors
  @tags = $tree->look_down( '_tag' => 'a', 'class' => 'ja50-ce-author' );
  my @authors_tmp = ();
  foreach my $entry (@tags) {
    push @authors_tmp, Paperpile::Library::Author->new()->parse_freestyle($entry->as_text)->bibtex();
  }
  $authors = join( " and ", @authors_tmp );

  # bibliogrpahic information
  @tags = $tree->look_down( '_tag' => 'div', 'id' => 'article_cite');
  if ( $tags[0]->as_text =~ m/(.*),\s+Volume\s+(\d+),\s+Issue\s+(\d+)\s*,\s+Pages\s(\d+)\s+-\s+(\d+),\s+\S+\s+(\d{4})/ ) {
    $journal = $1;
    $volume = $2;
    $issue = $3;
    $pages = "$4-$5";
    $year = $6;
  }
  if ( $tags[0]->as_text =~ m/(.*),\s+Volume\s+(\d+),\s+Issue\s+(\d+)\s*,\s+Page\s(\d+),\s+\S+\s+\S+\s+(\d{4})/ ) {
    $journal = $1;
    $volume = $2;
    $issue = $3;
    $pages = $4;
    $year = $5;
  }
  
  # DOI
  @tags = $tree->look_down( '_tag' => 'div', 'id' => 'article_DOI');
  if ( $tags[0]->as_text =~ m/doi:(\S+)\s*Cite.*/ ) {
    $doi = $1;
  }

  # Abstract
  @tags = $tree->look_down( '_tag' => 'div', 'class' => 'ja50-ce-abstract-section' );
  foreach my $tag (@tags) {
    ( my $tmp = $tag->as_HTML ) =~ s/\sclass="\S+"//g;
    $tmp =~ s/<\/?div>//g;
    $tmp =~ s/<h\d>/<b>/g;
    $tmp =~ s/<\/h\d>/<\/b> /g;
    $abstract .= $tmp;
  }

  # Fill publication object with data
  my $pub = Paperpile::Library::Publication->new( pubtype => 'ARTICLE' );

  $pub->journal($journal)     if $journal;
  $pub->series($series)       if $series;
  $pub->volume($volume)       if $volume;
  $pub->issue($issue)         if $issue;
  $pub->year($year)           if $year;
  $pub->month($month)         if $month;
  $pub->pages($pages)         if $pages;
  $pub->abstract($abstract)   if $abstract;
  $pub->title($title)         if $title;
  $pub->doi($doi)             if $doi;
  $pub->issn($ISSN)           if $ISSN;
  $pub->pmid($pmid)           if $pmid;
  $pub->eprint($arxivid)      if $arxivid;
  $pub->authors($authors)     if $authors;
  $pub->publisher($publisher) if $publisher;

  $tree->delete;

  return $pub;
}

1;
