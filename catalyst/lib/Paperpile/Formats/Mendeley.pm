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


1;

sub read {

  my $self = shift;
  my $file = $self->file;    # the mendeley sqlite db

  if ( !defined $file ) {
    FileFormatError->throw( error => "Could not find Mendeley sqlite database file." );
  }

  my @output = ();

  my %ignore_fields = (
    'id'              => 1,
    'confirmed'       => 1,
    'deletionPending' => 1,
    'favourite'       => 1,
    'read'            => 1,
    'type'            => 1,
    'uuid'            => 1,
    'added'           => 1,
    'modified'        => 1,
    'importer'        => 1,
    'privacy'         => 1
  );

  # get a DBI connection to the SQLite file
  my $dbh = DBI->connect( "dbi:SQLite:$file", '', '', { AutoCommit => 1, RaiseError => 1 } );

  # publications are stored in table 'Documents' and various related tables
  my $sth = $dbh->prepare("SELECT * FROM Documents;");
  $sth->execute();

  while ( my $row = $sth->fetchrow_hashref() ) {

    my %tmp = %{$row};

    # do not keep parsed references, that do not appear in the
    # library to the user
    next if ( $tmp{'onlyReference'} eq 'true' );

    # what we try to parse
    my (
      $title,   $authors, $journal, $issue,        $volume,    $year,
      $month,   $issn,    $pages,   $doi,          $abstract,  $booktitle,
      $url,     $pmid,    $arxivid, $editors,      $publisher, $edition,
      $series,  $address, $chapter, $organization, $linkout,   $local_pdfs,
      $citekey, $labels,    $note,    $howpublished, $isbn,      $keywords
    );

    my @unsupported_fields = ();

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

    my $pubtype = '';
    switch ( $tmp{'type'} ) {
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
        $pubtype = 'INBOOK';
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
        ( $howpublished = $tmp{'type'} ) =~ s/(.*[a-z])([A-Z].*)/$1 $2/;
      }
    }

    foreach my $key ( keys %tmp ) {

      # skip field if empty
      next if ( !$tmp{$key} );

      #print STDERR "$key: $tmp{$key}\n";

      my $supported = 0;
      switch ($key) {
        case 'title' {
          $title     = $tmp{$key};
          $supported = 1;
        }
        case 'abstract' {
          $abstract  = $tmp{$key};
          $supported = 1;
        }
        case 'arxivId' {
          $arxivid   = $tmp{$key};
          $supported = 1;
        }
        case 'doi' {
          $doi       = $tmp{$key};
          $supported = 1;
        }
        case 'edition' {
          $edition   = $tmp{$key};
          $supported = 1;
        }
        case 'issn' {
          $issn      = $tmp{$key};
          $supported = 1;
        }
        case 'isbn' {
          $isbn      = $tmp{$key};
          $supported = 1;
        }
        case 'issue' {
          $issue     = $tmp{$key};
          $supported = 1;
        }
        case 'month' {
          $month     = $tmp{$key};
          $supported = 1;
        }
        case 'pages' {
          $pages     = $tmp{$key};
          $supported = 1;
        }
        case 'pmid' {
          $pmid      = $tmp{$key};
          $supported = 1;
        }
        case 'publication' {
          $journal   = $tmp{$key};
          $supported = 1;
        }
        case 'volume' {
          $volume    = $tmp{$key};
          $supported = 1;
        }
        case 'year' {
          $year      = $tmp{$key};
          $supported = 1;
        }
        case 'series' {
          $series    = $tmp{$key};
          $supported = 1;
        }
        case 'institution' {
          $organization = $tmp{$key};
          $supported    = 1;
        }
        case 'publisher' {
          $publisher = $tmp{$key};
          $supported = 1;
        }
      }

      if ( !defined $ignore_fields{$key} and $supported == 0 ) {
        push @unsupported_fields, "Mendeley field \"$key\": $tmp{$key}";
      }

    }

    # get keywords
    my $sth2 = $dbh->prepare("SELECT keyword FROM DocumentKeywords WHERE documentId=?;");
    $sth2->execute( $tmp{'id'} );
    my @keywords_tmp = ();
    while ( my @tmp = $sth2->fetchrow_array ) {
      push @keywords_tmp, $tmp[0];
    }
    $keywords = join( ";", @keywords_tmp );

    # get authors
    my @tmpauthors = ();
    my @tmpeditors = ();
    my $sth3 =
      $dbh->prepare( 'SELECT contribution, lastName || ", " || firstNames '
        . 'FROM DocumentContributors '
        . 'WHERE documentId=?;' );
    $sth3->execute( $tmp{'id'} );
    while ( my @t = $sth3->fetchrow_array ) {
      if ( $t[0] eq 'DocumentEditor' ) {
        push @tmpeditors, $t[1] if ( $t[1] );
      } else {    # e.g. 'DocumentAuthor'
        push @tmpauthors, $t[1] if ( $t[1] );
      }
    }

    if (@tmpauthors) {
      $authors = join( " and ", @tmpauthors );
      $authors =~ s/\s+/ /g;
    }
    if (@tmpeditors) {
      $editors = join( " and ", @tmpeditors );
      $editors =~ s/\s+/ /g;
    }

    # get link_out
    my $sth4 = $dbh->prepare('SELECT url FROM DocumentUrls WHERE documentId=?;');
    $sth4->execute( $tmp{'id'} );
    if ( my @t = $sth4->fetchrow_array ) {    # guess only one
      $linkout = $t[0];
    }

    # get PDF and attachments; use first PDF in database as PDF file
    # and store the rest as supplementary files
    my $sth5 =
      $dbh->prepare( 'SELECT localUrl '
        . 'FROM DocumentFiles d, Files f '
        . 'WHERE d.documentId=? AND d.hash=f.hash ORDER BY d.rowid ASC' );
    $sth5->execute( $tmp{'id'} );
    my @attachments = ();
    my @pdfs        = ();
    while ( my @t = $sth5->fetchrow_array ) {
      my $file = Paperpile::Utils->process_attachment_name( $t[0] );
      next if !$file;

      if ( $file =~ /\.pdf$/i && !@pdfs ) {
        push @pdfs, $file;
      } else {
        push @attachments, $file;
      }
    }
    $local_pdfs = join( ";", @pdfs ) if (@pdfs);

    # get tags as comma separated list
    my $sth6 = $dbh->prepare('SELECT tag FROM DocumentTags WHERE documentId=?');
    $sth6->execute( $tmp{'id'} );
    my @labels = ();
    while ( my @t = $sth6->fetchrow_array ) {
      push @labels, $t[0];
    }
    $labels = join( ",", @labels );

    # add unsupported fields to note tag
    $note .= "<br />\n".join("<br />\n", @unsupported_fields)."<br />\n" if ( $#unsupported_fields  > -1 and $note);
    $note = join("<br />\n", @unsupported_fields)."<br />\n" if ( $#unsupported_fields > -1 and !$note);

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
    $pub->isbn($isbn)                 if $isbn;
    $pub->pmid($pmid)                 if $pmid;
    $pub->arxivid($arxivid)           if $arxivid;
    $pub->authors($authors)           if $authors;
    $pub->editors($editors)           if $editors;
    $pub->edition($edition)           if $edition;
    $pub->series($series)             if $series;
    $pub->booktitle($booktitle)       if $booktitle;
    $pub->organization($organization) if $organization;
    $pub->linkout($linkout)           if $linkout;
    $pub->keywords($keywords)         if $keywords;
    $pub->_pdf_tmp($local_pdfs)       if $local_pdfs;
    $pub->{_attachments_tmp} = [@attachments] if ( @attachments > 0 );
    $pub->labels($labels)                 if $labels;
    $pub->note($note)                 if $note;
    $pub->howpublished($howpublished) if $howpublished;

    push @output, $pub;
  }

  $dbh->disconnect;

  return [@output];

}
