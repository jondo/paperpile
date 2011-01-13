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


package Paperpile::Formats::Rss;
use Moose;
use XML::Simple;
use HTML::TreeBuilder::XPath;
use Paperpile::Library::Author;
use Data::Dumper;

extends 'Paperpile::Formats';

has 'title' => ( is => 'rw', isa => 'Str', default => '' );

sub BUILD {
  my $self = shift;
  $self->format('RSS');
  $self->readable(1);
  $self->writable(0);
}

sub read {

  my $self = shift;

  my @output = ();

  # read in XML
  my $file = $self->file;

  # XMLin crashes on empty files and if we have html content
  return if ( -z $file );
  open( TESTCASE, $file );
  my $html_flag = 0;
  while (<TESTCASE>) {
    $html_flag = 1 if ( $_ =~ m/<html>/ );
  }
  return if ($html_flag);

  my $result = XMLin( $file, ForceArray => 1 );

  # let's first screen the channel tag
  my $channel_journal_name;
  if ( $result->{channel}->[0]->{'prism:publicationName'} ) {
    $channel_journal_name = join( '', @{ $result->{channel}->[0]->{'prism:publicationName'} } );
  }

  my $channel_title;
  if ( $result->{channel}->[0]->{'title'} ) {
    $channel_title = join( '', @{ $result->{channel}->[0]->{'title'} } );
    $channel_title =~ s/^ScienceDirect\sPublication:\s//;
    $channel_title =~ s/^Annual\sReviews:\s//;
  }

  my $channel_description;
  if ( $result->{channel}->[0]->{'description'} ) {
    $channel_description = join( '', @{ $result->{channel}->[0]->{'description'} } );
  }
  $self->title($channel_title) if ($channel_title);

  my $issn;
  if ( $result->{channel}->[0]->{'prism:issn'} ) {
    $issn = join( '', @{ $result->{channel}->[0]->{'prism:issn'} } );
  }

  # get the list of items
  my @entries;

  if ( $result->{item} ) {
    @entries = @{ $result->{item} };
  }

  if ( $result->{entry} and $#entries == -1 ) {
    @entries = @{ $result->{entry} };
  }

  # PLoS journals use some really weird XML style
  if ( $result->{author}->[0]->{name}->[0] ) {
    if ( $result->{author}->[0]->{name}->[0] eq 'PLoS' ) {
      @entries = @{ $result->{entry} };
      $self->title( $result->{title}->[0]->{content} );
      return $self->_parse_PLoS( \@entries );
    }
  }

  # Parsing scientific RSS feeds is a cumbersome process. There are standards
  # but they are usually ignored. The only one that seems to have understand
  # the concept is NPG. Guided by the idea that this is the world's one and
  # only RSS reader for scientific RSS feeds, we try to do the job as good as
  # possible. Clearly speaking that means that we have to implement a lot of
  # sub functions specialized in parsing RSS feeds from particular publishers.

  if ( !@entries ) {

    # let's see why the regular way did not work
    my $channel_title = ( $result->{channel}->[0]->{'title'} )
      ? join( '', @{ $result->{channel}->[0]->{'title'} } )
      : '';
    my $channel_link =
      ( $result->{channel}->[0]->{'link'} )
      ? join( '', @{ $result->{channel}->[0]->{'link'} } )
      : '';
    my $channel_description =
      ( $result->{channel}->[0]->{'description'} )
      ? join( '', @{ $result->{channel}->[0]->{'description'} } )
      : '';

    # ScienceDirect
    if ( $channel_title =~ m/ScienceDirect/ ) {
      @entries = @{ $result->{channel}->[0]->{item} };
      return $self->_parse_ScienceDirect( \@entries );
    }

    # SpringerLink
    if ( $channel_link =~ m/content\/\d+-\d+\/preprint\/\?export=rss/ or
       $channel_link =~ m/content\/\d+-\d+\/\?export=rss/ ) {
      @entries = @{ $result->{channel}->[0]->{item} };
      return $self->_parse_SpringerLink( \@entries );
    }

    # ACS Publications
    if ( $channel_link =~ m/pubs\.acs\.org/ ) {
      @entries = @{ $result->{channel}->[0]->{item} };
      return $self->_parse_ACSPublications( \@entries );
    }

    # Chicago Journals
    if ( $channel_link =~ m/journals\.uchicago\.edu/ ) {
      @entries = @{ $result->{channel}->[0]->{item} };
      return $self->_parse_ChicagoJournals( \@entries );
    }

    # Annual Reviews
    if ( $channel_link =~ m/annualreviews\.org/ ) {
      @entries = @{ $result->{channel}->[0]->{item} };
      return $self->_parse_AnnualReviews( \@entries );
    }

    # Karger
    if ( $channel_link =~ m/karger\.com/ ) {
      @entries = @{ $result->{channel}->[0]->{item} };
      return $self->_parse_Karger( \@entries );
    }

    # IOP electronic journals
    if ( $channel_link =~ m/iop\.org/ ) {
      @entries = @{ $result->{channel}->[0]->{item} };
      return $self->_parse_IOP( \@entries, $channel_title );
    }

    # Cambridge Journals
    if ( $channel_link =~ m/journals\.cambridge\.org/ ) {
      @entries = @{ $result->{channel}->[0]->{item} };
      return $self->_parse_CambridgeJournals( \@entries, $channel_title );
    }

    # Ovid
    if ( $channel_link =~ m/ovid\.com/ ) {
      @entries = @{ $result->{channel}->[0]->{item} };
      return $self->_parse_Ovid( \@entries, $channel_title );
    }

    # LA Press
    if ( $channel_link =~ m/la-press\.com/ ) {
      @entries = @{ $result->{channel}->[0]->{item} };
      return $self->_parse_LAPress( \@entries, $channel_title );
    }

    # Metapress
    if ( $channel_link =~ m/metapress.com/ ) {
      @entries = @{ $result->{channel}->[0]->{item} };
      return $self->_parse_Metapress( \@entries, $channel_title );
    }

    # Emerald Insight
    if ( $channel_link =~ m/emeraldinsight\.com/ ) {
      @entries = @{ $result->{channel}->[0]->{item} };
      return $self->_parse_Emerald( \@entries, $channel_title );
    }

    # BioOne
    if ( $channel_link =~ m/bioone\.org/ ) {
      @entries = @{ $result->{channel}->[0]->{item} };
      return $self->_parse_BioOne( \@entries, $channel_title );
    }

    # Marry Ann Liebert
    if ( $channel_link =~ m/liebertonline.com/ ) {
      @entries = @{ $result->{channel}->[0]->{item} };
      return $self->_parse_Liebert( \@entries, $channel_title );
    }

    # Dove Press
    if ( $channel_link =~ m/dovepress.com/ ) {
      @entries = @{ $result->{channel}->[0]->{item} };
      return $self->_parse_DovePress( \@entries, $channel_title );
    }

    # let's try it again the regular way
    if ( $result->{channel}->[0]->{item} ) {
      @entries = @{ $result->{channel}->[0]->{item} };
      return $self->_parse_RegularFeed( \@entries, $channel_journal_name, $channel_title,
        $channel_description, $issn );
    }

  } else {
    my $channel_link =
      ( $result->{channel}->[0]->{'link'} )
      ? join( '', @{ $result->{channel}->[0]->{'link'} } )
      : '';

    # AmericanInstituteOfPhysics
    if ( $channel_link =~ m/aip.org/ ) {
      return $self->_parse_AIP( \@entries, $channel_title );
    }

    if ( $result->{generator} ) {
      if ( $result->{generator}->[0]->{content} ) {
	if ( $result->{generator}->[0]->{content} =~ m/Google\sReader/ ) {

 
	}
      }
    }

    # if we are here then we have a regular RSS feed
    return $self->_parse_RegularFeed( \@entries, $channel_journal_name, $channel_title,
      $channel_description, $issn );
  }
}


sub _parse_RegularFeed {

  my $self                 = shift;
  my @entries              = @{ $_[0] };
  my $channel_journal_name = $_[1];
  my $channel_title        = $_[2];
  my $channel_description  = $_[4];
  my $issn                 = $_[5];

  my @output = ();
  foreach my $entry (@entries) {

    my (
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
    );

    # parsing of the title; let's try first if there is a regular
    # title tag and if not if there is a dublin core title
    if ( $entry->{'title'} ) {
      if ( $entry->{'title'}->[0] =~ m/^HASH\(/ ) {
        $title = $entry->{'title'}->[0]->{'content'} if
	  $entry->{'title'}->[0]->{'content'};
      } else {
        $title = join( '', @{ $entry->{'title'} } );
      }
    }

    if ( $entry->{'dc:title'} and !$title ) {
      $title = join( '', @{ $entry->{'dc:title'} } );
      if ( $title =~ m/(.*)(\s\[[A-Z]+\]$)/ ) {
        $title = $1;
      }
    }

    # although the element dc:creator can be used (and should be used) for
    # more than once if there are multiple authors, some publishers just
    # put all the names in one field. This makes it necessary to do some parsing.
    if ( $entry->{'dc:creator'} ) {
      my @authors     = ();
      my @authors_tmp = @{ $entry->{'dc:creator'} };

      if ( $authors_tmp[0] =~ m/^HASH\(/ ) {
        $authors = 'Unknown';
      }

      # We just have one author line, and this is where the mess starts
      # It is amazing in how many stupid ways people can abuse
      # a defined schema and make it awkward to extract the information
      # Examples:
      # Essex, M. J., Klein, M. H., Slattery, M. J., Goldsmith, H. H., Kalin, N. H.
      # L. SCHLÜNZEN, N. JUUL, K. V. HANSEN, A. GJEDDE, G. E. COLD
      # Graham A. Lee, Robert Ritch, Steve Y.-W. Liang, Jeffrey M. Liebmann, 
      #  Philip Dubois, Matthew Bastian-Jordan, Kate Lehmann, Prin Rojanapongpun

      if ( $#authors_tmp == 0 and !$authors ) {

        # first we check if there is really just one author
        my $nr_separators = 0;
        $nr_separators += ( $authors_tmp[0] =~ tr/,// );

        # The case it is meant to be
        if ( $nr_separators == 0 ) {
          $authors =
            Paperpile::Library::Author->new()->parse_freestyle( $authors_tmp[0] )->bibtex();
        }

        # It might be of the form Gruber, A. R.
        if ( $nr_separators == 1 ) {
          if ( $authors_tmp[0] =~ m/(\S+),(.*)/ ) {
            $authors = Paperpile::Library::Author->new()->parse_freestyle("$2 $1")->bibtex();
          }
        }
        if ( $nr_separators > 1 ) {
          my $parsed_flag = 0;

          # Strategy 1: works well for Oxford journals
          my @tmp1 = split( /\., /, $authors_tmp[0] );
          if ( $#tmp1 > 0 ) {
            $authors = join( ". and ", @tmp1 );
            $parsed_flag = 1;
          }

          # L. SCHLUENZEN, N. JUUL, K. V. HANSEN, A. GJEDDE, G. E. COLD
          if ( $parsed_flag == 0 and $authors_tmp[0] =~ m/,\s[A-Z]\.?\s/ ) {
            my @tmp = split( /,/, $authors_tmp[0] );
            my @authors_objects = ();
            foreach my $entry (@tmp) {
              push @authors_objects,
                Paperpile::Library::Author->new()->parse_freestyle($entry)->bibtex();
            }
            $authors = join( ' and ', @authors_objects );
            $parsed_flag = 1;
          }

          # Graham A. Lee, Robert Ritch, Steve Y.-W. Liang, Jeffrey M. Liebmann, Philip Dubois
          if ( $parsed_flag == 0 ) {

            # we need to do some quality control if splitting this way
            # will produce something meaningful

            ( my $tmp_line = $authors_tmp[0] ) =~ s/\s[A-Z]\.?\s/ /g;
            my @tmp = split( /,\s/, $tmp_line );
            my $avg_spaces = 0;
            foreach my $entry (@tmp) {
              $avg_spaces += ( $entry =~ tr/ // );
            }
            $avg_spaces = $avg_spaces / ( $#tmp + 1 );

            if ( $avg_spaces <= 2.05 ) {
              my @tmp = split( /,/, $authors_tmp[0] );
              my @authors_objects = ();
              foreach my $entry (@tmp) {
                push @authors_objects,
                  Paperpile::Library::Author->new()->parse_freestyle($entry)->bibtex();
              }
              $authors = join( ' and ', @authors_objects );
              $parsed_flag = 1;
            }
          }

          if ( $parsed_flag == 0 ) {

            # Strategy 2: works well for Blackwell journals
            @tmp1 = split( /, /, $authors_tmp[0] );
            if ( $#tmp1 > 0 and !$authors ) {
              $authors = join( " and ", @tmp1 );
            }
          }
        }
      }
      if ( $#authors_tmp > 0 and !$authors ) {

        # it seems that there are multiple fields, so we assume that
        # each field is one author

        foreach my $author (@authors_tmp) {

          # if there is a comma, we assume that it is already in bibtex format
          if ( $author =~ m/(.*),(.*)/ ) {
            push @authors, $author;
          } else {
            push @authors, Paperpile::Library::Author->new()->parse_freestyle($author)->bibtex();
          }
        }

        $authors = join( ' and ', @authors );
      }
    }

    # observed for IEEE journals
    if ( $entry->{'authors'} ) {
      $authors = join( '', @{ $entry->{'authors'} } );
      if ( $authors =~ m/;/ ) {
        my @tmp = split( /;/, $authors );
        pop(@tmp) if ( $tmp[$#tmp] eq '' );
        $authors = join( " and ", @tmp );
      }
      $authors = 'Unknown' if ( $authors =~ m/^HASH\(/ );
    }

    # observed for Emerald journals and others
    if ( $entry->{'author'} ) {
      if ( $entry->{'author'}->[0] =~ m/^HASH\(/ ) {
        $authors = 'Unknown';
      } else {
        $authors = join( '', @{ $entry->{'author'} } );
        my $already_parsed_flag = 0;

        # authors are separated by semicolons
        if ( $authors =~ m/;/ ) {
          my @authors_objects = ();
          my @tmp = split( /;/, $authors );
          foreach my $entry (@tmp) {

            # if there are still commas we turn it around
            if ( $entry =~ m/(.*),(.*)/ ) {
              $entry = "$2 $1";
            }

            # if initials are at the end we turn it around
            if ( $entry =~ m/(.*)\s([A-Z])([A-Z])?$/ ) {
              $entry = ($3) ? "$2 $3 $1" : "$2 $1";
            }
            push @authors_objects,
              Paperpile::Library::Author->new()->parse_freestyle($entry)->bibtex();
          }
          $authors = join( ' and ', @authors_objects );
          $already_parsed_flag = 1;
        }

        if ( $already_parsed_flag == 0 and $authors =~ m/,/ ) {
          $already_parsed_flag = 1;
        }

        # seems that there is only a single author
        if ( $already_parsed_flag == 0 and $authors =~ m/(.+)\s([A-Z])([A-Z])?$/ ) {
          my $tmp = ($3) ? "$2 $3 $1" : "$2 $1";
          $authors = Paperpile::Library::Author->new()->parse_freestyle($tmp)->bibtex();
        }
      }

      #$authors =~ s/,\s/ and /g;
    }

    # Huanping Zhang, Xiaofeng Song, Huinan Wang, and Xiaobai Zhang
    # observed for Hindawi Publishing
    if ( $entry->{'Author'} ) {
      $authors = join( '', @{ $entry->{'Author'} } );
      my @tmp = split( /, /, $authors );
      my @authors_objects = ();
      foreach my $entry (@tmp) {
        $entry =~ s/^and\s//;
        push @authors_objects, Paperpile::Library::Author->new()->parse_freestyle($entry)->bibtex();
      }
      $authors = join( ' and ', @authors_objects );
    }

    # now we parse other bibliographic data

    if ( $entry->{'prism:publicationName'} ) {
      $journal = join( '', @{ $entry->{'prism:publicationName'} } );
    }

    # volume
    if ( $entry->{'prism:volume'} ) {
      $volume = join( '', @{ $entry->{'prism:volume'} } );
    }

    if ( $entry->{'volume'} and !$volume ) {
      $volume = join( '', @{ $entry->{'volume'} } );
    }

    # issue
    if ( $entry->{'prism:number'} ) {
      $issue = join( '', @{ $entry->{'prism:number'} } );
    }

    if ( $entry->{'issue'} and !$issue ) {
      $issue = join( '', @{ $entry->{'issue'} } );
    }

    # page numbers
    if ( $entry->{'prism:startingPage'} and $entry->{'prism:endingPage'} ) {
      $pages =
          join( '', @{ $entry->{'prism:startingPage'} } ) . '-'
        . join( '', @{ $entry->{'prism:endingPage'} } );
      $pages = '' if ( $pages =~ m/HASH/ );
    }
    if ( $entry->{'prism:startingPage'} and !$pages ) {
      $pages = join( '', @{ $entry->{'prism:startingPage'} } );
      $pages = '' if ( $pages =~ m/HASH/ );
    }

    if ( $entry->{'startPage'} and $entry->{'endPage'} and !$pages ) {
      $pages = join( '', @{ $entry->{'startPage'} } ) . '-' . join( '', @{ $entry->{'endPage'} } );
    }

    # DOI is interesting. There can be multiple entries.
    if ( $entry->{'prism:doi'} ) {
      $doi = join( '', @{ $entry->{'prism:doi'} } );
    }

    if ( $entry->{'dc:identifier'} ) {
      my $tmp = join( '', @{ $entry->{'dc:identifier'} } );
      if ( $tmp =~ m/doi/ ) {
        $tmp =~ s/(.*doi:?\/?)(\d\d\.\d\d\d.*)/$2/;
        if ( !$doi ) {
          $doi = $tmp;
        }
      }
      if ( $tmp =~ m/^\d\d\.\d\d\d/ and !$doi ) {
        $doi = $tmp;
      }
      if ( $tmp =~ m/HASH/ ) {
        if ( $entry->{'dc:identifier'}->[0]->{'rdf:resource'} ) {
          $doi = $entry->{'dc:identifier'}->[0]->{'rdf:resource'};
          $doi =~ s/doi://;
        }
      }
    }

    # year
    if ( $entry->{'dc:date'} ) {
      my $tmp = join( '', @{ $entry->{'dc:date'} } );
      if ( $tmp =~ m/^(\d\d\d\d)-(\d\d)-\d\d/ ) {
        $year = $1;
      }
      if ( $tmp =~ m/\s(\d\d\d\d)$/ and !$year ) {
        $year = $1;
      }
    }

    if ( $entry->{'pubDate'} and !$year ) {
      my $tmp = join( '', @{ $entry->{'pubDate'} } );
      if ( $tmp =~ m/^[A-Z]+\s+(\d\d\d\d)$/i ) {
        $year = $1;
      }
      if ( $tmp =~ m/\d{1,2}\s+[A-Z]{3}\s+(\d\d\d\d)/i ) {
        $year = $1;
      }
    }

    if ( $entry->{'prism:publicationDate'} and !$year ) {
      my $tmp = join( '', @{ $entry->{'prism:publicationDate'} } );
      if ( $tmp =~ m/^(\d\d\d\d)-\d\d-\d\d$/i ) {
        $year = $1;
      }
    }

    if ( $entry->{'description'} ) {
      $description = join( '', @{ $entry->{'description'} } );
      $description = '' if ( $description =~ m/^HASH\(/ );
    }

    if ( $entry->{'summary'} ) {
      if ( $entry->{'summary'}->[0]->{'content'} ) {
        $description = $entry->{'summary'}->[0]->{'content'};
      }
    }

    if ( $entry->{'link'} ) {
      $link = join( '', @{ $entry->{'link'} } );
    }

    if ( $entry->{'feedburner:origLink'} ) {
      $link = join( '', @{ $entry->{'feedburner:origLink'} } );
    }

    if ( $entry->{'dc:source'} ) {
      my $tmp = join( '', @{ $entry->{'dc:source'} } );

      # Magazine of Concrete Research 61(6): 401-406
      if ( $tmp =~ m/(.*)\s(\d+)\((\d+)\):\s(\d+-\d+)/ ) {
        $journal = $1 if ( !$journal );
        $volume  = $2 if ( !$volume );
        $issue   = $3 if ( !$issue );
        $pages   = $4 if ( !$pages );
      }

      if ( $tmp =~ m/\s\((20\d\d)\)$/ ) {
        $year = $1 if ( !$year );
      }
    }

    if ( $channel_journal_name and !$journal ) {
      $journal = $channel_journal_name;
    }

    if ( $channel_title and !$journal ) {
      $journal = $channel_title;
    }

    if ( !$description ) {
      $description = '';
    }

    # sometimes volume/issue information is "hidden" in the journal name
    if ( $journal =~ m/Volume\s\d+\s?\(\d+\)/ ) {
      ( $volume = $journal ) =~ s/(.*Volume\s)(\d+)(\s?.*)/$2/i        if ( !$volume );
      ( $issue  = $journal ) =~ s/(.*Volume\s\d+\s?\()(\d+)(\).*)/$2/i if ( !$issue );
      $journal =~ s/Volume\s\d+\s?\(\d+\)//;
    }
    if ( $journal =~ m/(200\d|201\d)$/ ) {
      ( $year = $journal ) =~ s/(.*\s)(200\d|201\d)$/$2/i if ( !$year );
      $journal =~ s/(200\d|201\d)$//;
    }

    # sometime volume/issue information is "hidden" in channel_description
    if ($channel_description) {
      if ( $channel_description =~ m/vol\.?\s(\d+)/i ) {
        $volume = $1 if ( !$volume );
      }
      if ( $channel_description =~ m/num\.?\s(\d+)/i ) {
        $issue = $1 if ( !$issue );
      }
    }

    # some cleaning up
    if ( $journal =~
      m/(January|February|March|April|May|June|July|August|September|October|November|December)/i )
    {
      $journal =~
        s/(January|February|March|April|May|June|July|August|September|October|November|December)\/?//gi;
    }

    $journal =~ s/<img.*>//;
    $journal =~ s/\s-\snew\sTOC//;
    $journal =~ s/on\s\d\d\d\d-\d\d-\d\d\s\d\d:\d\d\s(A|P)M//;
    $journal =~ s/"//g;
    $journal =~ s/\s+$//;
    $journal =~ s/\.$//;
    $journal =~ s/\s+/ /;

    $title = _remove_html_tags($title);
    if ($authors) {
      if ( $authors =~ m/(.*\s)(et\sal\.?)$/ ) {
        $authors = "$1 {$2}";
      }
      $authors =~ s/,/, /g;
      $authors =~ s/\s+/ /g;
    } else {
      $authors = '';
    }

    push @output,
      _fill_publication_object(
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
      );
  }

  return [@output];
}

sub _parse_SpringerLink {
  my $self    = shift;
  my @entries = @{ $_[0] };

  my @output = ();

  foreach my $entry (@entries) {

    my (
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
    );


    $title = _easy_join( 'title', $entry );
    $link  = _easy_join( 'link',  $entry );

    if ( $entry->{'description'} ) {

      # now we have HTML markup that we can parse with XPath
      my $html = join( '', @{ $entry->{'description'} } );
      $html =~ s/([^[:ascii:]])/sprintf("&#%d;",ord($1))/eg;
      $html = '<html><body>' . $html . '</html>/<body>';

      my $tree = HTML::TreeBuilder::XPath->new;
      $tree->utf8_mode(1);
      $tree->parse_content($html);

      # abstract
      my @tmp = $tree->findnodes('/html/body/p');
      $description = $tmp[0]->as_text();
      $description =~ s/Abstract\s//;

      # authors
      @tmp = $tree->findnodes('/html/body/ul/li/ul/li');
      my @authors = ();
      foreach my $line (@tmp) {
        my @temp = split( /,/, $line->as_text() );
        push @authors, Paperpile::Library::Author->new()->parse_freestyle( $temp[0] )->bibtex();

      }
      $authors = join( ' and ', @authors );

      # doi
      @tmp = $tree->findnodes('/html/body/ul/li');
      foreach my $line (@tmp) {
        my $tmpline = $line->as_text();
        if ( $tmpline =~ m/(DOI.*)(\d\d\.\d\d\d\d.*)/i ) {
          $doi = $2;
        }
      }

      # more bibliographic data
      @tmp = $tree->findnodes('/html/body/ul/ul/li');
      foreach my $line (@tmp) {
        my $tmpline = $line->as_text();
        if ( $tmpline =~ m/Journal/ and $tmpline !~ m/Volume/ ) {
          ( $journal = $tmpline ) =~ s/Journal\s//;
        }
        if ( $tmpline =~ m/Volume\s(\d+)/ ) {
          $volume = $1;
        }
        if ( $tmpline =~ m/Number\s(\d+)/ ) {
          $issue = $1;
        }
        if ( $tmpline =~ m/,\s(\d\d\d\d)$/ ) {
          $year = $1;
        }
      }
    }

    if ( $entry->{'pubDate'} and !$year ) {
      my $tmpline = join( '', @{ $entry->{'pubDate'} } );
      if ( $tmpline =~ m/\d+\s[A-Z]{3}\s(\d\d\d\d)/i ) {
        $year = $1;
      }
    }

    push @output,
      _fill_publication_object(
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
      );
  }

  return [@output];
}

sub _parse_ScienceDirect {

  my $self    = shift;
  my @entries = @{ $_[0] };

  my @output = ();

  foreach my $entry (@entries) {

    my (
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
    );

    $title = _easy_join( 'title', $entry );
    $link  = _easy_join( 'link',  $entry );

    if ( $entry->{'description'} ) {
      my @tmp = split( /<br>/, join( '', @{ $entry->{'description'} } ) );

      # 0 .. usually the year
      if ( $tmp[0] =~ m/Publication\syear:\s(\d\d\d\d)/ ) {
        $year = $1;
      }

      # 1 .. usually journal and other bibliographic stuff
      my @tmp2 = split( /,/, $tmp[1] );
      if ( $tmp2[0] =~ m/<b>Source:<\/b>\s(.*)/ ) {
        $journal = $1;
      }

      if ( $tmp[1] =~ m/Volume\s(\d+)/ ) {
        $volume = $1;
      }

      if ( $tmp[1] =~ m/Issue\s(\d+)/ ) {
        $issue = $1;
      }

      if ( $tmp[1] =~ m/Pages\s(\d+-\d+)/ ) {
        $pages = $1;
      }

      if ( $tmp[1] =~ m/In\sPress/ and !$volume ) {
        $volume = "In Press";
      }

      # 2 .. usually author line ( sometimes incomplete ends with ,... )
      if ( $tmp[2] !~ m/No\sauthor\sname\savailable/ ) {
        my $etal = '';
        if ( $tmp[2] =~ m/(.*)(\s,\s\.\.\.)$/ ) {
          $tmp[2] = $1;
          $etal = "et al.";
        }
        my @tmp3 = split( / , /, $tmp[2] );
        my @authors = ();
        foreach my $author (@tmp3) {
          if ( $author =~ m/(.+)(,\s)(.+)/ ) {
            push @authors, "$3,$1";
          }
        }
        push @authors, $etal if ( $etal ne '' );

        $authors = join( ' and ', @authors );
        $authors =~ s/,/, /g;
        $authors =~ s/\./. /g;
        $authors =~ s/\s+/ /g;

      }

      # the rest we put into the abstract field
      foreach my $i ( 3 .. $#tmp ) {
        $description .= " $tmp[$i]" if ( $tmp[$i] );
      }
    }

    push @output,
      _fill_publication_object(
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
      );
  }

  return [@output];
}

sub _parse_ACSPublications {

  my $self    = shift;
  my @entries = @{ $_[0] };

  my @output = ();

  foreach my $entry (@entries) {

    my (
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
    );

    $title = _easy_join( 'title', $entry );
    $link  = _easy_join( 'link',  $entry );

    if ( $entry->{'description'} ) {
      my $temp = join( '', @{ $entry->{'description'} } );
      my @tmp = split( /,/, _remove_html_tags($temp) );
      $journal = $tmp[0];
      ( $volume = $tmp[1] ) =~ s/.*Volume\s//;
      $volume = ( $volume > 0 ) ? $volume : 'in press';
      ( $issue = $tmp[2] ) =~ s/.*Issue\s//;
      $issue = ( $issue > 0 ) ? $issue : '';
      if ( $tmp[3] =~ m/(Page\s)(.*)/ ) {
        $pages = $2;
      }
      if ( $tmp[5] ) {
        if ( $tmp[5] =~ m/.*(\d\d\d\d).*/ ) {
          $year = $1;
        }
      }
      $description = join( '', @{ $entry->{'description'} } );
    }

    if ( $entry->{'author'} ) {
      my $tmp = join( '', @{ $entry->{'author'} } );
      if ( $tmp =~ m/(.*)(et al)$/ ) {
        $authors =
          Paperpile::Library::Author->new()->parse_freestyle($1)->bibtex() . " and {et al.}";
      } else {
        $authors = Paperpile::Library::Author->new()->parse_freestyle($tmp)->bibtex();
      }
    }

    $journal =~ s/<img.*>//;

    push @output,
      _fill_publication_object(
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
      );
  }

  return [@output];
}

sub _parse_ChicagoJournals {

  my $self    = shift;
  my @entries = @{ $_[0] };

  my @output = ();

  foreach my $entry (@entries) {

    my (
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
    );

    $title = _easy_join( 'title', $entry );
    $link  = _easy_join( 'link',  $entry );

    if ( $entry->{'description'} ) {
      my $temp = join( '', @{ $entry->{'description'} } );
      my @tmp = split( /,/, _remove_html_tags($temp) );
      $journal = $tmp[0];
      ( $volume = $tmp[1] ) =~ s/.*Volume\s//;
      $volume = ( $volume > 0 ) ? $volume : 'in press';
      ( $issue = $tmp[2] ) =~ s/.*Issue\s//;
      $issue = ( $issue > 0 ) ? $issue : '';
      if ( $tmp[3] =~ m/(Page\s)(.*)/ ) {
        $pages = ( $2 ne '000' ) ? $2 : '';
      }
      if ( $tmp[4] ) {
        if ( $tmp[4] =~ m/(\d+)?(\s[A-Z]+\s)(\d\d\d\d)\..*/i ) {
          $year = $3;
        }
      }
      $description = join( '', @{ $entry->{'description'} } );
    }

    if ( $entry->{'author'} ) {
      my $tmp = join( '', @{ $entry->{'author'} } );
      $tmp =~ s/.*\(//;
      $tmp =~ s/\)//;
      if ( $tmp =~ m/(.*)(et al)$/ ) {
        $authors =
          Paperpile::Library::Author->new()->parse_freestyle($1)->bibtex() . " and {et al.}";
      } else {
        $authors = Paperpile::Library::Author->new()->parse_freestyle($tmp)->bibtex();
      }
    }

    push @output,
      _fill_publication_object(
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
      );
  }

  return [@output];
}

# RSS feeds from source annualreviews.org
# Authors need special handling.
# Bibliographic information is parsed from the description field.
sub _parse_AnnualReviews {

  my $self    = shift;
  my @entries = @{ $_[0] };

  my @output = ();

  foreach my $entry (@entries) {

    my (
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
    );

    $title = _easy_join( 'title', $entry );
    $link  = _easy_join( 'link',  $entry );

    if ( $entry->{'description'} ) {
      my $temp = join( '', @{ $entry->{'description'} } );
      if ( $temp =~ m/(.*)(\sVolume\s)(\d+)(,.*\s)(\d\d\d\d)/ ) {
        $journal = $1;
        $volume  = $3;
        $year    = $5;
      }
      if ( $temp =~ m/(.*Page\s)(\d+-\d+)/ ) {
        $pages = $2;
      }
      $description = join( '', @{ $entry->{'description'} } );
    }

    if ( $entry->{'author'} ) {
      my $tmp = join( '', @{ $entry->{'author'} } );
      $tmp =~ s/.*\(//;
      $tmp =~ s/\)//;
      if ( $tmp =~ m/(.*)(et al)$/ ) {
        $authors =
          Paperpile::Library::Author->new()->parse_freestyle($1)->bibtex() . " and {et al.}";
      } else {
        $authors = Paperpile::Library::Author->new()->parse_freestyle($tmp)->bibtex();
      }
    }

    push @output,
      _fill_publication_object(
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
      );
  }

  return [@output];
}

# RSS feeds from source http://content.karger.com/
# There is no author field and bibliographic information
# is parsed from the description field.
sub _parse_Karger {

  my $self    = shift;
  my @entries = @{ $_[0] };

  my @output = ();

  foreach my $entry (@entries) {

    my (
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
    );

    $title = _easy_join( 'title', $entry );
    $link  = _easy_join( 'link',  $entry );

    if ( $entry->{'description'} ) {
      my $temp = join( '', @{ $entry->{'description'} } );

      # EXAMPLE: Folia Primatol 2009;80:426<96>429 (DOI:10.1159/000276120)
      if ( $temp =~ m/(.*)\s(\d\d\d\d);(\d+):(\d+)\D(\d+)(\s.*DOI:)(10.*)\)/ ) {
        $journal = $1;
        $year    = $2;
        $volume  = $3;
        $pages   = "$4-$5";
        $doi     = $7;
      }
      $description = join( '', @{ $entry->{'description'} } );
    }

    push @output,
      _fill_publication_object(
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
      );
  }

  return [@output];
}

# RSS feeds from source http://ej.iop.org
# Authors are parsed from the description field.
# There is no bibliographic information
sub _parse_IOP {

  my $self          = shift;
  my @entries       = @{ $_[0] };
  my $channel_title = $_[1];

  my @output = ();

  foreach my $entry (@entries) {

    my (
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
    );

    $title = _easy_join( 'title', $entry );
    $link  = _easy_join( 'link',  $entry );

    if ( $entry->{'description'} ) {
      my $temp = join( '', @{ $entry->{'description'} } );

      # parse authors
      my @tmp = split( /<br>/, $temp );
      $tmp[0] =~ s/Author\(s\):\s//;
      my @tmp2 = split( /, | and /, $tmp[0] );
      my @authors_formatted = ();
      foreach my $author (@tmp2) {
        push @authors_formatted,
          Paperpile::Library::Author->new()->parse_freestyle($author)->bibtex();
      }
      $authors = join( " and ", @authors_formatted );

      $description = join( '', @{ $entry->{'description'} } );
    }

    ( $journal = $channel_title ) =~ s/\slatest\spapers//;

    push @output,
      _fill_publication_object(
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
      );
  }

  return [@output];
}

# RSS feeds from source http://journals.cambridge.org
# Authors and  bibliographic information are parsed from
# the description field.
sub _parse_CambridgeJournals {

  my $self          = shift;
  my @entries       = @{ $_[0] };
  my $channel_title = $_[1];

  my @output = ();

  foreach my $entry (@entries) {

    my (
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
    );

    $title = _easy_join( 'title', $entry );
    $title =~ s/\s+/ /g;
    $link = _easy_join( 'link', $entry );

    if ( $entry->{'description'} ) {
      my $temp = join( '', @{ $entry->{'description'} } );
      my @tmp = split( /<br \/>/, $temp );
      $tmp[1] =~ s/\s+$//;
      if ( $tmp[1] =~ m/,$/ ) {
        my @tmp2 = split( /,/, $tmp[1] );
        my @authors_formatted = ();
        foreach my $author (@tmp2) {
          push @authors_formatted,
            Paperpile::Library::Author->new()->parse_freestyle($author)->bibtex();
        }
        $authors = join( " and ", @authors_formatted );
      }

      if ( $temp =~ m/Volume\s(\d+)/ ) {
        $volume = $1;
      }
      if ( $temp =~ m/Issue\s(\d+)/ ) {
        $issue = $1;
      }
      if ( $temp =~ m/pp\s(\d+-\d+)/ ) {
        $pages = $1;
      }

      $description = join( '', @{ $entry->{'description'} } );
    }

    ( $journal = $channel_title ) =~ s/\scurrent\sissue//i;

    push @output,
      _fill_publication_object(
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
      );
  }

  return [@output];
}

# RSS feeds from source http://ovidsp.ovid.com
# Parts of bibliographic data are parsed from channel_title.
# Authors are taken from the description field.
# It is cumbersopme to get rid of all the titles.
# Pages are taken from the description field.
sub _parse_Ovid {

  my $self          = shift;
  my @entries       = @{ $_[0] };
  my $channel_title = $_[1];

  my @output = ();

  foreach my $entry (@entries) {

    my (
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
    );

    $title = _easy_join( 'title', $entry );
    $title =~ s/\s+/ /g;
    $link = _easy_join( 'link', $entry );

    if ( $entry->{'description'} ) {
      my $temp = join( '', @{ $entry->{'description'} } );
      my @tmp  = split( /\n/, $temp );
      my @tmp2 = split( /;/,  _remove_html_tags( $tmp[3] ) );
      my @authors_formatted = ();
      foreach my $author (@tmp2) {
        my @tmp3 = split( /,/, $author );
        if ( $#tmp3 > 1 ) {
          $author = "$tmp3[0], $tmp3[1]";
        }

        $author =~ s/(\d,|\d)//g;
        $author =~
          s/(PhD|MD|MHA|MPH|MSc|BSc|DrPH|CGC|MSN|MS|CCRC|BSN|BS|DNSc|J\.\sEdD|RN|ADN|BA|MNS|MB|BNS|PharmD|MA|ChB)//g;
        $author =~ s/\[.*\]//g;
        $author =~ s/(\+|\*)//g;
        $author =~ s/(.*)(\s[A-Z]{2,})/$1/;
        $author =~ s/^\s+//;
        $author =~ s/\s+$//;
        $author =~ s/,$//;
        $author =~ s/\s+$//;
        $author =~ s/\s+/ /;
        push @authors_formatted, $author;
      }
      $authors = join( " and ", @authors_formatted );

      if ( $tmp[7] =~ m/(\d+-\d+)/ ) {
        $pages = $1;
      }
      if ( $tmp[7] =~ m/(\d+)/ and !$pages ) {
        $pages = $1;
      }

      $description = join( '', @{ $entry->{'description'} } );
    }

    ( $journal = $channel_title ) =~ s/(.*)(\.\s.*)/$1/;

    if ( $channel_title =~ m/Volume\s(\d+)/ ) {
      $volume = $1;
    }

    if ( $channel_title =~ m/Volume\s\d+\((.*)\)/ ) {
      $issue = $1;
    }

    if ( $channel_title =~ m/(2\d\d\d)$/ ) {
      $year = $1;
    }

    push @output,
      _fill_publication_object(
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
      );
  }

  return [@output];
}

# RSS feeds from source http://la-press.com
# No bibliographic information.
# Authors are parsed from description field.
sub _parse_LAPress {

  my $self          = shift;
  my @entries       = @{ $_[0] };
  my $channel_title = $_[1];

  my @output = ();

  foreach my $entry (@entries) {

    my (
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
    );

    $title = _easy_join( 'title', $entry );
    $link  = _easy_join( 'link',  $entry );

    if ( $entry->{'description'} ) {
      #my $temp = join( '', @{ $entry->{'description'} } );
      #my @tmp2 = split( /, | and /, $temp );
      #my @authors_formatted = ();
      #foreach my $author (@tmp2) {
      #  push @authors_formatted,
      #    Paperpile::Library::Author->new()->parse_freestyle($author)->bibtex();
      #}
      #$authors = join( " and ", @authors_formatted );
      $authors = 'Unknown';
      if ( $entry->{'description'}->[0] !~ m/^HASH\(/ ) {
	$description = join( '', @{ $entry->{'description'} } );
      }
    }

    if ( $entry->{'pubDate'} and !$year ) {
      my $tmp = join( '', @{ $entry->{'pubDate'} } );
      if ( $tmp =~ m/^[A-Z]+\s+(\d\d\d\d)$/i ) {
        $year = $1;
      }
      if ( $tmp =~ m/\d{1,2}\s+[A-Z]{3}\s+(\d\d\d\d)/i ) {
        $year = $1;
      }
    }

    ( $journal = $channel_title ) =~ s/(.*)(\.\s.*)/$1/;

    push @output,
      _fill_publication_object(
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
      );
  }

  return [@output];
}

# RSS feeds from source metapress.com
# Everything must be parsed from the
# description field.
sub _parse_Metapress {

  my $self          = shift;
  my @entries       = @{ $_[0] };
  my $channel_title = $_[1];

  my @output = ();

  foreach my $entry (@entries) {

    my (
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
    );

    $title = _easy_join( 'title', $entry );
    $link  = _easy_join( 'link',  $entry );

    if ( $entry->{'description'} ) {
      my $temp = join( '', @{ $entry->{'description'} } );

      # there is great HTML markup
      $temp =~ s/([^[:ascii:]])/sprintf("&#%d;",ord($1))/eg;
      $temp = "<html><body>$temp</body></html>";

      my $tree = HTML::TreeBuilder::XPath->new;
      $tree->utf8_mode(1);
      $tree->parse_content($temp);
      my @authors           = $tree->findnodes('/html/body/ul/li/ul/li');
      my @authors_formatted = ();
      foreach my $author (@authors) {
        my @tmp = split( /,/, $author->as_text() );
        push @authors_formatted,
          Paperpile::Library::Author->new()->parse_freestyle( $tmp[0] )->bibtex();
      }
      $authors = join( " and ", @authors_formatted );

      my @details = $tree->findnodes('/html/body/ul/ul/li/span/a');
      $journal = $details[0]->as_text();
      if ( $details[1] ) {
        if ( $details[1]->as_text() =~ m/Volume\s(\d+),\sNumber\s(\d+)\s.*\s(\d{4})$/ ) {
          $volume = $1;
          $issue  = $2;
          $year   = $3;
        }
      }

      if ( !$volume and !$issue ) {
        if ( $temp =~ m/Volume\s(\d+)/ ) {
          $volume = $1;
        }
        if ( $temp =~ m/Number\s(\d+)/ ) {
          $issue = $1;
        }
      }

      if ( $temp =~ m/<li>DOI (10\..*)<\/li>/ ) {
        $doi = $1;
      }

      $description = join( '', @{ $entry->{'description'} } );
    }

    push @output,
      _fill_publication_object(
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
      );
  }

  return [@output];
}

# RSS feeds from source http://emeraldinsight.com
# No bibliographic information.
sub _parse_Emerald {

  my $self          = shift;
  my @entries       = @{ $_[0] };
  my $channel_title = $_[1];

  my @output = ();

  foreach my $entry (@entries) {

    my (
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
    );

    $title = _easy_join( 'title', $entry );
    $link  = _easy_join( 'link',  $entry );

    my @authors = split( /, /, _easy_join( 'author', $entry ) );
    my @authors_formatted = ();
    foreach my $author (@authors) {
      push @authors_formatted,
        Paperpile::Library::Author->new()->parse_freestyle($author)->bibtex();
    }
    $authors = join( " and ", @authors_formatted );

    if ( $entry->{'description'} ) {
      $description = join( '', @{ $entry->{'description'} } );
    }

    ( $journal = $channel_title ) =~ s/(.*)(\.\s.*)/$1/;
    $journal =~ s/\s+$//;

    if ( $link =~ m/emeraldinsight\.com\/(10\.\d\d\d.*)/ ) {
      $doi = $1;
    }

    push @output,
      _fill_publication_object(
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
      );
  }

  return [@output];
}

# RSS feeds from source http://www.bioone.org
# Bibliographic information is parsed from
# description field. Authors needs special handling.
sub _parse_BioOne {

  my $self    = shift;
  my @entries = @{ $_[0] };

  my @output = ();

  foreach my $entry (@entries) {

    my (
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
    );

    $title = _easy_join( 'title', $entry );
    $link  = _easy_join( 'link',  $entry );

    if ( $entry->{'description'} ) {
      my $temp = join( '', @{ $entry->{'description'} } );
      if ( $temp =~ m/(.*)(\sVolume\s)(\d+)(,.*\s)(\d\d\d\d)/ ) {
        $journal = $1;
        $volume  = $3;
        $year    = $5;
      }
      if ( $temp =~ m/(.*Page\s)(\d+-\d+)/ ) {
        $pages = $2;
      }
      if ( $temp =~ m/(.*Page\s)(\d+)/ and !$pages ) {
        $pages = $2;
      }
      if ( $temp =~ m/(.*Issue\s)(\d+)/ ) {
        $issue = $2;
      }
      $description = join( '', @{ $entry->{'description'} } );
    }

    if ( $entry->{'author'} ) {
      my $tmp = join( '', @{ $entry->{'author'} } );
      $tmp =~ s/.*\(//;
      $tmp =~ s/\)//;
      if ( $tmp =~ m/(.*)(et al)$/ ) {
        $authors =
          Paperpile::Library::Author->new()->parse_freestyle($1)->bibtex() . " and {et al.}";
      } else {
        $authors = Paperpile::Library::Author->new()->parse_freestyle($tmp)->bibtex();
      }
    }

    if ( $link =~ m/doi\/abs\/(10.\d\d\d\d\/.*)\?/ ) {
      $doi = $1;
    }

    push @output,
      _fill_publication_object(
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
      );
  }

  return [@output];
}

# RSS feeds from source http://www.liebertonline.com
# Bibliographic information is parsed from
# description field. Authors needs special handling.
sub _parse_Liebert {

  my $self    = shift;
  my @entries = @{ $_[0] };

  my @output = ();

  foreach my $entry (@entries) {

    my (
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
    );

    $title = _easy_join( 'title', $entry );
    $link  = _easy_join( 'link',  $entry );

    if ( $entry->{'description'} ) {
      my $temp = join( '', @{ $entry->{'description'} } );

      if ( $temp =~ m/Vol\.\s(\d+)/ ) {
        $volume = ( $1 > 0 ) ? $1 : 'in press';
      }
      if ( $temp =~ m/No\.\s(\d+)/ ) {
        $issue = ( $1 > 0 ) ? $1 : '';
      }
      if ( $temp =~ m/:\s(\d+-\d+)\./ ) {
        $pages = $1;
      }
      if ( $temp =~ m/(.*)(\s+[A-Z]{3}\s)(\d{4})/i ) {
        $journal = $1;
        $journal =~ s/\s+$//;
        $year = $3;
      }
      if ( $temp =~ m/\s(\d{4}),/i and !$year ) {
        $year = $1;
      }

      if ( $temp =~ m/(.*)\s,\sVol\.\s0,/ and !$journal ) {
        $journal = $1;
      }

      $description = join( '', @{ $entry->{'description'} } );
    }

    if ( $entry->{'author'} ) {
      my $tmp = join( '', @{ $entry->{'author'} } );
      $tmp =~ s/.*\(//;
      $tmp =~ s/\)//;
      if ( $tmp =~ m/(.*)(et al)$/ ) {
        $authors =
          Paperpile::Library::Author->new()->parse_freestyle($1)->bibtex() . " and {et al.}";
      } else {
        $authors = Paperpile::Library::Author->new()->parse_freestyle($tmp)->bibtex();
      }
    }

    if ( $link =~ m/doi\/abs\/(10.\d\d\d\d\/.*)\?/ ) {
      $doi = $1;
    }

    push @output,
      _fill_publication_object(
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
      );
  }

  return [@output];
}

# RSS feeds from source http://www.dovepress.com
# No bibliographic information.
# Authors are parsed from description field.
sub _parse_DovePress {

  my $self          = shift;
  my @entries       = @{ $_[0] };
  my $channel_title = $_[1];

  my @output = ();

  foreach my $entry (@entries) {

    my (
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
    );

    $title = _easy_join( 'title', $entry );
    $link  = _easy_join( 'link',  $entry );

    if ( $entry->{'description'} ) {
      my $temp = join( '', @{ $entry->{'description'} } );
      my @authors = split( /, /, $temp );
      my @authors_formatted = ();
      foreach my $author (@authors) {
        if ( $author !~ m/et\sal/ ) {
          push @authors_formatted,
            Paperpile::Library::Author->new()->parse_freestyle($author)->bibtex();
        } else {
          push @authors_formatted, "{et al.}";
        }
      }
      $authors = join( " and ", @authors_formatted );

      $description = join( '', @{ $entry->{'description'} } );
    }

    ( $journal = $channel_title ) =~ s/(.*)(\.\s.*)/$1/;
    $journal =~ s/\s+$//;

    push @output,
      _fill_publication_object(
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
      );
  }

  return [@output];
}

# PLoS journals use some really weird XML style

sub _parse_PLoS {

  my $self    = shift;
  my @entries = @{ $_[0] };

  my @output = ();

  foreach my $entry (@entries) {

    my (
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
    );

    # journal name is parsed from the channel title
    ( $journal = $self->title ) =~ s/(.*)(:.*)/$1/;
    $journal =~ s/\sAlerts//g;

    $title = _easy_join( 'title', $entry );

    # usually the form first author et al.
    if ( $entry->{'author'}->[0]->{name}->[0] ) {
      my $tmp               = $entry->{'author'}->[0]->{name}->[0];
      my @authors_formatted = ();
      if ( $tmp =~ m/(.*)\set\sal\./ ) {
        push @authors_formatted, Paperpile::Library::Author->new()->parse_freestyle($1)->bibtex();
        push @authors_formatted, "{et al.}";
      }
      $authors = join( " and ", @authors_formatted );
    }

    # several linkouts (html/xml/pdf)
    foreach my $links ( @{ $entry->{'link'} } ) {
      if ( $links->{'rel'} eq 'alternate' ) {
        $link = $links->{'href'};
      }
    }

    # doi
    if ( $entry->{'id'}->[0] ) {
      ( $doi = $entry->{'id'}->[0] ) =~ s/info:doi\///;
    }

    # year
    if ( $entry->{'published'}->[0] ) {
      ( $year = $entry->{'published'}->[0] ) =~ s/^(\d\d\d\d)(-.*)/$1/;
    }

    # abstract
    if ( $entry->{'content'}->{'content'} ) {
      $description = $entry->{'content'}->{'content'};
    }

    push @output,
      _fill_publication_object(
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
      );
  }

  return [@output];
}

# RSS feeds from source http://aip.org
# Bibliographic information and authors
# are parsed from description field.
sub _parse_AIP {

  my $self          = shift;
  my @entries       = @{ $_[0] };
  my $channel_title = $_[1];

  my @output = ();

  foreach my $entry (@entries) {

    my (
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
    );

    $title = _easy_join( 'title', $entry );
    $link  = _easy_join( 'link',  $entry );

    if ( $entry->{'description'} ) {
      my $temp = join( '', @{ $entry->{'description'} } );
      my @temp2 = split(/<br\/>/, $temp );

      my @authors_formatted = ();
      my @temp3 = split(/,|\sand\s/, $temp2[0] );
      foreach my $entry (@temp3) {
	if ( $entry ne '' ) {
	  if ( $entry =~ m/(.*)(et al\.)$/ ) {
	    push @authors_formatted,
	      Paperpile::Library::Author->new()->parse_freestyle($1)->bibtex() . " and {et al.}";
	  } else {
	    push @authors_formatted,
	      Paperpile::Library::Author->new()->parse_freestyle($entry)->bibtex();
	  }
	}
      }
      $authors = join( " and ", @authors_formatted );

      # bibliographic information
      (my $temp4 = $temp2[1]) =~ s/(.*\[)(.*)(\].*)/$2/;
      ( $journal = $temp4 ) =~ s/(.*)(\s\d+,.*)/$1/;
      ( $year = $temp4 ) =~ s/(.*\()(\d\d\d\d)(\).*)/$2/;
      ( $volume = $temp4 ) =~ s/(.*\s)(\d+)(,.*)/$2/;
      ( $pages = $temp4 ) =~ s/(.*,\s)(\d+)(\s\(.*)/$2/;
      $description = $temp2[1];
    }

    push @output,
      _fill_publication_object(
      $title, $authors, $description, $doi,   $journal, $volume,
      $issue, $year,    $link,        $pages, $note
      );
  }

  return [@output];
}


##################################################################################
# Section of helper functions
##################################################################################

sub _easy_join {

  my $string = $_[0];
  my $entry  = $_[1];

  if ( $entry->{$string} ) {
    return join( '', @{ $entry->{$string} } );
  }

  return;
}

sub _fill_publication_object {

  my ( $title, $authors, $description, $doi, $journal, $volume, $issue, $year, $link, $pages,
    $note ) = @_;

  if ( $link ) {
    if ( $link =~ m/dx\.doi\.org\/(\d\d\.\d{4}.*)/ ) {
      $doi = $1;
    }
  }

  if ( $authors ) {
    $authors =~ s/<\/br>//g;
  }

  if ( $title ) {
    $authors =~ s/<\/br>//g;
  }

  my $pub = Paperpile::Library::Publication->new( pubtype => 'ARTICLE' );

  $pub->title($title)          if ($title);
  $pub->authors($authors)      if ($authors);
  $pub->abstract($description) if ($description);
  $pub->doi($doi)              if ($doi);
  $pub->journal($journal)      if ($journal);
  $pub->volume($volume)        if ($volume);
  $pub->issue($issue)          if ($issue);
  $pub->year($year)            if ($year);
  $pub->pages($pages)          if ($pages);
  $pub->linkout($link)         if ($link);

  return $pub;
}

sub _remove_html_tags {
  my $string = $_[0];

  my @tags = ( 'b', 'strong', 'span' );

  foreach my $tag (@tags) {
    $string =~ s/<$tag>//g;
    $string =~ s/<\/$tag>//g;
  }

  return $string;
}

sub write {

}

1;

