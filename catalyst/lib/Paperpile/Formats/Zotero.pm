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

    my @output = ();

    # TODO: Make this behave like all other plugins such that
    # $self->file is always given and move the function to find the
    # local Zotero file to Paperpile::Utils.

    # file is not defined we try to find it
    if ( !defined $file ) {

        # a typical Zotero path in windows (German)
        # C:\Dokumente und Einstellungen\someone\Anwendungsdaten\
        # Mozilla\Firefox\Profiles\b57sxgsi.default\zotero.sqlite

        # a typical Zotero path in ubuntu
        # ~/.mozilla/firefox/iqurqbah.default/zotero/zotero.sqlite

        # Try to find file in Linux environment
        my $home         = $ENV{'HOME'};
        my $firefox_path = "$home/.mozilla/firefox";
        if ( -d $firefox_path ) {
            my @profiles = ();
            opendir( DIR, $firefox_path );
            while ( defined( my $file = readdir(DIR) ) ) {

                next if ( $file eq '.' or $file eq '..' );
                push @profiles, "$firefox_path/$file"
                  if ( -d "$firefox_path/$file" );
            }
            close(DIR);

            foreach my $profile (@profiles) {
                if ( -e "$profile/zotero/zotero.sqlite" ) {
                    $file = "$profile/zotero/zotero.sqlite";
                    last;
                }
            }
        }
    }

    print STDERR "ZoteroDB: $file\n";
    if ( !defined $file ) {
        FileFormatError->throw(
            error => "Could not find Zotero database file (zotero.sqlite)." );
    }

    # get a DBI connection to the SQLite file
    my $dbh =
      DBI->connect( "dbi:SQLite:$file", '', '',
        { AutoCommit => 1, RaiseError => 1 } );

    # publications are stored in table items
    my $sth = $dbh->prepare("SELECT * FROM items;");
    $sth->execute();
    while ( my @tmp = $sth->fetchrow_array ) {
        my $itemID     = $tmp[0];
        my $itemTypeID = $tmp[1];

        # We do not proccess attachements at the moment
        next if ( $itemTypeID == 14 );

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
            $title,    $authors,   $journal, $issue, $volume,
            $year,     $month,     $ISSN,    $pages, $doi,
            $abstract, $booktitle, $url,     $pmid,  $arxivid
        );

        # now we gather data for each itemID
        my $sth2 = $dbh->prepare("SELECT * FROM itemData WHERE itemID=?;");
        $sth2->execute($itemID);
        while ( my @tmp2 = $sth2->fetchrow_array ) {
            my $fieldID = $tmp2[1];
            my $valueID = $tmp2[2];

            # Values/Key pairs for fieldID
            #  1 url                   2 rights             3 series
            #  4 volume                5 issue              6 edition
            #  7 place                 8 publisher         10 pages
            # 11 ISBN                 12 publicationTitle  13 ISSN
            # 14 date                 15 section           18 callNumber
            # 19 archiveLocation      21 distributor       22 extra
            # 25 journalAbbreviation  26 DOI               27 accessDate
            # 28 seriesTitle          29 seriesText        30 seriesNumber
            # 31 institution          32 reportType        36 code
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
            # 85 encyclopediaTitle    86 dictionaryTitle   87 language
            # 88 programmingLanguage  89 university        90 abstractNote
            # 91 websiteTitle         92 reportNumber      93 billNumber
            # 94 codeVolume           95 codePages         96 dateDecided
            # 97 reporterVolume       98 firstPage         99 documentNumber
            #100 dateEnacted         101 publicLawNumber  102 country
            #103 applicationNumber   104 forumTitle       105 episodeNumber
            #107 blogTitle           108 type             109 medium
            #110 title               111 caseName         112 nameOfAct
            #113 subject             114 proceedingsTitle 115 bookTitle
            #116 shortTitle

            my $statement = 'SELECT value FROM itemDataValues WHERE valueID=?';

            $url = $dbh->selectrow_array( $statement, undef, $valueID )
              if ( $fieldID == 1 );
            $title = $dbh->selectrow_array( $statement, undef, $valueID )
              if ( $fieldID == 110 );
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

            $pages = $dbh->selectrow_array( $statement, undef, $valueID )
              if ( $fieldID == 10 );
            $ISSN = $dbh->selectrow_array( $statement, undef, $valueID )
              if ( $fieldID == 13 );
            $doi = $dbh->selectrow_array( $statement, undef, $valueID )
              if ( $fieldID == 26 );
            $abstract = $dbh->selectrow_array( $statement, undef, $valueID )
              if ( $fieldID == 90 );
            $booktitle = $dbh->selectrow_array( $statement, undef, $valueID )
              if ( $fieldID == 115 );
            if ( $fieldID == 14 ) {
                my $tmpstring =
                  $dbh->selectrow_array( $statement, undef, $valueID );
                if ( $tmpstring =~ m/(\d\d\d\d)-(\d\d)-(\d\d)/ ) {
                    $year = $1;
                    $month = $2 if ( $2 ne '00' );
                }
            }

            # extra field: stores stuff like pubmedID, or things that
            # could not be parsed correctly (e.g. Arxiv bibliogrpahic lines)
            if ( $fieldID == 22 ) {
                my $tmpstring =
                  $dbh->selectrow_array( $statement, undef, $valueID );
                if ( $tmpstring =~ m/PMID:\s(\d+)/ ) {
                    $pmid = $1;
                }
            }
        }

        # now we gather data for each itemID
        my $sth3 = $dbh->prepare(
            "SELECT * FROM itemCreators WHERE itemID=? ORDER BY orderIndex;");
        $sth3->execute($itemID);
        my @tmpauthors = ();
        my $statement  = 'SELECT lastName || ", " || firstName '
          . 'FROM creators WHERE creatorID=?;';
        while ( my @tmp3 = $sth3->fetchrow_array ) {
            push @tmpauthors,
              $dbh->selectrow_array( $statement, undef, $tmp3[1] );
        }
        $authors = join( " and ", @tmpauthors );
        $authors =~ s/\s+/ /g;

        # if it does not have a title, we are not interested
        next if ( !defined $title );

        my $pubtype = 'MISC';
        $pubtype = 'ARTICLE' if ( $itemTypeID == 4 );

        my $pub = Paperpile::Library::Publication->new( pubtype => $pubtype );

        $pub->journal($journal)   if $journal;
        $pub->volume($volume)     if $volume;
        $pub->issue($issue)       if $issue;
        $pub->year($year)         if $year;
        $pub->month($month)       if $month;
        $pub->pages($pages)       if $pages;
        $pub->abstract($abstract) if $abstract;
        $pub->title($title)       if $title;
        $pub->doi($doi)           if $doi;
        $pub->issn($ISSN)         if $ISSN;
        $pub->pmid($pmid)         if $pmid;
        $pub->eprint($arxivid)    if $arxivid;
        $pub->authors($authors)   if $authors;

        push @output, $pub;
    }
    return [@output];

}



1;

