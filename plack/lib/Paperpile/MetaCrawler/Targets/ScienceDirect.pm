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


package Paperpile::MetaCrawler::Targets::ScienceDirect;
use Moose;
use HTML::TreeBuilder;
use Paperpile::Utils;
use Paperpile::Formats;
use Paperpile::Formats::Bibtex;

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

  # Let's try to parse the general bibliogrpahic information
  my @tags = $tree->look_down( '_tag' => 'div', 'class' => 'artiHead' );
  if ( $tags[0]->as_text =~
    m/(.*)\sVolume\s(\d+),\sIssues?\s([\d\-]+),\s(\d+)?\s?([A-Za-z]+)\s(\d{4}),\sPages\s(\d+-\d+).*/
    ) {
    $journal = $1;
    $volume  = $2;
    $issue   = $3;
    $month   = $5;
    $year    = $6;
    $pages   = $7;
  }

  # If we fail we follow the exportation link to the Bibtex
  if ( !$journal ) {
    $tree->delete;
    return _follow_links_to_bibtex($content);
  }

  # DOI
  @tags = $tree->look_down( '_tag' => 'a', 'target' => 'doilink' );
  if ( $tags[0]->as_text =~ m/^doi:(10.*)/ ) {
    $doi = $1;
  }

  # Title
  @tags = $tree->look_down( '_tag' => 'div', 'class' => 'articleTitle' );
  $title = $tags[0]->as_text;
  $title =~ s/^\s+//;

  # Abstract
  @tags = $tree->look_down( '_tag' => 'div', 'class' => 'articleText_indent' );
  foreach my $tag (@tags) {
    if ( $tag->as_text =~ m/^Abstract(.*)/ ) {
      $abstract = $1;
    }
  }

  # Authors
  @tags = $tree->look_down( '_tag' => 'div', 'id' => 'authorsAnchors' );
  if ( $#tags > -1 ) {
    my @tmp = $tags[0]->look_down( '_tag' => 'strong' );

    # We parse again the HTML, but get rid of <sup> tags before
    my $temp_content = $tmp[0]->as_HTML;
    $temp_content =~ s/<sup>.{0,9}<\/sup>//g;
    my $tree2 = HTML::TreeBuilder->new;
    $tree2->parse_content($temp_content);

    ( my $temp = $tree2->as_text ) =~ s/ and /,/;
    $temp =~ s/\s+,/,/g;
    $temp =~ s/\./. /g;
    $temp =~ s/\s+/ /g;
    $temp =~ s/,+/,/g;
    @tmp = split( /,/, $temp );
    my @authors_tmp = ();
    foreach my $entry (@tmp) {
      push @authors_tmp, Paperpile::Library::Author->new()->parse_freestyle($entry)->bibtex();
    }
    $authors = join( " and ", @authors_tmp );
    $tree2->delete;
  } else {

    # If we fail we follow the exportation link to the Bibtex
    $tree->delete;
    return _follow_links_to_bibtex($content);
  }

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

  return $pub;
}

sub _follow_links_to_bibtex {
  my $content = shift;

  my $export_link;
  if ( $content =~ m/a\shref="(\S+_ob=DownloadURL\S+)"\s/ ) {
    $export_link = "http://www.sciencedirect.com$1";
  }

  # Get abrowser and follow the export URL
  my $browser  = Paperpile::Utils->get_browser;
  my $response = $browser->get($export_link);

  # We parse the HTML via TreeBuilder
  my $tree = HTML::TreeBuilder->new;
  $tree->utf8_mode(1);
  $tree->parse_content( $response->content );

  # fill missing values with data from the form
  my $ob            = '_ob=DownloadURL';
  my $method        = '_method=finish';
  my $acct          = '_acct=';
  my $userid        = '_userid=';
  my $docType       = '_docType=FLA';
  my $uoikey        = '_uoikey=';
  my $count         = 'count=';
  my $md5           = 'md5=';
  my $JAVASCRIPT_ON = 'JAVASCRIPT_ON=Y';
  my $format        = 'format=cite-abs';
  my $type          = 'citation-type=BIBTEX';

  my $flag = 0;
  my @input_tags = $tree->look_down( '_tag' => 'input' );
  foreach my $tag (@input_tags) {
    next if ( !$tag->{name} );
    next if ( !$tag->{value} );
    $flag = 1 if ( $tag->{value} eq 'DownloadURL' );
    next if ( $flag == 0 );
    $acct   .= $tag->{value} if ( $tag->{name} eq '_acct' );
    $userid .= $tag->{value} if ( $tag->{name} eq '_userid' );
    $uoikey .= $tag->{value} if ( $tag->{name} eq '_uoikey' );
    $count  .= $tag->{value} if ( $tag->{name} eq 'count' );
    $md5    .= $tag->{value} if ( $tag->{name} eq 'md5' );
  }
  $tree->delete;

  # generate the Bibtex URL and call in th browser
  my $bibtex_url =
      'http://www.sciencedirect.com/science?' 
    . $ob . '&' 
    . $method . '&' 
    . $acct . '&' 
    . $userid . '&'
    . $docType . '&'
    . $uoikey . '&'
    . $count . '&'
    . $md5 . '&'
    . $JAVASCRIPT_ON . '&'
    . $format . '&'
    . $type;

  $response = $browser->get($bibtex_url);
  my $content_bibtex = $response->content;

  my $f = Paperpile::Formats::Bibtex->new();
  my $pub = $f->read_string($content_bibtex);

  return $pub->[0];
}
