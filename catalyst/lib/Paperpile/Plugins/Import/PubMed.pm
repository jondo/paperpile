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
use Paperpile::Library::Journal;
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
	$tmp[$i] = uri_escape( $tmp[$i] );
    }
    
    return join( "+", @tmp );
}

sub _FormatQueryString {
    my $query = $_[0];
    my $formatted_query_string = '';

    # let's see if we have signal words
    my $special_words = 0;

    $special_words = 1 if ( $query =~ m/(author:|title:|journal:)/ );
 
    # there are no special words so we just do a regular escaping
    if ( $special_words == 0 ) {
        $formatted_query_string = _EscapeString( $query );
    } else {
	my @blocks = split(/(author:|title:|journal:)/, $query);
	shift(@blocks) if (!$blocks[0]);

	my @tmp_query = ( );
	for ( my $i=0; $i <= $#blocks; $i++ ) {
	    #print STDERR "$i :: $blocks[$i]\n";
	    if ( $blocks[$i] =~ m/^author:$/i ) {
		if ( defined $blocks[$i+1] ) {
		    push @tmp_query, _EscapeString( '"'.$blocks[$i+1].'"'."[Author]" );
		}
		$i++;
	    }
	    if ( $blocks[$i] =~ m/^title:$/i ) {
		if ( defined $blocks[$i+1] ) {
		    push @tmp_query, _EscapeString( '"'.$blocks[$i+1].'"'."[Title]" );
		}
		$i++;
	    }
	    if ( $blocks[$i] =~ m/^journal:$/i ) {
		if ( defined $blocks[$i+1] ) {
		    push @tmp_query, _EscapeString( '"'.$blocks[$i+1].'"'."[Journal]" );
		}
		$i++;
	    }
	    #print STDERR "   $i :: $blocks[$i]\n";
	}
	$formatted_query_string = join("+", @tmp_query);
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
  my $query_string = _FormatQueryString($self->query);
  my $response = $browser->get( $esearch . $query_string );

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
      error    => 'PubMed query failed: unknown return format',
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

  # we should always call this function to make the results available
  # afterwards via find_sha1
  $self->_save_page_to_hash($page);

  return $page;
}


sub all {
  ( my $self ) = @_;
  return $self->page(0,100);
}


# Simple and untested for now...

sub match {

  ( my $self, my $pub ) = @_;

  my $matchDOI   = 0;
  my $matchTitle = 0;

  my $query = '';

  if ( $pub->doi ) {
    $query    = $pub->doi . "[AID]";
    $matchDOI = 1;
  } else {
    if ( $pub->title ) {
      $query      = $pub->title;
      $matchTitle = 1;
      if ( $pub->authors ) {
        my $first = $pub->get_authors->[0]->last;
        $query .= " AND $first [1au]";
      }
    }
  }

  my $browser   = Paperpile::Utils->get_browser;
  my $response  = $browser->get( $esearch . $query );
  my $resultXML = $response->content;
  my $result    = XMLin($resultXML);

  if ( $result->{Count} == 0 ) {
    NetMatchError->throw( error => 'No match against PubMed.');
  }

  $self->web_env( $result->{WebEnv} );
  $self->query_key( $result->{QueryKey} );
  $self->total_entries( $result->{Count} );

  my $xml = $self->_pubFetch( 0, 100 );
  my $page = $self->_read_xml($xml);
  $self->_linkOut($page);

  if ($matchDOI) {
    if ( $page->[0]->doi eq $pub->{doi} ) {
      return $self->_merge_pub( $pub, $page->[0] );
    }
  }

  if ($matchTitle) {
    if ( $self->_match_title( $page->[0]->title, $pub->title ) ) {
      return $self->_merge_pub( $pub, $page->[0] );
    }
  }

  NetMatchError->throw( error => 'No match against PubMed.');

}


sub web_lookup {

  my ($self, $url, $content) = @_;

  #my $pmid;

  $url=~/pubmed\/(\d+)/;

  my $pmid=$1;

  my $browser   = Paperpile::Utils->get_browser;
  my $response  = $browser->get( $esearch . $pmid );
  my $resultXML = $response->content;
  my $result    = XMLin($resultXML);

  if ( $result->{Count} == 0 ) {
    NetMatchError->throw( error => 'Could not find entry in PubMed');
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

  if ( $response->is_error ) {
    NetGetError->throw(
      error => 'PubMed query failed: ' . $response->message,
      code  => $response->code
    );
  }

  my $resultXML = $response->content;

  return $resultXML;

}

# function: _read_xml

# Parses the PubMed XML format and converts it into a list of
# Paperpile::Library::Publication entries.

sub _read_xml {

  ( my $self, my $xml ) = @_;

  my $result = XMLin( $xml, keyattr => ['IdType'], SuppressEmpty => 1 );

  if ( not defined $result->{PubmedArticle} ) {
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

    $pub->pmid( $cit->{PMID} );

    my $volume   = $cit->{Article}->{Journal}->{JournalIssue}->{Volume};
    my $issue    = $cit->{Article}->{Journal}->{JournalIssue}->{Issue};
    my $year     = $cit->{Article}->{Journal}->{JournalIssue}->{PubDate}->{Year};
    my $month    = $cit->{Article}->{Journal}->{JournalIssue}->{PubDate}->{Month};
    my $pages    = $cit->{Article}->{Pagination}->{MedlinePgn};
    my $abstract = $cit->{Article}->{Abstract}->{AbstractText};
    my $title    = $cit->{Article}->{ArticleTitle};
    my $status   = $article->{PubmedData}->{PublicationStatus};
    my $journal  = $cit->{MedlineJournalInfo}->{MedlineTA};
    my $issn     = $cit->{Article}->{Journal}->{ISSN}->{content};

    my $doi = $article->{PubmedData}->{ArticleIdList}->{ArticleId}->{doi}->{content};

    # Remove period from end of title
    $title=~s/\.\s*$//;

    $pub->volume($volume)     if $volume;
    $pub->issue($issue)       if $issue;
    $pub->year($year)         if $year;
    $pub->month($month)       if $month;
    $pub->pages($pages)       if $pages;
    $pub->abstract($abstract) if $abstract;
    $pub->title($title)       if $title;
    $pub->doi($doi)           if $doi;
    $pub->issn($issn)         if $issn;


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
          last  => '',
          first => '',
          jr    => '',
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

  if ( $response->is_error ) {
    NetGetError->throw(
      error => 'PubMed query failed: ' . $response->message,
      code  => $response->code
    );
  }

  my $result = XMLin( $response->content, forceArray =>['IdUrlSet']);

  foreach my $entry ( @{ $result->{LinkSet}->{IdUrlList}->{IdUrlSet} } ) {

    my $id = $entry->{Id};

    # got an error message
    if ( defined $entry->{Info} ) {
      $pub_hash{$id}->linkout('');
    } else {
      $pub_hash{$id}->linkout( $entry->{ObjUrl}->{Url} );

      # Adjust the url otherwise it won't get displayed correctly
      my $icon_url = $entry->{ObjUrl}->{IconUrl};
      $icon_url =~ s/entrez/corehtml/;
      $pub_hash{$id}->icon($icon_url);
    }
  }

}

1;
