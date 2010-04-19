
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

package Paperpile::MetaCrawler::Targets::LandesBioScience;
use Moose;
use HTML::TreeBuilder;
use Paperpile::Utils;

extends 'Paperpile::MetaCrawler::Targets';

sub convert {

  my ( $self, $content ) = @_;

  my (
    $title, $authors, $journal, $issue,      $volume,   $year,
    $month, $ISSN,    $pages,   $doi,        $abstract, $booktitle,
    $url,   $pmid,    $arxivid, $start_page, $end_page, $publisher
  );

  # We parse the HTML via TreeBuilder
  my $tree = HTML::TreeBuilder->new;
  $tree->utf8_mode(1);
  $tree->parse_content($content);

  # title
  my @tags = $tree->look_down( '_tag' => 'h2', 'id' => 'article_title' );
  $title = $tags[0]->as_text;

  # authors
  @tags = $tree->look_down( '_tag' => 'h5', 'class' => 'short' );
  ( my $tmp = $tags[0]->as_text ) =~ s/\sand\s/,/;
  my @temp = split( /\s*,\s*/, $tmp );
  my @authors_tmp = ();
  foreach my $entry (@temp) {
    push @authors_tmp, Paperpile::Library::Author->new()->parse_freestyle($entry)->bibtex();
  }
  $authors = join( " and ", @authors_tmp );

  # bibliographic information
  @tags = $tree->look_down( '_tag' => 'input', 'type' => 'hidden' );
  foreach my $tag (@tags) {
    $volume  = $tag->{value} if ( $tag->{id} eq 'volume' );
    $issue   = $tag->{value} if ( $tag->{id} eq 'issue' );
    $journal = $tag->{value} if ( $tag->{id} eq 'journal_name' );
    $url     = $tag->{value} if ( $tag->{id} eq 'article_url' );
  }
  @tags = $tree->look_down( '_tag' => 'div', 'class' => 'landes_content_center' );
  if ( $tags[0]->as_text =~
    m/.*(January|February|March|April|May|June|July|August|September|October|Novermber|December)\s(\d\d\d\d).*/
    ) {
    $year = $2;
  }
  if ( $tags[0]->as_text =~ m/.*Pages\s(\d+)\s*-\s*(\d+).*/ ) {
    $pages = "$1-$2";
  }

  # abstract
  @tags = $tree->look_down( '_tag' => 'p', 'id' => 'abstract' );
  $abstract = $tags[0]->as_text;

  # Fill publication object with data
  my $pub = Paperpile::Library::Publication->new( pubtype => 'ARTICLE' );

  $pub->journal($journal)     if $journal;
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

  return undef if ( ! $title );

  return $pub;
}

