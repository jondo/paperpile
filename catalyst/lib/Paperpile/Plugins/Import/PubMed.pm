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


package Paperpile::Plugins::Import::PubMed;

use Carp;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;
use XML::Simple;
use URI::Escape;
use 5.010;

use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Paperpile::Utils;

extends 'Paperpile::Plugins::Import';

# The database query which is passed to PubMed
has 'query' => ( is => 'rw' );

# The PubMed API saves session information for a query via two
# variables
has 'web_env'   => ( is => 'rw' );
has 'query_key' => ( is => 'rw' );

# URLs for PubMed resources at NCBI
my $esearch =
  "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=PubMed&usehistory=y&retmax=1&term=";
my $efetch = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?retmode=xml&db=PubMed";
my $elink_linkout =
  "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?retmode=ref&cmd=prlinks&db=PubMed&";
my $elink_related =
  "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?dbfrom=pubmed&db=pubmed&id=";
my $espell = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/espell.fcgi?&db=PubMed&term=";
my $epost  = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/epost.fcgi?db=pubmed&id=";

sub BUILD {
  my $self = shift;
  $self->plugin_name('PubMed');
}

sub _EscapeString {
  my $string = $_[0];

  # remove leading spaces
  $string =~ s/^\s+//;

  # remove spaces at the end
  $string =~ s/\s+$//;

  # escape each single word and finally join
  # with plus signs
  my @tmp = split( /\s+/, $string );
  foreach my $i ( 0 .. $#tmp ) {
    $tmp[$i] = uri_escape_utf8( $tmp[$i] );
  }

  return join( "+", @tmp );
}

sub _FormatQueryString {
  my $query                  = $_[0];
  my $formatted_query_string = '';

  # let's see if we have signal words
  my $special_words = 0;

  $special_words = 1 if ( $query =~ m/(author:|title:|journal:)/ );

  # there are no special words so we just do a regular escaping
  if ( $special_words == 0 ) {
      # temporary fix for issue 1014
      # Problem description: words like "a", "an", ...
      # are not index in pubmed. If a string contains "a" it is not mapped to [All fields] 
      # but only to [Author], for example. Even assigning [All fields] does not help.
      # For now we just remove it, until we have a unified interface to process query strings.
      $query =~ s/\s+a\s+/ /g;

      $formatted_query_string = _EscapeString($query);
  } else {
    my @blocks = split( /(author:|title:|journal:)/, $query );
    shift(@blocks) if ( !$blocks[0] );

    my @tmp_query = ();
    for ( my $i = 0 ; $i <= $#blocks ; $i++ ) {

      #print STDERR "$i :: $blocks[$i]\n";
      if ( $blocks[$i] =~ m/^author:$/i ) {
        if ( defined $blocks[ $i + 1 ] ) {
          push @tmp_query, _EscapeString( '"' . $blocks[ $i + 1 ] . '"' . "[Author]" );
        }
        $i++;
      }
      if ( $blocks[$i] =~ m/^title:$/i ) {
        if ( defined $blocks[ $i + 1 ] ) {
          push @tmp_query, _EscapeString( '"' . $blocks[ $i + 1 ] . '"' . "[Title]" );
        }
        $i++;
      }
      if ( $blocks[$i] =~ m/^journal:$/i ) {
        if ( defined $blocks[ $i + 1 ] ) {
          push @tmp_query, _EscapeString( '"' . $blocks[ $i + 1 ] . '"' . "[Journal]" );
        }
        $i++;
      }

      #print STDERR "   $i :: $blocks[$i]\n";
    }
    $formatted_query_string = join( "+", @tmp_query );

    #print STDERR "BLOCKS :: ",join("+", @blocks)," --> $formatted_query_string\n";

    #$formatted_query_string = $query;
  }

  return $formatted_query_string;
}

sub connect {
  my $self = shift;

  # First we get a LWP user agent. We always should get it via the
  # Utils function because this way we get a correctly configured
  # browser. Additional configuration can be added afterwards if
  # needed.
  my $browser = Paperpile::Utils->get_browser;

  # We send our query to PubMed via a simple get
  my $query_string = _FormatQueryString( $self->query );
  my $response     = $browser->get( $esearch . $query_string );

  print STDERR "$esearch$query_string\n";

  if ( $response->is_error ) {
    NetGetError->throw(
      error => 'PubMed query failed: ' . $response->message,
      code  => $response->code
    );
  }

  # The response is XML formatted and can be parsed with XML::Simple
  my $resultXML = $response->content;
  my $result    = XMLin($resultXML);

  if ( ( not defined $result->{WebEnv} )
    or ( not defined $result->{QueryKey} )
    or ( not defined $result->{Count} ) ) {
    NetFormatError->throw(
      error   => 'PubMed query failed: unknown return format',
      content => $response->content
    );
  }

  # The relevant results are stored in the appropriate fields
  $self->web_env( $result->{WebEnv} );
  $self->query_key( $result->{QueryKey} );
  $self->total_entries( $result->{Count} );

  # The function must return the total number of search results.
  return $self->total_entries;
}

sub page {
  ( my $self, my $offset, my $limit ) = @_;

  # We have split the functionality to three functions:
  # _pubFetch, _read_xml, _link_out
  my $xml = $self->_pubFetch( $offset, $limit );
  my $page = $self->_read_xml($xml);
  $self->_linkOut($page);

  # We clear the cache on every page
  $self->clear_cache();
  Paperpile::Utils->uniquify_pubs([@$page]);

  # we should always call this function to make the results available
  # afterwards via find_guid
  $self->_save_page_to_hash($page);


  return $page;
}

sub all {
  ( my $self ) = @_;

  return $self->page( 0, 100 );

}

# Match function to match publication-objects
# against Pubmed.

sub match {

  ( my $self, my $pub ) = @_;

  my $query_pmid    = '';
  my $query_doi     = '';
  my $query_title   = '';
  my $query_authors = '';
  my @title_words   = ();

  # First we format the three query strings properly. Besides
  # HTML escaping we remove words that contain non-alphnumeric
  # characters. These words can cause severe problems.

  # 0) Pubmed ID
  $query_pmid = _EscapeString( $pub->pmid . "[PMID]" ) if ( $pub->pmid );

  # 1) DOI
  $query_doi = _EscapeString( $pub->doi . "[AID]" ) if ( $pub->doi );

  # 2) Title
  if ( $pub->title ) {
    my @tmp = ();
    ( my $tmp_title = $pub->title ) =~ s/(\(|\)|-|\.|,|:|;|\{|\}|\?|!)/ /g;
    foreach my $word ( split( /\s+/, $tmp_title ) ) {

      # words that contain non-alphnumeric and non-ascii
      # characters are removed
      next if ( $word =~ m/[^\w\s-]/ );
      next if ( $word =~ m/[^[:ascii:]]/ );
      push @title_words, $word;

      # words with less than 3 characters are removed
      next if ( length($word) < 3 );

      # Pubmed stopwords are not searched and the query will
      # fail if we keep them
      # the list is taken from here: http://www.ncbi.nlm.nih.gov/
      # bookshelf/br.fcgi?book=helppubmed&part=pubmedhelp&
      # rendertype=table&id=pubmedhelp.T43
      # last line contains other words that might cause problems. They
      # may be in the title for PDF parsing errors.

      my @pubmed_stopwords = (
        "about",         "again",      "all",      "almost",
        "also",          "although",   "always",   "among",
        "and",           "another",    "any",      "are",
        "because",       "been",       "before",   "being",
        "between",       "both",       "but",      "can",
        "could",         "did",        "does",     "done",
        "due",           "during",     "each",     "either",
        "enough",        "especially", "etc",      "for",
        "found",         "from",       "further",  "had",
        "has",           "have",       "having",   "here",
        "how",           "however",    "into",     "its",
        "itself",        "just",       "made",     "mainly",
        "make",          "may",        "might",    "most",
        "mostly",        "must",       "nearly",   "neither",
        "nor",           "not",        "obtained", "often",
        "our",           "overall",    "perhaps",  "pmid",
        "quite",         "rather",     "really",   "regarding",
        "seem",          "seen",       "several",  "should",
        "show",          "showed",     "shown",    "shows",
        "significantly", "since",      "some",     "such",
        "than",          "that",       "the",      "their",
        "theirs",        "them",       "then",     "there",
        "therefore",     "these",      "they",     "this",
        "those",         "through",    "thus",     "upon",
        "use",           "used",       "using",    "various",
        "very",          "was",        "were",     "what",
        "when",          "which",      "while",    "with",
        "within",        "without",    "would",    "review",
        "article"
      );
      my $flag = 0;
      foreach my $stop_word (@pubmed_stopwords) {
        if ( lc($word) eq $stop_word ) {
          $flag = 1;
          last;
        }
      }
      next if ( $flag == 1 );

      # Add Title-tag
      push @tmp, "$word\[Title]";
    }
    $query_title = _EscapeString( join( " AND ", @tmp ) );
  }

  # 3) Authors. We just use each author's last name
  # At the moment we use the first two authors at most.
  if ( $pub->authors ) {
    my @tmp = ();
    my $max_number = 2;
    my $nr_authors = 0;
    foreach my $author ( @{ $pub->get_authors } ) {

      # words that contain non-alphnumeric and non-ascii
      # characters are removed
      next if ( $author->last =~ m/[^\w\s-]/ );
      next if ( $author->last =~ m/[^[:ascii:]]/ );
      next if ( $nr_authors >= $max_number );
      $nr_authors++;
      push @tmp, $author->last . "[au]";
    }
    $query_authors = _EscapeString( join( " AND ", @tmp ) );
  }

  # SEARCH STRATEGY:
  # 0) Use PMID if available
  # 1) Use DOI if available: This is the best strategy if a DOI is available,
  #    but it might happen that there are parsing errors in the DOI.
  # 2) Title+Authors: Most stringent, but parsing errors and strange characters
  #    in the PDF can cause troubles.
  # 3) Just Title: If everything till this point failed.

  my $browser = Paperpile::Utils->get_browser;

  if ( $query_pmid ne '' ) {
    my $response = $browser->get( $esearch . $query_pmid );
    Paperpile::Utils->check_browser_response($response);

    my $resultXML = $response->content;
    my $result    = XMLin($resultXML);

    #print STDERR "$esearch$query_pmid\n";
    # If we get exactly one result then the DOI was really unique
    # and in most cases we are done.
    if ( $result->{Count} == 1 ) {
      $self->web_env( $result->{WebEnv} );
      $self->query_key( $result->{QueryKey} );

      my $xml = $self->_pubFetch( 0, 1 );
      my $page = $self->_read_xml($xml);
      $self->_linkOut($page);

      if ( $page->[0]->pmid eq $pub->pmid ) {
        return $self->_merge_pub( $pub, $page->[0] );
      }
    }
  }

  if ( $query_doi ne '' ) {
    my $response  = $browser->get( $esearch . $query_doi );
    Paperpile::Utils->check_browser_response($response);
    my $resultXML = $response->content;
    my $result    = XMLin($resultXML);

    # If we get exactly one result then the DOI was really unique
    # and in most cases we are done.
    if ( $result->{Count} == 1 ) {
      $self->web_env( $result->{WebEnv} );
      $self->query_key( $result->{QueryKey} );

      my $xml = $self->_pubFetch( 0, 1 );
      my $page = $self->_read_xml($xml);
      $self->_linkOut($page);

      if ( $page->[0]->doi eq $pub->{doi} ) {
        return $self->_merge_pub( $pub, $page->[0] );
      }
    }
  }

  # If we are here then the DOI was not conducted or did not work.
  # We try a search using the title/authors now.
  if ( $query_title ne '' and $query_authors ne '' ) {

    #print STDERR "$esearch$query_title+$query_authors\n";
    # Pubmed is queried using title and authors
    my $response  = $browser->get( $esearch . "$query_title+$query_authors" );
    Paperpile::Utils->check_browser_response($response);
    my $resultXML = $response->content;
    my $result    = XMLin($resultXML);

    # If some errors popup we adjust our query string and query again
    if ( $result->{ErrorList}->{PhraseNotFound} ) {
      my @badtmp = ();
      if ( $result->{ErrorList}->{PhraseNotFound} =~ m/^ARRAY/ ) {
        @badtmp = @{ $result->{ErrorList}->{PhraseNotFound} };
      } else {
        push @badtmp, $result->{ErrorList}->{PhraseNotFound};
      }
      foreach my $badword (@badtmp) {
        $badword = _EscapeString($badword);
        $query_title   =~ s/(\+AND\+)?$badword//;
        $query_authors =~ s/(\+AND\+)?$badword//;
      }

      # now query again
      $response  = $browser->get( $esearch . "$query_title+$query_authors" );
      Paperpile::Utils->check_browser_response($response);
      $resultXML = $response->content;
      $result    = XMLin($resultXML);
    }

    # Let's check if the query returned any results and if
    # the publication of interest is contained. The Top 5
    # results are checked.
    if ( $result->{Count} > 0 ) {
      $self->web_env( $result->{WebEnv} );
      $self->query_key( $result->{QueryKey} );
      my $xml = $self->_pubFetch( 0, 5 );
      my $page = $self->_read_xml($xml);
      $self->_linkOut($page);
      my $max = ( $result->{Count} > 5 ) ? 4 : $result->{Count} - 1;

      # if there is only one result, we belive it and return
      # Note: Sometimes we delete some words from the title (maybe
      # parsing errors, e.g. review, ...) and the two titles do not
      # match

      return $self->_merge_pub( $pub, $page->[0] ) if ( $max == 0 );
      foreach my $i ( 0 .. $max ) {
        if ( $self->_match_title( $page->[$i]->title, $pub->title ) ) {
          return $self->_merge_pub( $pub, $page->[$i] );
        }
      }
    }

  }

  # If we are here then Title+Auhtors failed, and we try to search
  # only with the title.
  if ( $query_title ne '' ) {
    my $response  = $browser->get( $esearch . "$query_title" );
    Paperpile::Utils->check_browser_response($response);
    my $resultXML = $response->content;
    my $result    = XMLin($resultXML);

    # Let's check if the query returned any results and if
    # the publication of interest is contained. The Top 5
    # results are checked.

    if ( $result->{Count} > 0 ) {
      $self->web_env( $result->{WebEnv} );
      $self->query_key( $result->{QueryKey} );

      my $xml = $self->_pubFetch( 0, 5 );
      my $page = $self->_read_xml($xml);
      $self->_linkOut($page);
      my $max = ( $result->{Count} > 5 ) ? 4 : $result->{Count} - 1;
      foreach my $i ( 0 .. $max ) {

        # there are often PDF parsing errors so we cannot do a
        # simple string comparison
        my $counts          = 0;
        my $to_compare_with = ' ' . $page->[$i]->title . ' ';
        foreach my $word (@title_words) {
          $counts++ if ( $to_compare_with =~ m/\s$word\s/i );
        }
        my $words_current_title = ( $page->[$i]->title =~ tr/ // );
        if ( $counts > $#title_words and $counts / $words_current_title >= 0.9 ) {
          return $self->_merge_pub( $pub, $page->[$i] );
        }
      }
    }
  }

  # If we are here then our search against Pubmed was not successful.
  NetMatchError->throw( error => 'No match against PubMed.' );

  #return $pub; # comment in for command line testing
}

sub web_lookup {

  my ( $self, $url, $content ) = @_;

  #my $pmid;

  $url =~ /pubmed\/(\d+)/;

  my $pmid = $1;

  my $browser   = Paperpile::Utils->get_browser;
  my $response  = $browser->get( $esearch . $pmid );
  Paperpile::Utils->check_browser_response($response);
  my $resultXML = $response->content;
  my $result    = XMLin($resultXML);

  if ( $result->{Count} == 0 ) {
    NetMatchError->throw( error => 'Could not find entry in PubMed' );
  }

  $self->web_env( $result->{WebEnv} );
  $self->query_key( $result->{QueryKey} );
  $self->total_entries( $result->{Count} );

  my $xml = $self->_pubFetch( 0, 100 );
  my $page = $self->_read_xml($xml);
  $self->_linkOut($page);

  return $page;

}

# function: _pubFetch

# Sends request to PubMed for page given by $offset and $limit and
# returns XML output.

sub _pubFetch {

  ( my $self, my $offset, my $limit ) = @_;

  my $browser   = Paperpile::Utils->get_browser;
  my $query_key = $self->query_key;
  my $web_env   = $self->web_env;

  my $url      = "$efetch&query_key=$query_key&WebEnv=$web_env&retstart=$offset&retmax=$limit";
  my $response = $browser->get($url);

  Paperpile::Utils->check_browser_response($response,'PubMed query failed');

  my $resultXML = $response->content;

  return $resultXML;

}

# function: _read_xml

# Parses the PubMed XML format and converts it into a list of
# Paperpile::Library::Publication entries.

sub _read_xml {

  ( my $self, my $xml ) = @_;

  my $result = XMLin( $xml, keyattr => ['IdType'], SuppressEmpty => 1 );

  my $result_ok = 0;

  # Eval to avoid exception when $result is not a hashref
  eval { $result_ok = 1 if ( defined $result->{PubmedArticle} ); };

  if ( $@ or !$result_ok ) {
    NetFormatError->throw(
      error   => 'PubMed query failed: unknown return format',
      content => $xml
    );
  }

  my @output = ();

  my @list;

  if ( ref( $result->{PubmedArticle} ) eq 'ARRAY' ) {
    @list = @{ $result->{PubmedArticle} };
  } else {
    @list = ( $result->{PubmedArticle} );
  }

  foreach my $article (@list) {

    my $cit = $article->{MedlineCitation};
    my $pub = Paperpile::Library::Publication->new( pubtype => 'ARTICLE' );

    $pub->pmid( $cit->{PMID}->{content} );

    my $volume = $cit->{Article}->{Journal}->{JournalIssue}->{Volume};
    my $issue  = $cit->{Article}->{Journal}->{JournalIssue}->{Issue};

    my $year = '';
    if ( exists $cit->{Article}->{Journal}->{JournalIssue}->{PubDate}->{Year} ) {
      $year = $cit->{Article}->{Journal}->{JournalIssue}->{PubDate}->{Year};
    } elsif ( exists $cit->{Article}->{Journal}->{JournalIssue}->{PubDate}->{MedlineDate} ) {
      my $meddate = $cit->{Article}->{Journal}->{JournalIssue}->{PubDate}->{MedlineDate};

      # TODO: Can a medline date be any string?
      # Should probably be parsed via a date parser module.
      if ( $meddate =~ /(\d\d\d\d)/ ) {
        $year = $1;
      } else {
        print STDERR "Warning: could not parse medline date '$meddate'";
      }
    }

    my $month  = $cit->{Article}->{Journal}->{JournalIssue}->{PubDate}->{Month};
    my $pages  = $cit->{Article}->{Pagination}->{MedlinePgn};

    # check if abstract is given as blank string or in a more complex format
    my $abstract = '';
    if ( ref( $cit->{Article}->{Abstract}->{AbstractText} ) eq ''
      || ref( $cit->{Article}->{Abstract}->{AbstractText} ) eq 'SCALAR' ) {
      $abstract = $cit->{Article}->{Abstract}->{AbstractText};
    } elsif ( ref( $cit->{Article}->{Abstract}->{AbstractText} ) eq 'ARRAY' ) {
      foreach my $absPart ( @{ $cit->{Article}->{Abstract}->{AbstractText} } ) {
        if ( exists $absPart->{Label} ) {
          $abstract .= $absPart->{Label};
          $abstract =~ s/\s+$//g;    # remove endstanding spaces
          $abstract .= ": " if ( $abstract !~ /:$/ );
        }

        if ( exists $absPart->{content} ) {
          $abstract .= $absPart->{content};
          $abstract =~ s/\s+$//g;    # remove endstanding spaces
          $abstract .= ' ';
        }
      }
    }

    my $title       = $cit->{Article}->{ArticleTitle};
    my $status      = $article->{PubmedData}->{PublicationStatus};
    my $journal     = $cit->{MedlineJournalInfo}->{MedlineTA};
    my $issn        = $cit->{Article}->{Journal}->{ISSN}->{content};
    my $affiliation = $cit->{Article}->{Affiliation};

    my $doi = $article->{PubmedData}->{ArticleIdList}->{ArticleId}->{doi}->{content};

    # backup strategy for pubmed id
    if ( $pub->pmid() ) {
      if ( $pub->pmid() !~ m/^\d+$/ ) {
        $pub->pmid( $article->{PubmedData}->{ArticleIdList}->{ArticleId}->{pubmed}->{content} );
      }
    }

    # Remove period from end of title
    $title =~ s/\.\s*$//;

    $pub->volume($volume)           if $volume;
    $pub->issue($issue)             if $issue;
    $pub->year($year)               if $year;
    $pub->month($month)             if $month;
    $pub->pages($pages)             if $pages;
    $pub->abstract($abstract)       if $abstract;
    $pub->title($title)             if $title;
    $pub->doi($doi)                 if $doi;
    $pub->issn($issn)               if $issn;
    $pub->affiliation($affiliation) if $affiliation;

    if ($journal) {
      my $jid = $journal;
      $pub->journal($journal),;
    }

    my @authors = ();
    my @tmp     = ();
    if ( ref( $cit->{Article}->{AuthorList}->{Author} ) eq 'ARRAY' ) {
      @tmp = @{ $cit->{Article}->{AuthorList}->{Author} };
    } else {
      @tmp = ( $cit->{Article}->{AuthorList}->{Author} );
    }

    foreach my $author (@tmp) {

      if ( $author->{CollectiveName} ) {
        push @authors,
          Paperpile::Library::Author->new(
          last       => '',
          first      => '',
          jr         => '',
          collective => $author->{CollectiveName},
          )->normalized;
      } else {
        push @authors,
          Paperpile::Library::Author->new(
          last  => $author->{LastName} ? $author->{LastName} : '',
          first => $author->{Initials} ? $author->{Initials} : '',
          jr    => $author->{Suffix}   ? $author->{Suffix}   : '',
          )->normalized;
      }

    }
    $pub->authors( join( ' and ', @authors ) );
    push @output, $pub;
  }
  return [@output];
}

# Function: _linkOut

# Sends request for "LinkOut" URLs to the server and adds the
# information to the list of Publication objects.

sub _linkOut {

  ( my $self, my $pubs ) = @_;

  my %pub_hash = ();

  my @ids = ();
  foreach my $pub (@$pubs) {
    push @ids, $pub->{pmid};
    $pub_hash{ $pub->{pmid} } = $pub;
  }

  my $ids = join( ',', @ids );

  my $browser = Paperpile::Utils->get_browser;

  my $url =
    "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?retmode=xml&cmd=prlinks&db=PubMed&id=$ids";

  my $response = $browser->get($url);

  Paperpile::Utils->check_browser_response($response,"PubMed query failed");

  my $result = XMLin( $response->content, forceArray => ['IdUrlSet', 'ObjUrl'] );

  foreach my $entry ( @{ $result->{LinkSet}->{IdUrlList}->{IdUrlSet} } ) {

    my $id = $entry->{Id};
    
    # got an error message
    if ( defined $entry->{Info} ) {
      $pub_hash{$id}->linkout('');
      # There is still the chance that there is a linkout to PMC, we can query this
      # using cmd=llinks instead of cmd=prlinks. We only do this if there is no DOI.
      if ( $pub_hash{$id}->doi eq '' ) {
	my $url2 =
	  "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?retmode=xml&cmd=llinks&db=PubMed&id=$id";
	my $response2 = $browser->get($url2);
	Paperpile::Utils->check_browser_response($response2);
	my $result2 = XMLin( $response2->content, forceArray => ['IdUrlSet'] );
	eval {
	  my $linkout2 = $result2->{LinkSet}->{IdUrlList}->{IdUrlSet}->[0]->{ObjUrl}->[0]->{Url};
	  if ( defined $linkout2 ) {
	    $pub_hash{$id}->linkout( $linkout2 ) if ( $linkout2 =~ m/ukpmc/ or
						      $linkout2 =~ m/pubmedcentral/ or
						      $linkout2 =~ m/gov\/pmc/ ) ;
	  }
	};
      }
    } else {

      $pub_hash{$id}->linkout( $entry->{ObjUrl}->[0]->{Url} );

      # Adjust the url otherwise it won't get displayed correctly
      #my $icon_url = $entry->{ObjUrl}->{IconUrl};
      #$icon_url =~ s/entrez/corehtml/;
      #$pub_hash{$id}->icon($icon_url);
    }
  }
}

# Function: _fetch_by_pmid

sub _fetch_by_pmid {

  ( my $self, my $pmid ) = @_;

  my $browser = Paperpile::Utils->get_browser;
  if ( $pmid ne '' ) {
    my $query = "$esearch$pmid";
    $query .= "[uid]" if ( $pmid !~ m/^PMC/ );

    my $response  = $browser->get($query);
    Paperpile::Utils->check_browser_response($response);
    my $resultXML = $response->content;
    my $result    = XMLin($resultXML);

    if ( $result->{Count} == 1 ) {
      $self->web_env( $result->{WebEnv} );
      $self->query_key( $result->{QueryKey} );

      my $xml = $self->_pubFetch( 0, 1 );
      my $page = $self->_read_xml($xml);
      $self->_linkOut($page);
      return $page->[0];
    }
  }
}

1;
