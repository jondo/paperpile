package Paperpile::Plugins::Import::GoogleScholar;

use Carp;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;
use XML::Simple;
use HTML::TreeBuilder::XPath;
use URI::Escape;
use 5.010;

use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Paperpile::Library::Journal;
use Paperpile::Utils;

use Paperpile::Plugins::Import::SpringerLink;
use Paperpile::Plugins::Import::ACM;
use Paperpile::Plugins::Import::PubMed;

extends 'Paperpile::Plugins::Import';

# The search query to be send to GoogleScholar
has 'query' => ( is => 'rw' );

# We need to set a cookie to get links to BibTeX file.
has '_session_cookie' => ( is => 'rw' );

# The main search URL
my $searchUrl = 'http://scholar.google.com/scholar?hl=en&lr=&btnG=Search&q=';

# The URL with the settings form. We use it to turn on BibTeX output.
my $settingsUrl =
  'http://scholar.google.com/scholar_setprefs?output=search&inststart=0&hl=en&lang=all&instq=&submit=Save+Preferences&scis=yes';

sub BUILD {
    my $self = shift;
    $self->plugin_name('GoogleScholar');
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

# Format the query sent to Google Scholar. This means escaping 
# things like non-alphanumeric characters and joining words with '+'.

sub FormatQueryString {
    my $query = $_[0];

    return _EscapeString( $query );
}

sub connect {
  my $self = shift;

  # First set preferences (necessary to show BibTeX export links)
  # We simulate submitting the form which sets a cookie. We save
  # the cookie for this session.

  my $browser = Paperpile::Utils->get_browser;
  $settingsUrl .= 'num=10&scisf=4';    # gives us BibTeX
  $browser->get($settingsUrl);
  $self->_session_cookie( $browser->cookie_jar );

  # Then start real query
  $browser = Paperpile::Utils->get_browser;          # get new browser
  $browser->cookie_jar( $self->_session_cookie );    # set the session cookie

  # Get the results
  my $query_string = FormatQueryString($self->query);
  my $response = $browser->get( $searchUrl . $query_string );
  my $content  = $response->content;
 
  # save first page in cache to speed up call to first page afterwards
  $self->_page_cache( {} );
  $self->_page_cache->{0}->{ $self->limit } = $content;

  # Nothing found
  if ( $content =~ /No pages were found containing/ ) {
    $self->total_entries(0);
    return 0;
  }

  # We parse the HTML via XPath
  my $tree = HTML::TreeBuilder::XPath->new;
  $tree->utf8_mode(1);
  $tree->parse_content($content);

  # Try to find the number of hits
  my @stats = $tree->findnodes('/html/body/form/table/tr/td[@align="right"]/font[@size="-1"]');
  if ( $stats[0]->as_text() =~ m/Results\s\d+\s-\s\d+\sof\s(about\s)?([0123456789,]+)\./ ) {
    my $number = $2;
    $number =~ s/,//g;
    $number = 1000 if ( $number > 1000 );    # Google does not provide more than 1000 results
    $self->total_entries($number);
  } else {
    die('Something is wrong with the results page.');
  }

  # Return the number of hits
  return $self->total_entries;
}

sub page {
  ( my $self, my $offset, my $limit ) = @_;

  # Get the content of the page, either via cache for the first page
  # which has been retrieved in the connect function or send new query
  my $content = '';
  if ( $self->_page_cache->{$offset}->{$limit} ) {
    $content = $self->_page_cache->{$offset}->{$limit};
  } else {
    my $browser = Paperpile::Utils->get_browser;
    $browser->cookie_jar( $self->_session_cookie );
    my $query_string = FormatQueryString($self->query);
    my $query    = $searchUrl . $query_string . "&start=$offset";
    my $response = $browser->get($query);
    $content = $response->content;
  }

  my $page = $self->_parse_googlescholar_page($content);
 
  # we should always call this function to make the results available
  # afterwards via find_sha1
  $self->_save_page_to_hash($page);

  return $page;
}

sub _check_for_better_bibliographic_data {
    ( my $self, my $pub ) = @_;
    
    # Create a new Publication object
    my $full_pub = Paperpile::Library::Publication->new();
    
    my $backup_details_link = $pub->_details_link;
    my $done = 0;
    
    # Exit point to direct PubMed calls
    if ( $pub->_www_publisher eq 'ncbi.nlm.nih.gov' ) {
	if ( $pub->linkout() =~ m/http:\/\/www\.ncbi\.nlm\.nih\.gov\/pubmed\/(\d+)/ ) {
	    my $PubMedPlugin = Paperpile::Plugins::Import::PubMed->new();
	    $full_pub = $PubMedPlugin->_fetch_by_pmid ( $1 );
	    $done = 1 if ( $full_pub->title );
	}
    }

    # Exit point to direct PubMed calls via Pubmed Central Id
    if ( $pub->_www_publisher eq 'pubmedcentral.nih.gov' and $done == 0 ) {
	if ( $pub->linkout() =~ m/http:\/\/www\.pubmedcentral\.nih\.gov\/articlerender\.fcgi\?artid=(\d+)/ ) {
	    my $PubMedPlugin = Paperpile::Plugins::Import::PubMed->new();
	    $full_pub = $PubMedPlugin->_fetch_by_pmid ( "PMC$1" );
	    $done = 1 if ( $full_pub->title );
	}
    }
    
    # Exit point to SpringerLink details completion
    if ( $pub->_www_publisher eq 'Springer' and $done == 0 ) {
	if ( $pub->linkout() =~ m/http:\/\/www.springerlink.com\/index\/(\w+)(\.pdf)/ ) {
	    my $tmp_details_link = 'http://www.springerlink.com/content/'.$1;
	    my $SpringerLinkPlugin = Paperpile::Plugins::Import::SpringerLink->new();
	    $pub->_details_link( $tmp_details_link );
	    $full_pub = $SpringerLinkPlugin->complete_details( $pub );
	    $done = 1 if ( $full_pub->title );
	}
    }
    
    # Exit point to ACM details completion
    if ( $pub->_www_publisher eq 'portal.acm.org' and $done == 0 ) {
	if ( $pub->linkout() =~ m/http:\/\/portal\.acm\.org\/citation\.cfm\?id=/ ) {
	    my $tmp_details_link = $pub->linkout();
	    my $ACMPlugin = Paperpile::Plugins::Import::ACM->new();
	    $pub->_details_link( $tmp_details_link );
	    $full_pub = $ACMPlugin->complete_details( $pub );
	    $done = 1 if ( $full_pub->title );
	}
    }
    
    # If we have no support for the publisher yet, or it did not work
    # we return undef
    if ( $done == 0 ) {
	$pub->_details_link( $backup_details_link );
	return undef;
    } else {
	# If we are here we succeded in calling another Plugin and
	# we are done
	my $old_sha1 = $pub->sha1;
	my $new_sha1 = $full_pub->sha1;
	delete( $self->_hash->{$old_sha1} );
	$self->_hash->{$new_sha1} = $full_pub;
	
	return $full_pub;
    }
}


# We parse GoogleScholar in a two step process. First we scrape off
# what we see and display it unchanged in the front end via
# _authors_display and _citation_display. If the user clicks on an
# entry the missing information is completed from the BibTeX
# file. This ensures fast search results and avoids too many requests
# to Google which is potentially harmful.

sub complete_details {

  ( my $self, my $pub ) = @_;

  my $browser = Paperpile::Utils->get_browser;
  $browser->cookie_jar( $self->_session_cookie );
  my $bibtex = '';

  # Let's see if the the www_provider is a good one
  my @best_sources = ( 'Elsevier','ingentaconnect.com',
		       'liebertonline.com', 'nature.com',
		       'sciencemag.org', 'Springer',
		       'Cambridge Univ Press',
		       'Nature Publishing Group', 'Oxford Univ Press',
		       'portal.acm.org','ncbi.nlm.nih.gov');
  my $best_flag = 0;
  foreach my $j ( 0 .. $#best_sources ) {
      $best_flag = 1 if ( $pub->_www_publisher eq $best_sources[$j] );
  }

  # if the publisher is already a good one we call the BibTeX right here
  # or take another Plugin if we can recognize it
  if ( $best_flag == 1 ) {
      my $full_pub = $self->_check_for_better_bibliographic_data( $pub );
      if ( $full_pub ) {
	  return $full_pub;
      } else {
	  my $bibtex_tmp = $browser->get( $pub->_details_link );
	  $bibtex = $bibtex_tmp->content;
      } 
  }

  # For many articles Google provides links to several versions of
  # the same article. There are differences regarding the parsing
  # quality of the BibTeX. We search all versions if there are any
  # high quality links.
  if ( $pub->_all_versions ne '' and $best_flag == 0 ) {
      my @order_publishers = ( 'ncbi.nlm.nih.gov','Springer',
			       'portal.acm.org','Elsevier','ingentaconnect.com',
			       'liebertonline.com', 'nature.com',
			       'sciencemag.org', 
			       'Cambridge Univ Press', 'indexcopernicus.com',
			       'Nature Publishing Group', 'Oxford Univ Press',
			       'pubmedcentral.nih.gov',
			       'adsabs.harvard.edu',
			       'cat.inist.fr','arxiv.org','csa.com');
      my @order_flags = (  );
      for ( 0 .. $#order_publishers ) { push @order_flags, -1 }

      my $response_all_versions = $browser->get( $pub->_all_versions );
      my $content_all_versions = $response_all_versions->content;

      my $page = $self->_parse_googlescholar_page( $content_all_versions );
      for my $i ( 0 .. $#{ $page } ) {
	  foreach my $j ( 0 .. $#order_publishers ) {
	      if ( $page->[$i]->_www_publisher =~ m/$order_publishers[$j]/ ) {
		  $order_flags[$j] = $i if ( $order_flags[$j] == -1 );
	      }
	  }
      }
      
      # let's define the best one
      my $best_one = 0;
      foreach my $j ( 0 .. $#order_flags ) {
	  if ( $order_flags[$j] > -1 ) {
	      $best_one = $order_flags[$j];
	      last;
	  }
      }
 
      # Get the BibTeX
      my $full_pub = $self->_check_for_better_bibliographic_data( $page->[$best_one] );
      if ( $full_pub ) {
	  return $full_pub;
      } else {
	  my $bibtex_tmp = $browser->get( $page->[$best_one]->_details_link );
	  $bibtex = $bibtex_tmp->content;
      } 
  } 

  # Nothing good found till here, so we take the link of the original
  # publication object
  if ( $bibtex eq '' ) {
      my $bibtex_tmp = $browser->get( $pub->_details_link );
      $bibtex = $bibtex_tmp->content;
  }

  # Create a new Publication object
  my $full_pub = Paperpile::Library::Publication->new();

  # Google Bug: everything is twice escaped in bibtex
  $bibtex =~ s/\\\\/\\/g;

  # import the information from the BibTeX string
  $full_pub->import_string( $bibtex, 'BIBTEX' );

  # there are cases where bibtex gives less information than we already have
  $full_pub->title( $pub->title ) if ( !$full_pub->title );
  $full_pub->authors( $pub->_authors_display ) if ( !$full_pub->authors );
  if (!$full_pub->journal and !$full_pub->year ) {
      $full_pub->_citation_display( $pub->_citation_display );
  }

  # Google uses number instead of issue
  $full_pub->issue( $full_pub->number ) if ( !$full_pub->issue and $full_pub->number );

  # Add the linkout from the old object because it is not in the BibTeX
  #and thus not in the new object
  $full_pub->linkout( $pub->linkout );

  # We call the British Library Direct link to get the
  # abstract if they have any
  my $abstract = $self->_parse_BL ( $pub );
  $full_pub->abstract ( $abstract ) if ( $abstract ne '' );

  # We don't use Google key
  $full_pub->citekey('');

  # Note that if we change title, authors, and citation also the sha1
  # will change. We have to take care of this.
  my $old_sha1 = $pub->sha1;
  my $new_sha1 = $full_pub->sha1;
  delete( $self->_hash->{$old_sha1} );
  $self->_hash->{$new_sha1} = $full_pub;

  return $full_pub;
}

# match function to match a given publication object against Google
# Scholar.

sub match {

  ( my $self, my $pub ) = @_;

  my $query_doi = '';
  my $query_title = '';
  my $query_authors = '';

  # First we format the three query strings properly. Besides
  # HTML escaping we remove words that contain non-alphnumeric
  # characters. These words can cause severe problems.
  # 1) DOI
  $query_doi = _EscapeString( $pub->doi ) if ( $pub->doi );

  # 2) Title
  if ( $pub->title ) {
      my @tmp = ( );
      ( my $tmp_title = $pub->title ) =~ s/(\(|\)|-|\.|,|:|;|\{|\}|\?|!)/ /g;
      foreach my $word ( split(/\s+/, $tmp_title ) ) {
	  # words that contain non-alphnumeric and non-ascii 
	  # characters are removed
	  next if ( $word =~ m/[^\w\s-]/ );
	  next if ( $word =~ m/[^[:ascii:]]/ );

	  # words with less than 3 characters are removed
	  next if (length($word) < 3 );
	  
	  my @google_stopwords = ('about', 'com', 'for', 'from', 'how', 
				  'that', 'the', 'this', 'was', 'what',
				  'when', 'where', 'will', 'with', 'und',
				  'and', 'www');

	  my $flag = 0;
	  foreach my $stop_word (@google_stopwords) {
	      if (lc($word) eq $stop_word) {
		  $flag = 1;
		  last;
	      }
	  }
	  next if ($flag == 1);

	  # Add Title-tag
	  push @tmp, $word;
      }
      $query_title = _EscapeString( join( " ", @tmp ) );
      $query_title = 'allintitle:'.$query_title;
  }

  # 3) Authors. We just use each author's last name
  if ( $pub->authors ) {
      my @tmp = ( );
      foreach my $author ( @{ $pub->get_authors } ) {
	  # words that contain non-alphnumeric and non-ascii 
	  # characters are removed
	  next if ( $author->last =~ m/[^\w\s-]/ );
	  next if ( $author->last =~ m/[^[:ascii:]]/ );

	  push @tmp, 'author:'.$author->last;
      }
      $query_authors = _EscapeString(join(" ", @tmp));
  }

  # First set preferences (necessary to show BibTeX export links)
  # We simulate submitting the form which sets a cookie. We save
  # the cookie for this session.

  my $browser = Paperpile::Utils->get_browser;
  $settingsUrl .= 'num=10&scisf=4';    # gives us BibTeX
  $browser->get($settingsUrl);
  $self->_session_cookie( $browser->cookie_jar );

  # Then start real query
  $browser = Paperpile::Utils->get_browser;          # get new browser
  $browser->cookie_jar( $self->_session_cookie );    # set the session cookie


  # Once the browser is properly set
  # We first try the DOI if there is one
  if ( $query_doi ne '' ) {

      my $query = $searchUrl . $query_doi ."&as_vis=1";
      my $response = $browser->get( $query );
      my $content = $response->content;
      print STDERR "$query\n";
      # parse the page and then see if a publication matches
      if ( $pub->title() ) {
	  my $page = $self->_parse_googlescholar_page( $content );
	  my $matchedpub = $self->_find_best_hit( $page, $pub );
	  
	  if ( $matchedpub ) {
	      #print STDERR "Found a match using DOI as query.\n";
	      return $matchedpub;
	  } else {
	      # We resolve the doi using dx.doi.org of the first hit
	      if ( $page->[0] ) {
		  my $fullpub = $self->complete_details( $page->[0] );
		  my $doi_response = $browser->get( 'http://dx.doi.org/'.$pub->doi );
		  ( my $doi_content = $doi_response->content ) =~ s/({|})//g;
		  $doi_content =~ s/\s+/ /g;
		  $doi_content =~ s/\n//g; 
		  my $title = $fullpub->title;
		  if ( $doi_content =~ m/\Q$title\E/i ) {
		      return $self->_merge_pub( $pub, $fullpub );
		  }
	      }
	  }
      } else {
	  # we do not have a title and authors; in most cases google
	  # returns more than one hit when searching with a doi
	  # we have nothing to compare with and have to search with  
	  # another strategy

	  # let's take the first Google hit, which is usually the most
	  # promising one and let's see if we can find the title in the
	  # HTML page that we get when we resolve the doi
	  my $page = $self->_parse_googlescholar_page( $content );
	  if ( $page->[0] ) {
	      my $fullpub = $self->complete_details( $page->[0] );
	      
	      # We resolve the doi using dx.doi.org
	      my $doi_response = $browser->get( 'http://dx.doi.org/'.$pub->doi );
	      ( my $doi_content = $doi_response->content ) =~ s/({|})//g;
	      $doi_content =~ s/\s+/ /g;
	      $doi_content =~ s/\n//g; 
	      my $title = $fullpub->title;
	      # \Q \E are needed, otherwise we would need to esacpe brackets
	      # and other stuff
	      if ( $doi_content =~ m/\Q$title\E/im ) {
		  return $self->_merge_pub( $pub, $fullpub );
	      }
	  }
      }
   }

  # If we are here, it means a search using the DOI was not conducted or 
  # not successfull. Now we try a query using title and authors.

  if ( $query_title ne '' and $query_authors ne '') {

      # we add "&as_vis=1" to exclude citations and get only those links
      # that have stronger support
      my $query_string = "$query_title+$query_authors"."&as_vis=1";
      print STDERR "$searchUrl$query_string\n";

      # Now let's ask GoogleScholar again with Authors/Title
      my $query = $searchUrl . $query_string;
      my $response = $browser->get($query);
      my $content = $response->content;
      # parse the page and then see if a publication matches
      my $page = $self->_parse_googlescholar_page($content);
      my $matchedpub = $self->_find_best_hit( $page, $pub );
      
      if ( $matchedpub ) {
	  #print STDERR "Found a match using Authors/Title as query.\n";
	  return $matchedpub;
      }
  }

  # If we are here then Title+Auhtors failed, and we try to search
  # only with the title and include also citations this time.
  # Final quality check if there are enough words in the title
  # to give a significant match

  my $count_words = ($query_title =~ tr/\+//);
  if ( $query_title ne '' and $count_words > 5) {
      my $query_string = "$query_title"."&as_vis=0";
      print STDERR "$searchUrl$query_string\n";

      # Now let's ask GoogleScholar again with Authors/Title
      my $query = $searchUrl . $query_string;
      my $response = $browser->get($query);
      my $content = $response->content;
  
      # parse the page and then see if a publication matches
      my $page = $self->_parse_googlescholar_page($content);
      my $matchedpub = $self->_find_best_hit( $page, $pub );
      
      if ( $matchedpub ) {
	  #print STDERR "Found a match using Title as query.\n";
	  return $matchedpub;
      }
  }
  
  # If we are here then all search strategies failed.
  NetMatchError->throw( error => 'No match against GoogleScholar.');
  #return $pub;
}



# Gets from a list of GoogleScholar hits the one that fits 
# the publication title we are searching for best
sub _find_best_hit {
    ( my $self, my $hits_ref, my $orig_pub ) = @_;

    my @google_hits = @{$hits_ref};
    if ( $#google_hits > -1 ) {

	# let's get rid of words that contain none ASCII chars
	# and other bad stuff (often PDF utf-8 issues)
	my @words = ( );
	(my $tmp_orig_title = $orig_pub->title) =~ s/(\(|\)|-|\.|,|:|;|\{|\}|\?|!)/ /g;
	$tmp_orig_title =~ s/\s+/ /g;
	foreach my $word ( split(/\s+/, $tmp_orig_title ) ) {
	    next if ( $word =~ m/([^[:ascii:]])/ );
	    next if ( length ( $word ) < 2 ); # skip one letter words
	    push @words, $word if ( $word =~ m/^\w+$/ );
	}
	
	# now we screen each hit and see which one matches best
 	my $max_counts = $#words;
	my $best_hit = -1;

	# we take a look at the top three candidates
	my $max_to_screen = ( $#google_hits < 2 ) ? $#google_hits : 2;
	foreach my $i ( 0 .. $max_to_screen ) {

	    # In some cases it is necessary to get the BibTex entry, 
	    # because sometimes not the full title is displayed. These
	    # cases can be identified by the '...' Hex-code 2026
	    my $tmp_title;
	    if ( $google_hits[$i]->title =~ m/\x{2026}/ ) {
		my $tmp_pub = $self->complete_details($google_hits[$i]);
		$tmp_title = $tmp_pub->title;
	    } else {
		$tmp_title = $google_hits[$i]->title;
	    }

	    # some preprocessing again
	    my @words2 = ( );
	    $tmp_title =~ s/(\(|\)|-|\.|,|:|;|\{|\}|\?|!)/ /g;
	    $tmp_title =~ s/\s+/ /g;
	    foreach my $word ( split(/\s+/, $tmp_title ) ) {
		next if ( $word =~ m/([^[:ascii:]])/ );
		push @words2, $word if ( $word =~ m/^\w+$/ );
	    }
	    $tmp_title = " ".join( " ", @words2 )." ";
	      
	    # let's check how many of the words in the title match
	    my $counts = 0;
	    foreach my $word ( @words ) {
		$counts++ if ( $tmp_title =~ m/\s$word\s/i );
		#print "$counts || $word || $tmp_title\n";
	    }

	    if ( $counts > $max_counts ) {
		$max_counts = $counts;
		$best_hit = $i;
	    }

	    # if we fail, we try it a little less restrictive
	    if ( $best_hit == -1 and $max_counts >= 10 ) {
		if ( $counts >= $max_counts ) {
		    $best_hit = $i;
		}
	    }

	    #print "$counts of $max_counts --> $best_hit\n";
	}
	
	# now let's look up the BibTeX record and see if it is really 
	# what we are looking for
	if ( $best_hit > -1) {
	    my $fullpub = $self->complete_details($google_hits[$best_hit]);
	    #if ( $self->_match_title( $fullpub->title, $orig_pub->title ) ) {
	    return $self->_merge_pub( $orig_pub, $fullpub );
	    #}
	}
    }

    return undef;
}

# the functionality of parsing a google scholar results page
# implemented originally in the sub "page" was moved to this 
# separate sub as it is needed by the sub "match" too.
# it returns an array reference of publication objects
sub _parse_googlescholar_page {

    ( my $self, my $content ) = @_;
    
    # Google markup is a mess, so also the code to parse is cumbersome
    
    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->utf8_mode(1);
    $tree->parse_content($content);
    
    my %data = (
	authors   => [],
	titles    => [],
	citations => [],
	urls      => [],
	bibtex    => [],
	versions  => [],
	www_publisher => [],
	related_articles => [],
	BL => []
	);
    
    # Each entry has a h3 heading
    my @nodes = $tree->findnodes('/html/body/h3[@class="r"]');
    
    foreach my $node (@nodes) {
	
	my ( $title, $url );
	
	# A link to a web-resource is available
	if ( $node->findnodes('./a') ) {
	    $title = $node->findvalue('./a');
	    $url   = $node->findvalue('./a/@href');
	    
	    # citation only
	} else {
	    
	    $title = $node->findvalue('.');
	    
	    # Remove the tags [CITATION] and [BOOK] (and the character
	    # afterwards which is a &nbsp;)
	    $title =~ s/\[CITATION\].//;
	    $title =~ s/\[BOOK\].//;
	    
	    $url = '';
	}
	push @{ $data{titles} }, $title;
	push @{ $data{urls} },   $url;
    }
    
    # There is <div> for each entry but a <font> tag directly below the
    # <h3> header
    
    @nodes = $tree->findnodes(q{/html/body/font[@size='-1']});
    
    foreach my $node (@nodes) {
	
	# Most information is contained in a <span> tag
	my $line = $node->findvalue(q{./span[@class='a']});
	next if not $line;
	
	my ( $authors, $citation, $publisher ) = split( / - /, $line );

	# we set _www_publisher, which is used then again in _complete_details
	push @{ $data{www_publisher} },   defined($publisher)  ? $publisher  : '';


	# sometime the publisher is just a plain IP-address or some URL
	if ( defined $publisher ) {
	    undef ( $publisher ) if ( $publisher =~ m/\.[A-Z]{3}$/i );
	}
	if ( defined $publisher ) {
	    undef ( $publisher ) if ( $publisher =~ m/\d{3}\./ );
	}
	
	$citation .= "- $publisher" if ( defined $publisher );
	
	push @{ $data{authors} },   defined($authors)  ? $authors  : '';
	push @{ $data{citations} }, defined($citation) ? $citation : '';
	
	my @links = $node->findnodes('./span[@class="fl"]/a');
	
	# Find the BibTeX export links
	my $cluster_link_found = 0;
	my $related_link_found = 0;
	my $BL_link_found = 0;
	foreach my $link (@links) {
	    my $url = $link->attr('href');
	    if ( $url =~ /\/scholar\.bib/ ) {
		$url = "http://scholar.google.com$url" if ( $url !~ m/^http/ );
		push @{ $data{bibtex} }, $url;
	    }
	    if ( $url =~ /\/scholar\?cluster/ ) {
		$url = "http://scholar.google.com$url" if ( $url !~ m/^http/ );
		push @{ $data{versions} }, $url;
		$cluster_link_found = 1;
	    }
	    if ( $url =~ /\/scholar\?cluster/ ) {
		$url = "http://scholar.google.com$url" if ( $url !~ m/^http/ );
		push @{ $data{versions} }, $url;
		$cluster_link_found = 1;
	    }
	    if ( $url =~ /\/scholar\?q=related/ ) {
		$url = "http://scholar.google.com$url" if ( $url !~ m/^http/ );
		push @{ $data{related_articles} }, $url;
		$related_link_found = 1;
	    }
	    if ( $url =~ /direct\.bl\.uk/ ) {
		push @{ $data{BL} }, $url;
		$BL_link_found = 1;
	    }
	}
	
	# not all nodes have a versions link; we push an empty one
	# if nothing was found 
	push @{ $data{versions} }, '' if ( $cluster_link_found == 0 );
	push @{ $data{related_articles} }, '' if ( $related_link_found == 0 );
	push @{ $data{BL} }, '' if ( $BL_link_found == 0 );
    }
    
    # Write output list of Publication records with preliminary
    # information We save to the helper fields _authors_display and
    # _citation_display which will be displayed in the front end.
    my $page = [];
    
    foreach my $i ( 0 .. @{ $data{titles} } - 1 ) {
	my $pub = Paperpile::Library::Publication->new();
	$pub->title( $data{titles}->[$i] );
	$pub->_authors_display( $data{authors}->[$i] );
	$pub->_citation_display( $data{citations}->[$i] );
	$pub->linkout( $data{urls}->[$i] );
	$pub->_details_link( $data{bibtex}->[$i] );
	$pub->_all_versions( $data{versions}->[$i] );
	$pub->_www_publisher( $data{www_publisher}->[$i] );
	$pub->_related_articles( $data{related_articles}->[$i] );
	$pub->_google_BL_link( $data{BL}->[$i] );
	$pub->refresh_fields;
	push @$page, $pub;
    }
    
    return $page;
        
}

# parses the BL (British Library Direct) link to get bibliographic
# data and abstract. 

sub _parse_BL {
    ( my $self, my $pub ) = @_;

    my $abstract = '';
    if ( $pub->_google_BL_link ne '' ) {
	my $browser = Paperpile::Utils->get_browser;
	my $response = $browser->get( $pub->_google_BL_link );
	my $content = $response->content;

	my $tree = HTML::TreeBuilder::XPath->new;
	$tree->utf8_mode(1);
	$tree->parse_content($content);

	# The bibliographic data is easy to parse, but it seems to be
	# generated automatically and is therefore likely not to be complete. 
	# But the abstract is useful.
	$abstract = $tree->findvalue(q{/html/body/div/table/tr/td/table/tr/td[3]/table[2]/tr/td/div});
	$abstract =~ s/^Abstract:\s?//;

    }

    return $abstract;
}



1;
