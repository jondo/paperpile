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

package Paperpile::Formats::Mendeley;
use Moose;
use DBI;
use Switch;

extends 'Paperpile::Formats';

sub BUILD {
  my $self = shift;
  $self->format('MENDELEY');
  $self->readable(1);
  $self->writable(0);
}

sub read {

  my $self = shift;
  my $file = $self->file;

  if ( !defined $file ) {
    FileFormatError->throw(
      error => "Could not
    find Mendeley sqllite database file."
    );
  }

  #( my $path = $file ) =~ s/zotero\.sqlite$//;

  my @output = ();

  # get a DBI connection to the SQLite file
  my $dbh = DBI->connect( "dbi:SQLite:$file", '', '', { AutoCommit => 1, RaiseError => 1 } );

  # publications are stored in table 'Documents' and various related tables
  my $sth = $dbh->prepare("SELECT * FROM Documents;");
  $sth->execute();
  while ( my @tmp = $sth->fetchrow_array ) {

    # what we try to parse
    my (
      $title,   $authors, $journal, $issue,        $volume,    $year,
      $month,   $issn,    $pages,   $doi,          $abstract,  $booktitle,
      $url,     $pmid,    $arxivid, $editors,      $publisher, $edition,
      $series,  $address, $chapter, $organization, $linkout,   $local_pdfs,
      $citekey, $tags,    $note
    );

    ############################################
    # mendeley types:      ->   paperpile types:
    ############################################
    # Bill                    MISC
    # Book                    BOOK
    # BookSection             INBOOK
    # Case                    MISC
    # ComputerProgram         MISC
    # ConferenceProceedings   PROCEEDINGS
    # EncyclopediaArticle     MISC
    # Film                    MISC
    # Generic                 MISC
    # Hearing                 MISC
    # JournalArticle          ARTICLE
    # MagazineArticle         ARTICLE
    # NewspaperArticle        ARTICLE
    # Patent                  MISC
    # Report                  TECHREPORT
    # Statute                 MISC
    # TelevisionBroadcast     MISC
    # Thesis                  PHDTHESIS or PHDTHESIS (TODO: which?)
    # WebPage                 MISC
    # WorkingPaper            UNPUBLISHED

    my $pubtype       = '';
    my $mend_id       = $tmp[0];
    my $mend_itemType = $tmp[6];

    switch ($mend_itemType) {
      case 'JournalArticle' {
        $pubtype = 'ARTICLE';
      }
      case 'MagazineArticle' {
        $pubtype = 'ARTICLE';
      }
      case 'NewspaperArticle' {
        $pubtype = 'ARTICLE';
      }
      case 'Book' {
        $pubtype = 'BOOK';
      }
      case 'BookSection' {
        $pubtype   = 'INBOOK';
        $booktitle = $tmp[53];    # 53 = publication
      }
      case 'ConferenceProceedings' {
        $pubtype = 'PROCEEDINGS';
      }
      case 'Report' {
        $pubtype = 'TECHREPORT';
      }
      case 'Thesis' {
        $pubtype = 'PHDTHESIS';
      }
      case 'WorkingPaper' {
        $pubtype = 'UNPUBLISHED';
      }
      else {
        $pubtype = 'MISC';
      }
    }

    $abstract     = $tmp[8];
    $note         = $tmp[12];
    $title        = $tmp[14];
    $arxivid      = $tmp[18];
    $chapter      = $tmp[19];
    $citekey      = $tmp[20];
    $doi          = $tmp[31];
    $edition      = $tmp[32];
    $organization = $tmp[35];
    $issn         = $tmp[41];
    $issue        = $tmp[42];
    $month        = $tmp[48];
    $pages        = $tmp[51];
    $pmid         = $tmp[52];
    $journal      = $tmp[53];
    $series       = $tmp[61];
    $volume       = $tmp[67];
    $year         = $tmp[68];

    # TODO: get keywords
    # my $sth2 = $dbh->prepare("
    # SELECT keyword FROM DocumentKeywords WHERE documentId=$mend_id;");
    # $sth2->execute();
    # while ( my @tmp = $sth2->fetchrow_array ) {
    #  $keywords .= $tmp[0]" ";
    # }

    # get authors
    my @tmpauthors = ();
    my @tmpeditors = ();
    my $sth3 =
      $dbh->prepare( 'SELECT contribution, lastName || ", " || firstNames '
        . 'FROM DocumentContributors '
        . 'WHERE documentId=?;' );
    $sth3->execute($mend_id);
    while ( my @t = $sth3->fetchrow_array ) {
      if ( $t[0] eq 'DocumentEditor' ) {
        push @tmpeditors, $t[1] if ( $t[1] );
      } else {    # e.g. 'DocumentAuthor'
        push @tmpauthors, $t[1] if ( $t[1] );
      }
    }

    if ( scalar @tmpauthors > 1 ) {
      $authors = join( " and ", @tmpauthors );
      $authors =~ s/\s+/ /g;
    }
    if ( scalar @tmpeditors > 1 ) {
      $editors = join( " and ", @tmpeditors );
      $editors =~ s/\s+/ /g;
    }

    # get link_out
    my $sth4 = $dbh->prepare('SELECT url FROM DocumentUrls WHERE documentId=?;');
    $sth4->execute($mend_id);
    if ( my @t = $sth4->fetchrow_array ) {    # guess only one
      $linkout = $t[0];
    }

    # get local PDF and attachments
    # result should be :/home/wash/PDFs/file.pdf:PDF
    # problem for attachments: it is not known
    # which PDF is the actual paper and which files are just attachments
    # Mendeley does not distinguish...
    # maybe we have to parse the PDFs again?
    my $sth5 = $dbh->prepare(
      'SELECT localUrl FROM DocumentFiles d, Files f ' . 'WHERE d.documentId=? AND d.hash=f.hash' );
    $sth5->execute($mend_id);
    my @attachments = ();
    my @pdfs        = ();
    while ( my @t = $sth5->fetchrow_array ) {
      $t[0] =~ s/^file\:\/\//\:/g;
      if ( $t[0] =~ /\.pdf$/i ) {
        $t[0] .= ':PDF';
        push @pdfs, $t[0];
      } else {
        push @attachments, $t[0];
      }
    }
    $local_pdfs = join( ";", @pdfs ) if ( scalar @pdfs > 1 );

    # get tags as comma separated list
    my $sth6 = $dbh->prepare('SELECT tag FROM DocumentTags WHERE documentId=?');
    $sth6->execute($mend_id);
    my @tags = ();
    while ( my @t = $sth6->fetchrow_array ) {
      push @tags, $t[0];
    }
    $tags = join( ",", @tags );

    # create publication object
    my $pub = Paperpile::Library::Publication->new( pubtype => $pubtype );

    $pub->citekey($citekey)           if $citekey;
    $pub->journal($journal)           if $journal;
    $pub->volume($volume)             if $volume;
    $pub->chapter($chapter)           if $chapter;
    $pub->issue($issue)               if $issue;
    $pub->year($year)                 if $year;
    $pub->month($month)               if $month;
    $pub->pages($pages)               if $pages;
    $pub->abstract($abstract)         if $abstract;
    $pub->title($title)               if $title;
    $pub->doi($doi)                   if $doi;
    $pub->issn($issn)                 if $issn;
    $pub->pmid($pmid)                 if $pmid;
    $pub->eprint($arxivid)            if $arxivid;
    $pub->authors($authors)           if $authors;
    $pub->editors($editors)           if $editors;
    $pub->edition($edition)           if $edition;
    $pub->series($series)             if $series;
    $pub->booktitle($booktitle)       if $booktitle;
    $pub->organization($organization) if $organization;
    $pub->linkout($linkout)           if $linkout;
    $pub->_pdf_tmp($local_pdfs)       if $local_pdfs;
    $pub->{_attachments_tmp} = [@attachments] if (@attachments);
    $pub->tags($tags) if $tags;
    $pub->note($note) if $note;

    push @output, $pub;
  }

  $dbh->disconnect;

  return [@output];

}

1;

