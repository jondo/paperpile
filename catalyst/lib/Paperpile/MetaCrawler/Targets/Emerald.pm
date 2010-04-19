
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

package Paperpile::MetaCrawler::Targets::Emerald;
use Moose;
use HTML::TreeBuilder;
use Paperpile::Utils;
use Paperpile::Formats;

extends 'Paperpile::MetaCrawler::Targets';

sub convert {

  my ( $self, $content ) = @_;

  my (
    $title, $authors, $journal, $issue,      $volume,   $year,
    $month, $ISSN,    $pages,   $doi,        $abstract, $booktitle,
    $url,   $pmid,    $arxivid, $start_page, $end_page, $publisher,
      $series
  );

  my $type = 'ARTICLE';

  $content =~ s/&nbsp;/ /g;

  # We parse the HTML via TreeBuilder
  my $tree = HTML::TreeBuilder->new;
  $tree->utf8_mode(1);
  $tree->parse_content($content);

  my @tags = $tree->look_down( '_tag' => 'div', 'class' => 'toc' );
  if ( $tags[0] ) {

    if ( $tags[0]->as_text =~ m/(Title:\s)(.*)(\s?Author\(s\):.*)/ ) {
      $title = $2;
    }
    if ( $tags[0]->as_text =~ m/(.*Author\(s\):\s?)(.*)(\s?Journal:.*)/ ) {
      my @temp = split( /,/, $2 );
      my @authors_tmp = ();
      foreach my $entry (@temp) {
        push @authors_tmp, Paperpile::Library::Author->new()->parse_freestyle($entry)->bibtex();
      }
      $authors = join( " and ", @authors_tmp );
    }
    if ( $tags[0]->as_text =~ m/(.*Author\(s\):\s?)(.*)(\s?Book\sSeries:.*)/ ) {
      my @temp = split( /,/, $2 );
      my @authors_tmp = ();
      foreach my $entry (@temp) {
        push @authors_tmp, Paperpile::Library::Author->new()->parse_freestyle($entry)->bibtex();
      }
      $authors = join( " and ", @authors_tmp );
    }
    if ( $tags[0]->as_text =~ m/(.*Journal:\s?)(.*)(Year:.*)/ ) {
      $journal = $2;
    }
    if ( $tags[0]->as_text =~ m/(.*Book\sSeries:\s?)(.*)(Year:.*)/ ) {
      $series = $2;
      $type = 'INBOOK';
    }
    if ( $tags[0]->as_text =~ m/(.*Year:\s?)(\d+)(\s*Volume:.*)/ ) {
      $year = $2;
    }
    if ( $tags[0]->as_text =~ m/(.*Volume:\s?)(\d+)(\s?Issue:.*)/ ) {
      $volume = $2;
    }
    if ( $tags[0]->as_text =~ m/(.*Volume:\s?)(\d+)(\s?Page:.*)/ ) {
      $volume = $2;
    }
    if ( $tags[0]->as_text =~ m/(.*Issue:\s?)(\d+)(\s?Page:.*)/ ) {
      $issue = $2;
    }
    if ( $tags[0]->as_text =~ m/(.*Page:\s?)(\d+)(\s?-\s?)(\d+)(\s?DOI:.*)/ ) {
      $pages = "$2-$4";
    }
    if ( $tags[0]->as_text =~ m/(.*Page:\s?)(\d+)(\s?-\s?)(\d+)(\s?ISSN:.*)/ ) {
      $pages = "$2-$4";
    }
    if ( $tags[0]->as_text =~ m/(.*ISSN:\s?)([\d\-]+)(\s?DOI:.*)/ ) {
      $ISSN = $2;
    }
    if ( $tags[0]->as_text =~ m/(.*DOI:\s?)(.*)(\s?Chapter\sURL:.*)/ ) {
      $doi = $2;
    }
    if ( $tags[0]->as_text =~ m/(.*DOI:\s?)(.*)(Publisher:.*)/ and ! $doi ) {
      $doi = $2;
    }
    if ( $tags[0]->as_text =~ m/(.Publisher:\s)(.*)/ ) {
      $publisher = $2;
    }
  }

  # abstract
  @tags = $tree->look_down( '_tag' => 'div', 'id' => 'centerLeft' );
  if ( $tags[0] ) {
    if ( $tags[0]->as_text =~ m/(.*Abstract:\s)(.*)(Keywords:\s.*)/ ) {
      $abstract = $2;
    }

    if ( $tags[0]->as_text =~ m/(.*Abstract:\s)(.*)(Top.\sEmerald\sGroup\sPublishing\sLimited.*)/ and ! $abstract ) {
      $abstract = $2;
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
