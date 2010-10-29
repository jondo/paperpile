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


package Paperpile::Formats::HTML;
use Moose;
use Paperpile::Utils;
use HTML::TreeBuilder::XPath;
use Paperpile::Library::Author;
use Switch;

extends 'Paperpile::Formats';

has 'content' => ( is => 'rw', isa => 'Str', default => '' );

sub BUILD {
  my $self = shift;
  $self->format('HTML');
  $self->readable(1);
  $self->writable(0);
}

sub read {

  my $self = shift;

  my $content = $self->content;

  my (
    $title, $authors, $journal, $issue,      $volume,   $year,
    $month, $ISSN,    $pages,   $doi,        $abstract, $booktitle,
    $url,   $pmid,    $arxivid, $start_page, $end_page, $publisher
  );

  my @authors_creator     = ();
  my @authors_contributor = ();
  my @authors_citation    = ();

  # We parse the HTML via XPath
  my $tree = HTML::TreeBuilder::XPath->new;
  $tree->utf8_mode(1);
  $tree->parse_content($content);

  my @meta = $tree->findnodes('/html/head/meta');
  foreach my $tag (@meta) {
    if ( $tag->attr('name') ) {
      my $name    = uc( $tag->attr('name') );
      my $content = $tag->attr('content');
      next if ( $content eq '' );

      #print STDERR "$name ==> $content\n";

      switch ($name) {
        case "DC.TITLE" { $title = $content }
        case "DC.CREATOR" {
          $content =~ s/\./. /g;
          $content =~ s/\s+/ /g;

          # reverse string if necessary
          if ( $content =~ m/\s[A-Z]{1,2}$/ and $content !~ m/,/ ) {
            my @tmp_author = split( /\s/, $content );
            $content = join( ' ', reverse(@tmp_author) );
          }

          my $tmp =
            ( $content =~ m/,/ )
            ? $content
            : Paperpile::Library::Author->new()->parse_freestyle($content)->bibtex();
          push @authors_creator, $tmp;

        }
        case "DC.CREATOR.PERSONALNAME" {
          $content =~ s/\./. /g;
          $content =~ s/\s+/ /g;

          # reverse string if necessary
          if ( $content =~ m/\s[A-Z]{1,2}$/ and $content !~ m/,/ ) {
            my @tmp_author = split( /\s/, $content );
            $content = join( ' ', reverse(@tmp_author) );
          }

          my $tmp =
            ( $content =~ m/,/ )
            ? $content
            : Paperpile::Library::Author->new()->parse_freestyle($content)->bibtex();
          push @authors_creator, $tmp;

        }
        case "DC.CONTRIBUTOR" {
          $content =~ s/\./. /g;
          $content =~ s/\s+/ /g;

          # reverse string if necessary
          if ( $content =~ m/\s[A-Z]{1,2}$/ and $content !~ m/,/ ) {
            my @tmp_author = split( /\s/, $content );
            $content = join( ' ', reverse(@tmp_author) );
          }

          my $tmp =
            ( $content =~ m/,/ )
            ? $content
            : Paperpile::Library::Author->new()->parse_freestyle($content)->bibtex();
          push @authors_contributor, $tmp;
        }
        case "DC.IDENTIFIER" {
          if ( $content =~ m/^10\./ ) {
            $doi = $content;
          } elsif ( $content =~ m/(.*)(10\.\d{4}.+)/ ) {
            $doi = $2;
          }
        }
        case "DC.DATE" {
          if ( $content =~ m/(\d{4})-(\d{1,2})-(\d{1,2})/ ) {
            $year  = $1 if ( !$year );
            $month = $2 if ( !$month );
          }
          if ( $content =~ m/(\d{1,2})\/(\d{1,2})\/(\d{4})/ ) {
            $year  = $3 if ( !$year );
            $month = $1 if ( !$month );
          }
          if ( $content =~ m/(^\d{4})-(\d{1,2})$/ ) {
            $year  = $1 if ( !$year );
            $month = $2 if ( !$month );
          }
        }
        case "DC.DESCRIPTION" { $abstract = $content }
        case "DC.SOURCE" {
          if ( $content =~ m/(.*),\sVol\.\s(\d+),\sIssue\s(\d+),\spp\.\s(\d+)-(\d+)/ ) {
            $journal    = $1 if ( !$journal );
            $volume     = $2 if ( !$volume );
            $issue      = $3 if ( !$issue );
            $start_page = $4 if ( !$start_page );
            $end_page   = $5 if ( !$end_page );
          }

        }
        case "DC.SOURCE.ISSUE"  { $issue  = $content }
        case "DC.SOURCE.VOLUME" { $volume = $content }

        case "PRISM.PUBLICATIONNAME" { $journal = $content }
        case "PRISM.VOLUME"          { $volume  = $content }
        case "PRISM.NUMBER"          { $issue   = $content }
        case "PRISM.ISSN"            { $ISSN    = $content }
        case "PRISM.PUBLICATIONDATE" {
          if ( $content =~ m/(\d{4})-(\d{1,2})-(\d{1,2})/ ) {
            $year  = $1;
            $month = $2;
          }
          if ( $content =~ m/(\d{1,2})\/(\d{1,2})\/(\d{4})/ ) {
            $year  = $3;
            $month = $1;
          }
        }
        case "PRISM.STARTINGPAGE"     { $start_page = $content }
        case "PRISM.ENDINGPAGE"       { $end_page   = $content }
        case "CITATION_TITLE"         { $title      = $content if ( !$title ) }
        case "CITATION_JOURNAL_TITLE" { $journal    = $content if ( !$journal ) }
	case "CITATION_CONFERENCE"    { $journal    = $content if ( !$journal ) }
        case "CITATION_VOLUME"        { $volume     = $content if ( !$volume ) }
        case "CITATION_ISSUE"         { $issue      = $content if ( !$issue ) }
        case "CITATION_FIRSTPAGE"     { $start_page = $content if ( !$start_page ) }
        case "CITATION_LASTPAGE"      { $end_page   = $content if ( !$end_page ) }
        case "CITATION_ISSN"          { $ISSN       = $content if ( !$ISSN ) }
        case "CITATION_DOI" {

          if ( $content =~ m/^10\./ ) {
            $doi = $content if ( !$doi );
          } elsif ( $content =~ m/(.*)(10\.\d{4}.+)/ ) {
            $doi = $2 if ( !$doi );
          }
        }
        case "CITATION_FULLTEXT_HTML_URL" { $url              = $content }
        case "CITATION_ABSTRACT_HTML_URL" { $url              = $content if ( !$url ) }
        case "CITATION_PMID"              { $pmid             = $content }
        case "CITATION_PUBLISHER"         { $publisher        = $content if ( !$publisher ) }
        case "CITATION_AUTHORS"           { push @authors_citation, $content }
        case "CITATION_ABSTRACT"          { $abstract         = $content if ( !$abstract ) }
        case "CITATION_DATE" {

          if ( $content =~ m/(\d{4})-(\d{1,2})-(\d{1,2})/ ) {
            $year  = $1 if ( !$year );
            $month = $2 if ( !$month );
          }
          if ( $content =~ m/(\d{1,2})\/(\d{1,2})\/(\d{4})/ ) {
            $year  = $3 if ( !$year );
            $month = $1 if ( !$month );
          }
          if ( $content =~ m/^(\d{4})\s[A-Z]\w.*/ ) {
            $year = $1 if ( !$year );
          }
        }
        case "CITATION_YEAR" { $year = $content if ( $content =~ m/^\d+$/ and !$year ) }

        case "RFT_JTITLE" { $journal   = $content if ( !$journal ) }
        case "RFT_ATITLE" { $title     = $content if ( !$title ) }
        case "RFT_ISSN"   { $ISSN      = $content if ( !$ISSN ) }
        case "RFT_PUB"    { $publisher = $content if ( !$publisher ) }
        case "RFT_DATE" {
          if ( $content =~ m/(\d{4})-(\d{1,2})-(\d{1,2})/ ) {
            $year  = $1 if ( !$year );
            $month = $2 if ( !$month );
          }
          if ( $content =~ m/(\d{1,2})\/(\d{1,2})\/(\d{4})/ ) {
            $year  = $3 if ( !$year );
            $month = $1 if ( !$month );
          }
        }
        case "RFT_ID" {
          if ( $content =~ m/(.*)(10\.\d{4}.+)/ ) {
            $doi = $2 if ( !$doi );
          }
        }
        case "PPL.VOLUME"    { $volume     = $content if ( !$volume ) }
        case "PPL.ISSUE"     { $issue      = $content if ( !$issue and $content > 0 ) }
        case "PPL.FIRSTPAGE" { $start_page = $content if ( !$start_page ) }
        case "PPL.LASTPAGE"  { $end_page   = $content if ( !$end_page ) }
        case "PPL.DOI" {
          if ( $content =~ m/^10\./ ) {
            $doi = $content if ( !$doi );
          } elsif ( $content =~ m/(.*)(10\.\d{4}.+)/ ) {
            $doi = $2 if ( !$doi );
          }
        }
        case "DCTERMS.BIBLIOGRAPHICCITATION" {
          if ( $content =~ m/([A-Za-z\.\s]+),\s(\d+),\s(\d+),\s(\d+)-(\d+)/ ) {
            $journal    = $1 if ( !$journal );
            $volume     = $2 if ( !$volume );
            $issue      = $3 if ( !$issue );
            $start_page = $4 if ( !$start_page );
            $end_page   = $5 if ( !$end_page );
          }

        }
        case "DCTERMS.ISSUED" {
          if ( $content =~ m/(.*\s)(\d\d\d\d)$/ ) {
            $year = $2 if ( !$year );
          }
        }
      }

      # control each tag content if DOI hides
      if ( $content =~ m/(.*doi:?)(10\.\d\d\d\d.\S+)(\s.*)?/i ) {
        $doi = $2 if ( !$doi );
      }
    }
  }

  # Not found anything till now
  if ( !$title or !$journal ) {
    foreach my $tag (@meta) {
      if ( $tag->attr('name') ) {
        my $name    = uc( $tag->attr('name') );
        my $content = $tag->attr('content');
        next if ( $content eq '' );

        switch ($name) {
          case /.*CITATION_TITLE/         { $title      = $content if ( !$title ) }
          case /.*CITATION_JOURNAL_TITLE/ { $journal    = $content if ( !$journal ) }
          case /.*CITATION_VOLUME/        { $volume     = $content if ( !$volume ) }
          case /.*CITATION_ISSUE/         { $issue      = $content if ( !$issue ) }
          case /.*ISSUE/                  { $issue      = $content if ( !$issue ) }
          case /.*NUMBER/                 { $issue      = $content if ( !$issue ) }
          case /.*VOLUME/                 { $volume     = $content if ( !$volume ) }
          case /.*CITATION_FIRSTPAGE/     { $start_page = $content if ( !$start_page ) }
          case /.*CITATION_LASTPAGE/      { $end_page   = $content if ( !$end_page ) }
          case /.*CITATION_ISSN/          { $ISSN       = $content if ( !$ISSN ) }
          case /.*ISSN/                   { $ISSN       = $content if ( !$ISSN ) }
          case /.*CITATION_DOI/ {

            if ( $content =~ m/^10\./ ) {
              $doi = $content if ( !$doi );
            } elsif ( $content =~ m/(.*)(10\.\d{4}.+)/ ) {
              $doi = $2 if ( !$doi );
            }
          }
          case /.*CITATION_FULLTEXT_HTML_URL/ { $url              = $content }
          case /.*CITATION_ABSTRACT_HTML_URL/ { $url              = $content if ( !$url ) }
          case /.*CITATION_PMID/              { $pmid             = $content }
          case /.*CITATION_PUBLISHER/         { $publisher        = $content if ( !$publisher ) }
          case /.*CITATION_AUTHORS/           { push @authors_citation, $content }
          case /.*CITATION_ABSTRACT/          { $abstract         = $content if ( !$abstract ) }
          case /.*CITATION_DATE/ {

            if ( $content =~ m/(\d{4})-(\d{1,2})-(\d{1,2})/ ) {
              $year  = $1 if ( !$year );
              $month = $2 if ( !$month );
            }
            if ( $content =~ m/(\d{1,2})\/(\d{1,2})\/(\d{4})/ ) {
              $year  = $3 if ( !$year );
              $month = $1 if ( !$month );
            }
            if ( $content =~ m/^(\d{4})\s[A-Z]\w.*/ ) {
              $year = $1 if ( !$year );
            }
          }
          case /.*CITATION_YEAR/ { $year = $content if ( $content =~ m/^\d+$/ and !$year ) }

        }
      }
    }
  }

  if ($title) {
    $title =~ s/\n//g;
    $title =~ s/\t//g;
  }

  #if ( $content =~ m/"Z3988"\stitle="(\S+)"/ ) {
  #  print STDERR "AAAAA $1\n";
  #}

  $authors = join( " and ", @authors_creator );
  $authors = join( " and ", @authors_contributor ) if ( $authors eq '' );

  if ( $authors eq '' and $#authors_citation > -1 ) {
    if ( $#authors_citation == 0 ) {
      if ( $authors_citation[0] =~ m/;/ and $authors_citation[0] =~ m/,/ ) {
	$authors_citation[0] =~ s/;/ and /g;
	$authors_citation[0] =~ s/\s+/ /g;
	$authors = $authors_citation[0];
      } elsif ( $authors_citation[0] !~ m/;/ and $authors_citation[0] =~ m/,/ ) {
	my @tmp = split( /,/, $authors_citation[0] );
	@authors_creator = ( );
	foreach my $entry (@tmp) {
	  push @authors_creator, Paperpile::Library::Author->new()->parse_freestyle($entry)->bibtex();
	}
	$authors = join( " and ", @authors_creator );
      }
    } else {
      # more than one entry
      @authors_creator = ( );
      foreach my $entry (@authors_citation) {
	my $count = ($entry =~ tr/,//);
	if ( $count == 0 ) {
	  push @authors_creator, Paperpile::Library::Author->new()->parse_freestyle($entry)->bibtex();
	} elsif ( $count == 1 ) {
	  push @authors_creator, $entry;
	} else {
	  # I do not know if this case exists
	}
      }
      $authors = join( " and ", @authors_creator );
    }
  }

  if ( $authors ne '' ) {
    $authors =~ s/\s+/ /g;
  }

  if ( $start_page and $end_page ) {
    $pages = "$start_page-$end_page";
  }
  if ( $start_page and !$end_page ) {
    $pages = "$start_page";
  }

  if ($volume) {
    if ( $volume =~ m/^\d+$/ ) {
      $volume = undef if ( $volume < 1 );
    }
  }

  if ($issue) {
    if ( $issue =~ m/^\d+$/ ) {
      $issue = undef if ( $issue < 1 );
    }
  }

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

  return $pub;
}

1;
