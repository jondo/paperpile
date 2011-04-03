
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


package Paperpile::MetaCrawler::Targets::DovePress;
use Mouse;
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

  my $type = 'ARTICLE';

  $content =~ s/<sup>.{1,3}<\/sup>//g;

  # We parse the HTML via TreeBuilder
  my $tree = HTML::TreeBuilder->new;
  $tree->utf8_mode(1);
  $tree->parse_content($content);

  my @tags = $tree->look_down( '_tag' => 'span', 'class' => 'allowEm' );

  # title
  my @tmp = $tags[0]->look_down( '_tag' => 'h1' );
  $title = $tmp[0]->as_text();

  # bibliographic information
  @tmp = $tags[0]->look_down( '_tag' => 'h3' );
  if ( $tmp[0]->as_text() =~ m/.*Volume\s(\d+):(\d+).*/ ) {
    $volume = $2;
    $year   = $1;
  }
  @tmp = $tree->look_down( '_tag' => 'div', 'id' => 'breadcrumb' );
  if ( $tmp[0]->as_text() =~ m/(.*Journal:\s)(.*)/ ) {
    $journal = $2;
  }

  # authors and abstract
  @tmp = $tags[0]->look_down( '_tag' => 'p' );
  for my $i ( 0 .. $#tmp ) {
    if ( $i == 0 ) {
      my @temp = split( /,/, $tmp[$i]->as_text );
      my @authors_tmp = ();
      foreach my $entry (@temp) {
        push @authors_tmp, Paperpile::Library::Author->new()->parse_freestyle($entry)->bibtex();
      }
      $authors = join( " and ", @authors_tmp );
    }
    if ( $i > 1 ) {
      last if ( $tmp[$i]->as_text =~ m/^Keywords/ );
      $abstract .= $tmp[$i]->as_text."\n";
    }
  }

  # Fill publication object with data
  my $pub = Paperpile::Library::Publication->new( pubtype => $type );

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
