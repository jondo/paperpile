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

package Paperpile::Formats::Zotero;
use Moose;
use DBI;
use Paperpile::Utils;

extends 'Paperpile::Formats';

sub BUILD {
  my $self = shift;
  $self->format('ZOTERO');
  $self->readable(1);
  $self->writable(0);
}

sub read {

  my $self = shift;

  my $file = $self->file;

  if ( !defined $file ) {
    FileFormatError->throw( error => "Could not find Zotero database file (zotero.sqlite)." );
  }

  ( my $path = $file ) =~ s/zotero\.sqlite$//;

  my @output = ();

  # get a DBI connection to the SQLite file
  my $dbh = DBI->connect( "dbi:SQLite:$file", '', '', { AutoCommit => 1, RaiseError => 1 } );

  # publications are stored in table items
  my $sth = $dbh->prepare("SELECT * FROM items;");
  $sth->execute();
  while ( my @tmp = $sth->fetchrow_array ) {
    my $itemID     = $tmp[0];
    my $itemTypeID = $tmp[1];

    # We do not proccess attachements at this stage
    next if ( $itemTypeID == 14 );

    # We do not process notes at this sages
    next if ( $itemTypeID == 1 );

    # check if deleted
    my $sth_deleted = $dbh->prepare("SELECT * FROM deletedItems WHERE itemID=?;");
    $sth_deleted->execute($itemID);
    my $flag_deleted = 0;
    while ( my @tmp_deleted = $sth_deleted->fetchrow_array ) {
      $flag_deleted = 1;
    }
    next if ( $flag_deleted == 1 );

    # Values/Key pairs for itemTypeID
    # 1 note             2 book                 3 bookSection
    # 4 journalArticle   5 magazineArticle      6 newspaperArticle
    # 7 thesis           8 letter               9 manuscript
    #10 interview       11 film                12 artwork
    #13 webpage         14 attachment          15 report
    #16 bill            17 case                18 hearing
    #19 patent          20 statute             21 email
    #22 map             23 blogPost            24 instantMessage
    #25 forumPost       26 audioRecording      27 presentation
    #28 videoRecording  29 tvBroadcast         30 radioBroadcast
    #31 podcast         32 computerProgram     33 conferencePaper
    #34 document        35 encyclopediaArticle 36 dictionaryEntry

    my (
      $title,  $authors, $journal, $issue,        $volume,    $year,
      $month,  $ISSN,    $pages,   $doi,          $abstract,  $booktitle,
      $url,    $pmid,    $arxivid, $editors,      $publisher, $edition,
      $series, $address, $school,  $howpublished, $note,      $isbn
    );

    my @pdfs                 = ();
    my @snapshots            = ();
    my @regular_attachements = ();
    my @notes_dummy          = ();

    # now we gather data for each itemID
    my $sth2 = $dbh->prepare("SELECT * FROM itemData WHERE itemID=?;");
    $sth2->execute($itemID);
    while ( my @tmp2 = $sth2->fetchrow_array ) {
      my $fieldID = $tmp2[1];
      my $valueID = $tmp2[2];

      #print "$fieldID,$valueID\n";

      # Values/Key pairs for fieldID
      #  1 *url                  2 rights             3 *series
      #  4 *volume               5 *issue             6 *edition
      #  7 *place                8 *publisher        10 *pages
      # 11 *ISBN                12 *publicationTitle 13 *ISSN
      # 14 date                 15 section           18 callNumber
      # 19 archiveLocation      21 distributor       22 *extra
      # 25 *journalAbbreviation 26 *DOI              27 accessDate
      # 28 *seriesTitle         29 seriesText        30 seriesNumber
      # 31 *institution         32 reportType        36 code
      # 40 session              41 legislativeBody   42 history
      # 43 reporter             44 court             45 numberOfVolumes
      # 46 committee            48 assignee          50 patentNumber
      # 51 priorityNumbers      52 issueDate         53 references
      # 54 legalStatus          55 codeNumber        59 artworkMedium
      # 60 number               61 artworkSize       62 repository
      # 63 videoRecordingType   64 interviewMedium   65 letterType
      # 66 manuscriptType       67 mapType           68 scale
      # 69 thesisType           70 websiteType       71 audioRecordingType
      # 72 label                74 presentationType  75 meetingName
      # 76 studio               77 runningTime       78 network
      # 79 postType             80 audioFileType     81 version
      # 82 system               83 company           84 conferenceName
      # 85 *encyclopediaTitle   86 *dictionaryTitle  87 language
      # 88 programmingLanguage  89 *university       90 *abstractNote
      # 91 *websiteTitle        92 reportNumber      93 billNumber
      # 94 codeVolume           95 codePages         96 dateDecided
      # 97 reporterVolume       98 firstPage         99 documentNumber
      #100 dateEnacted         101 publicLawNumber  102 country
      #103 applicationNumber   104 *forumTitle      105 episodeNumber
      #107 *blogTitle          108 type             109 medium
      #110 *title              111 caseName         112 nameOfAct
      #113 subject             114 proceedingsTitle 115 *bookTitle
      #116 shortTitle          117 docketNumber     118 numPages
      #119 programTitle        120 issuingAuthority 121 filingDate
      #122 genre               123 archive

      my %unsupported = (
        '2'   => 'rights',
        '14'  => 'date',
        '15'  => 'section',
        '18'  => 'callNumber',
        '19'  => 'archiveLocation',
        '21'  => 'distributor',
        '22'  => 'extra',
        '27'  => 'accessDate',
        '29'  => 'seriesText',
        '30'  => 'seriesNumber',
        '32'  => 'reportType',
        '36'  => 'code',
        '40'  => 'session',
        '41'  => 'legislativeBody',
        '42'  => 'history',
        '43'  => 'reporter',
        '44'  => 'court',
        '45'  => 'numberOfVolumes',
        '46'  => 'committee',
        '48'  => 'assignee',
        '50'  => 'patentNumber',
        '51'  => 'priorityNumbers',
        '52'  => 'issueDate',
        '53'  => 'references',
        '54'  => 'legalStatus',
        '55'  => 'codeNumber',
        '59'  => 'artworkMedium',
        '60'  => 'number',
        '61'  => 'artworkSize',
        '62'  => 'libraryCatalog',
        '63'  => 'videoRecordingFormat',
        '64'  => 'interviewMedium',
        '65'  => 'letterType',
        '66'  => 'manuscriptType',
        '67'  => 'mapType',
        '68'  => 'scale',
        '69'  => 'thesisType',
        '70'  => 'websiteType',
        '71'  => 'audioRecordingFormat',
        '72'  => 'label',
        '74'  => 'presentationType',
        '75'  => 'meetingName',
        '76'  => 'studio',
        '77'  => 'runningTime',
        '78'  => 'network',
        '79'  => 'postType',
        '80'  => 'audioFileType',
        '81'  => 'version',
        '82'  => 'system',
        '83'  => 'company',
        '84'  => 'conferenceName',
        '87'  => 'language',
        '88'  => 'programmingLanguage',
        '91'  => 'websiteTitle',
        '92'  => 'reportNumber',
        '93'  => 'billNumber',
        '94'  => 'codeVolume',
        '95'  => 'codePages',
        '96'  => 'dateDecided',
        '97'  => 'reporterVolume',
        '98'  => 'firstPage',
        '99'  => 'documentNumber',
        '100' => 'dateEnacted',
        '101' => 'publicLawNumber',
        '102' => 'country',
        '103' => 'applicationNumber',
        '105' => 'episodeNumber',
        '108' => 'type',
        '109' => 'medium',
        '111' => 'caseName',
        '112' => 'nameOfAct',
        '113' => 'subject',
        '114' => 'proceedingsTitle',
        '116' => 'shortTitle',
        '117' => 'docketNumber',
        '118' => 'numPages',
        '119' => 'programTitle',
        '120' => 'issuingAuthority',
        '121' => 'filingDate',
        '122' => 'genre',
        '123' => 'archive'
      );

      my $statement = 'SELECT value FROM itemDataValues WHERE valueID=?';

      $school = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 89 );
      $school = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 31 );
      $address = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 7 );
      $edition = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 6 );
      $publisher = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 8 );
      $series = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 3 );
      $series = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 28 and !$series );
      $url = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 1 );
      $title = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 110 );
      $title = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 104 and !$title );
      $title = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 85 and !$title );
      $title = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 86 and !$title );
      $title = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 91 and !$title );
      $title = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 107 and !$title );

      $volume = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 4 );
      $issue = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 5 );
      if ( $fieldID == 12 ) {
        $journal = $dbh->selectrow_array( $statement, undef, $valueID );
        if ( $journal =~ m/\d+\.\d+/ ) {
          $arxivid = "arXiv:$journal";
          $journal = "Preprint";
        }
      }
      $journal = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 25 and !$journal );

      $pages = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 10 );
      $pages = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 118 and !$pages );
      $ISSN = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 13 );
      $isbn = $dbh->selectrow_array( $statement, undef, $valueID )
	if ( $fieldID == 11 );
      $doi = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 26 );
      $abstract = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 90 );
      $booktitle = $dbh->selectrow_array( $statement, undef, $valueID )
        if ( $fieldID == 115 );

      if ( $fieldID == 14 ) {
        my $tmpstring = $dbh->selectrow_array( $statement, undef, $valueID );
        if ( $tmpstring =~ m/(\d\d\d\d)-(\d\d)-(\d\d)/ ) {
          $year = $1;
          $month = $2 if ( $2 ne '00' );
        }
      }

      # extra field: stores stuff like pubmedID, or things that
      # could not be parsed correctly (e.g. Arxiv bibliogrpahic lines)
      if ( $fieldID == 22 ) {
        my $tmpstring = $dbh->selectrow_array( $statement, undef, $valueID );
        if ( $tmpstring =~ m/PMID:\s(\d+)/ ) {
          $pmid = $1;
        }
      }

      # now we add everything else to notes that has not been parsed yet
      if ( defined $unsupported{$fieldID} ) {
	my $tmpstring = $dbh->selectrow_array( $statement, undef, $valueID );
	push @notes_dummy, "ZOTERO field \"$unsupported{$fieldID}\": $tmpstring";
      }

    }

    # now we gather data for each itemID
    my $sth3 =
      $dbh->prepare( "SELECT * FROM itemCreators WHERE itemID=? " . "ORDER BY orderIndex;" );
    $sth3->execute($itemID);
    my @tmpauthors = ();
    my @tmpeditors = ();
    my $statement =
      'SELECT lastName || ", " || firstName ' . 'FROM creatorData ' . 'WHERE creatorDataID=?;';
    while ( my @tmp3 = $sth3->fetchrow_array ) {
      ( my $itemID, my $creatorID, my $creatorTypeID, my $orderIndex ) = @tmp3;

      # Values/Key pairs for creatorTypeID
      #  1 author        2 contributor       3 editor
      #  4 translator    5 seriesEditor      6 interviewee
      #  7 interviewer   8 director          9 scriptwriter
      # 10 producer     11 castMember       12 sponsor
      # 13 counsel      14 inventor         15 attorneyAgent
      # 16 recipient    17 performer        18 composer
      # 19 wordsBy      20 cartographer     21 programmer
      # 22 artist       23 commenter        24 presenter
      # 25 guest        26 podcaster        27 reviewedAuthor
      # 28 cosponsor    29 bookAuthor
      if ( $creatorTypeID == 3 or $creatorTypeID == 5 ) {
        push @tmpeditors, $dbh->selectrow_array( $statement, undef, $creatorID );
      } else {
        push @tmpauthors, $dbh->selectrow_array( $statement, undef, $creatorID );
      }
    }
    $authors = join( " and ", @tmpauthors );
    $authors =~ s/\s+/ /g;
    $editors = join( " and ", @tmpeditors );
    $editors =~ s/\s+/ /g;

    # let's screen for attachments
    my $sth4 = $dbh->prepare( "SELECT * FROM itemAttachments WHERE " . "sourceItemID=?;" );
    $sth4->execute($itemID);
    while ( my @tmp4 = $sth4->fetchrow_array ) {
      my $attachmentID = $tmp4[0];
      my $mimeType     = $tmp4[3];
      my $filename     = $tmp4[5];
      next if ( !$filename );

      my $sth5 = $dbh->prepare("SELECT * FROM items WHERE itemID=?;");
      $sth5->execute($attachmentID);
      my @tmp5 = $sth5->fetchrow_array();

      my $file;
      next if ( !$tmp5[6] );
      if ( $filename =~ m/storage:(.*)/ ) {
        $file = $path . "storage/$tmp5[6]/$1";
      } else {
        $file = $filename;
      }

      $file = Paperpile::Utils->process_attachment_name($file);
      next if ( !$file );

      # if we find a PDF we assume the first one is THE PDF
      push @pdfs, $file if ( $mimeType eq 'application/pdf' );

      # most likely this is the website snapshot
      push @snapshots, $file if ( $mimeType eq 'text/html' );

      # the other stuff is assigned as regular attachement
      push @regular_attachements, $file
        if ( $mimeType ne 'text/html' and $mimeType ne 'application/pdf' );
    }

    # let's screen for notes
    my $sth6 = $dbh->prepare( "SELECT note FROM itemNotes WHERE " . "sourceItemID=?;" );
    $sth6->execute($itemID);
    while ( my @tmp6 = $sth6->fetchrow_array ) {
      ( $note = $tmp6[0] ) =~ s/<div\s+class="[^"]+">//;
      $note =~ s/<\/div>$//;
    }

    # if it does not have a title, we are not interested
    next if ( !defined $title );

    my $pubtype = 'MISC';
    $pubtype = 'ARTICLE'       if ( $itemTypeID == 4 );
    $pubtype = 'BOOK'          if ( $itemTypeID == 2 );
    $pubtype = 'INBOOK'        if ( $itemTypeID == 3 );
    $pubtype = 'INPROCEEDINGS' if ( $itemTypeID == 33 );
    $pubtype = 'PHDTHESIS'     if ( $itemTypeID == 7 );
    $pubtype = 'UNPUBLISHED'   if ( $itemTypeID == 9 );
    if ( $pubtype eq 'MISC' ) {
      $howpublished = 'Magazine article'     if ( $itemTypeID == 5 );
      $howpublished = 'Newspaper article'    if ( $itemTypeID == 6 );
      $howpublished = 'Letter'               if ( $itemTypeID == 8 );
      $howpublished = 'Film'                 if ( $itemTypeID == 11 );
      $howpublished = 'Interview'            if ( $itemTypeID == 10 );
      $howpublished = 'Artwork'              if ( $itemTypeID == 12 );
      $howpublished = 'Webpage'              if ( $itemTypeID == 13 );
      $howpublished = 'Report'               if ( $itemTypeID == 15 );
      $howpublished = 'Bill'                 if ( $itemTypeID == 16 );
      $howpublished = 'Case'                 if ( $itemTypeID == 17 );
      $howpublished = 'Hearing'              if ( $itemTypeID == 18 );
      $howpublished = 'Patent'               if ( $itemTypeID == 19 );
      $howpublished = 'Statute'              if ( $itemTypeID == 20 );
      $howpublished = 'Email'                if ( $itemTypeID == 21 );
      $howpublished = 'Map'                  if ( $itemTypeID == 22 );
      $howpublished = 'Blog post'            if ( $itemTypeID == 23 );
      $howpublished = 'Instant message'      if ( $itemTypeID == 24 );
      $howpublished = 'Forum post'           if ( $itemTypeID == 25 );
      $howpublished = 'Audio recording'      if ( $itemTypeID == 26 );
      $howpublished = 'Presentation'         if ( $itemTypeID == 27 );
      $howpublished = 'Video recording'      if ( $itemTypeID == 28 );
      $howpublished = 'TV broadcast'         if ( $itemTypeID == 29 );
      $howpublished = 'Radio broadcast'      if ( $itemTypeID == 30 );
      $howpublished = 'Podcast'              if ( $itemTypeID == 31 );
      $howpublished = 'Computer program'     if ( $itemTypeID == 32 );
      $howpublished = 'Document'             if ( $itemTypeID == 34 );
      $howpublished = 'Encyclopedia article' if ( $itemTypeID == 35 );
      $howpublished = 'Dictionary entry'     if ( $itemTypeID == 36 );
    }

    # add unsupported fields to note tag
    $note .= "<br />\n".join("<br />\n", @notes_dummy)."<br />\n" if ( $#notes_dummy  > -1 and $note);
    $note = join("<br />\n", @notes_dummy)."<br />\n" if ( $#notes_dummy  > -1 and !$note);

    my $pub = Paperpile::Library::Publication->new( pubtype => $pubtype );

    $pub->journal($journal)           if $journal;
    $pub->volume($volume)             if $volume;
    $pub->issue($issue)               if $issue;
    $pub->year($year)                 if $year;
    $pub->month($month)               if $month;
    $pub->pages($pages)               if $pages;
    $pub->abstract($abstract)         if $abstract;
    $pub->title($title)               if $title;
    $pub->doi($doi)                   if $doi;
    $pub->issn($ISSN)                 if $ISSN;
    $pub->isbn($isbn)                 if $isbn;
    $pub->pmid($pmid)                 if $pmid;
    $pub->arxivid($arxivid)           if $arxivid;
    $pub->authors($authors)           if $authors;
    $pub->editors($editors)           if $editors;
    $pub->edition($edition)           if $edition;
    $pub->series($series)             if $series;
    $pub->booktitle($booktitle)       if $booktitle;
    $pub->address($address)           if $address;
    $pub->howpublished($howpublished) if $howpublished;
    $pub->school($school)             if $school;
    $pub->annote($note)               if $note;

    # add PDFs and other attachements
    foreach my $i ( 0 .. $#pdfs ) {
      if ( $i == 0 ) {
        $pub->_pdf_tmp($pdfs[$i]);
      } else {
        unshift( @regular_attachements, $pdfs[$i] );
      }
    }
    if (@regular_attachements) {
      $pub->{_attachments_tmp} = [@regular_attachements] if ( $#regular_attachements > -1 );
    }

    push @output, $pub;
  }
  return [@output];

}



1;

