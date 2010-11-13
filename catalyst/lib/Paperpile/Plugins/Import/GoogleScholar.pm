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


package Paperpile::Plugins::Import::GoogleScholar;

use Carp;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;
use XML::Simple;
use HTML::TreeBuilder::XPath;
use URI::Escape;
use Encode;
use 5.010;

use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Paperpile::Utils;

use Paperpile::Plugins::Import::SpringerLink;
use Paperpile::Plugins::Import::ACM;
use Paperpile::Plugins::Import::PubMed;
use Paperpile::Plugins::Import::OxfordJournals;
use Paperpile::Plugins::Import::URL;

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

  return _EscapeString($query);
}

# parses Google scholar content if there are errors
# returns 0 if everyhting is okay and there is NO error
# returns 1 if Google blocks this IP
# returns 2 if the page does not contain results
sub _check_content {
  my $content     = $_[0];
  my $error_level = 0;

  $error_level = 1
    if ( $content =~ m/but your computer or network may be sending automated queries/ );

  $error_level = 2
    if ( $content =~ m/Your\ssearch\s.*\sdid\snot\smatch\sany\sarticles\./ );

  return $error_level;
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
  my $query_string = FormatQueryString( $self->query );
  my $response     = $browser->get( $searchUrl . $query_string );
  my $content      = $response->content;

  # save first page in cache to speed up call to first page afterwards
  $self->_page_cache( {} );
  $self->_page_cache->{0}->{ $self->limit } = $content;

  my $error_level = _check_content($content);

  if ( $error_level == 2 ) {
    $self->total_entries(0);
    return 0;
  }

  if ( $error_level == 1 ) {
    NetError->throw( error => 'Google Scholar blocks queries from this IP.' );
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

    # Google does not provide more than 1000 results
    $number = 1000 if ( $number > 1000 );
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
    my $query_string = FormatQueryString( $self->query );
    my $query        = $searchUrl . $query_string . "&start=$offset";
    my $response     = $browser->get($query);
    $content = $response->content;
  }

  my $page = $self->_parse_googlescholar_page($content);

  # we should always call this function to make the results available
  # afterwards via find_sha1
  $self->_save_page_to_hash($page);

  return $page;
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

  my $URL_plugin = Paperpile::Plugins::Import::URL->new;

  my $bibtex = '';

  # if the given linkout is a good one we are done
  # the meta-crawler is called and bibliographic
  # informations is obtained from the linkout page
  my $full_pub = undef;
  eval { $full_pub = $URL_plugin->match($pub) };
  if ($full_pub) {

    if ( $full_pub->title() ) {
      $full_pub->citekey('');

      # Update plugin _hash with new data
      $full_pub->guid( $pub->guid );
      $self->_hash->{ $pub->guid } = $full_pub;

      # refresh fields
      $full_pub->_light(0);
      $full_pub->refresh_fields();
      $full_pub->refresh_authors();
      $full_pub->_details_link('');

      return $full_pub;
    }
  }
  print STDERR "GoogleScholar complete_details: first URL match call was not successful.\n";

  # For many articles Google provides links to several versions of
  # the same article. There are differences regarding the parsing
  # quality of the BibTeX. We search all versions if there are any
  # high quality links.
  if ( $pub->_all_versions ne '' ) {

    my @supported = (
      "biomedcentral\.com",                     "chemistrycentral\.com",
      "physmathcentral\.com",                   "aps\.org",
      "plos",                                   "iop\.org",
      "atypon",                                 "acs\.org\/doi\/(abs|full)",
      "annualreviews\.org\/doi\/(abs|full)",    "liebertonline\.com\/doi\/(abs|full)",
      "mitpressjournals\.org\/doi\/(abs|full)", "reference-global\.com",
      "informahealthcare\.com",                 "avma\.org",
      "ametsoc\.org",                           "bioone\.org",
      "uchicago\.edu",                          "jst\.go\.jp",
      "agu\.org",                               "atmos-chem-phys\.net",
      "biogeosciences\.net",                    "envplan\.com",
      "perceptionweb\.com",                     "iucr\.org",
      "sagepub\.com",                           "cshlp\.org",
      "pnas\.org",                              "sciencemag\.org",
      "oxfordjournals\.org",                    "bmj\.com",
      "bmjjournals\.com",                       "ajhp\.org",
      "uwpress\.org",                           "geoscienceworld\.org",
      "hematologylibrary\.org",                 "iovs\.org",
      "physiology\.org",                        "aphapublications\.org",
      "amjpathol\.org",                         "dukejournals\.org",
      "psychonomic-journals\.org",              "ama-assn\.org",
      "ctsnetjournals\.org",                    "birjournals\.org",
      "aacrjournals\.org",                      "ctsnetbooks\.org",
      "jwatch\.org",                            "diabetesjournals\.org",
      "chestpubs\.org",                         "rsmjournals\.com",
      "ahajournals\.org",                       "biologists\.org",
      "lyellcollection\.org",                   "royalsocietypublishing\.org",
      "highwire\.org",                          "ipap\.jp",
      "mdpi\.com",                              "ieeexplore\.ieee\.org",
      "computer\.org",                          "cell\.com",
      "springerlink",                           "nature\.com",
      "sciencedirect\.com\/science",            "landesbioscience\.com",
      "emeraldinsight\.com",                    "dovepress\.com",
      "la-press\.com",                          "thelancet\.com",
      "\.wiley\.com",                           "lww\.com"
    );

    # We retrieve at most 100 aritcles and screen the page if there
    # is a good linkout to a publisher that we can already parse or
    my $response_all_versions = $browser->get( $pub->_all_versions . '&num=100' );
    my $content_all_versions  = $response_all_versions->content;

    my $page = $self->_parse_googlescholar_page($content_all_versions);

    # We trust pubmed the most and so we screen first for a pubmed entry
    for my $i ( 0 .. $#{$page} ) {
      foreach my $j ( 0 .. $#supported ) {
        if ( $page->[$i]->linkout =~ m/ncbi\.nlm\.nih\.gov/ ) {
	  print STDERR "GoogleScholar complete_details: found an ncbi linkout.\n";
          $full_pub = undef;
          eval { $full_pub = $URL_plugin->match( $page->[$i] ) };
          if ($full_pub) {
            if ( $full_pub->title() ) {
              $full_pub->citekey('');

              # Update plugin _hash with new data
              $full_pub->guid( $pub->guid );
              $self->_hash->{ $pub->guid } = $full_pub;

              # refresh fields
              $full_pub->_light(0);
              $full_pub->refresh_fields();
              $full_pub->refresh_authors();
              $full_pub->_details_link('');

              return $full_pub;
            }
          }
          last;
        }
      }
    }

    # If we are here, there as no pubmed entry and we
    # look for other good sites

    for my $i ( 0 .. $#{$page} ) {
      foreach my $j ( 0 .. $#supported ) {
        if ( $page->[$i]->linkout =~ m/$supported[$j]/ ) {
	  print STDERR "GoogleScholar complete_details: now trying ",$page->[$i]->linkout,".\n";
          $full_pub = undef;
          eval { $full_pub = $URL_plugin->match( $page->[$i] ) };
          if ($full_pub) {
            if ( $full_pub->title() ) {
              $full_pub->citekey('');

              # Update plugin _hash with new data
              $full_pub->guid( $pub->guid );
              $self->_hash->{ $pub->guid } = $full_pub;

              # refresh fields
              $full_pub->_light(0);
              $full_pub->refresh_fields();
              $full_pub->refresh_authors();
              $full_pub->_details_link('');

              return $full_pub;
            }
          }
          last;
        }
      }
    }
  }

  # Nothing good found till here, so we take the link of the original
  # publication object

  my $bibtex_tmp = $browser->get( $pub->_details_link );
  $bibtex = $bibtex_tmp->content;

  # Create a new Publication object
  $full_pub = Paperpile::Library::Publication->new();

  # Google Bug: everything is twice escaped in bibtex
  $bibtex =~ s/\\\\/\\/g;

  # import the information from the BibTeX string
  $full_pub->import_string( $bibtex, 'BIBTEX' );

  # bibtex import deactivates automatic refresh of fields
  # we force it now at this point
  $full_pub->_light(0);
  $full_pub->refresh_fields();
  $full_pub->refresh_authors();

  # there are cases where bibtex gives less information than we already have
  $full_pub->title( $pub->title )              if ( !$full_pub->title );
  $full_pub->authors( $pub->_authors_display ) if ( !$full_pub->authors );
  if ( !$full_pub->journal and !$full_pub->year ) {
    $full_pub->_citation_display( $pub->_citation_display );
  }

  # Google uses number instead of issue
  if ( !$full_pub->issue and $full_pub->number ) {
    $full_pub->issue( $full_pub->number );
    $full_pub->number('');
  }

  # Add the linkout from the old object because it is not in the BibTeX
  #and thus not in the new object
  $full_pub->linkout( $pub->linkout );

  # What GoogleScholar provides is not really the abstract, but
  # better than nothing
  $full_pub->abstract( $pub->abstract ) if ( !$full_pub->abstract );

  # We don't use Google key
  $full_pub->citekey('');

  # Unset to mark as completed
  $full_pub->_details_link('');

  # Update plugin _hash with new data
  $full_pub->guid( $pub->guid );
  $self->_hash->{ $pub->guid } = $full_pub;

  return $full_pub;
}

sub needs_completing {
  ( my $self, my $pub ) = @_;

  return 1 if ( $pub->{_details_link} );
  return 0;
}

# match function to match a given publication object against Google
# Scholar.

sub match {

  ( my $self, my $pub ) = @_;

  my $query_doi      = '';
  my $query_title    = '';
  my $query_authors  = '';
  my $query_authors2 = '';

  # First we format the three query strings properly. Besides
  # HTML escaping we remove words that contain non-alphnumeric
  # characters. These words can cause severe problems.
  # 1) DOI
  $query_doi = _EscapeString( $pub->doi ) if ( $pub->doi );

  # 2) Title
  if ( $pub->title ) {
    my @tmp = ();
    ( my $tmp_title = $pub->title ) =~ s/(\(|\)|-|\.|,|:|;|\{|\}|\?|!)/ /g;
    foreach my $word ( split( /\s+/, $tmp_title ) ) {

      # words that contain non-alphnumeric and non-ascii
      # characters are removed
      next if ( $word =~ m/[^\w\s-]/ );
      next if ( $word =~ m/[^[:ascii:]]/ );

      # words with less than 3 characters are removed
      next if ( length($word) < 3 );

      my @google_stopwords = (
        'about', 'com',   'for',  'from', 'how', 'that', 'the', 'this', 'was', 'what',
        'when',  'where', 'will', 'with', 'und', 'and',  'www'
      );

      my $flag = 0;
      foreach my $stop_word (@google_stopwords) {
        if ( lc($word) eq $stop_word ) {
          $flag = 1;
          last;
        }
      }
      next if ( $flag == 1 );

      # Add Title-tag
      push @tmp, $word;
    }
    $query_title = _EscapeString( join( " ", @tmp ) );
    $query_title = 'allintitle:' . $query_title;
  }

  # 3) Authors. We just use each author's last name
  if ( $pub->authors ) {
    my @tmp = ();
    foreach my $author ( @{ $pub->get_authors } ) {

      # words that contain non-alphnumeric and non-ascii
      # characters are removed
      next if ( !defined $author->last );
      next if ( $author->last =~ m/[^\w\s-]/ );
      next if ( $author->last =~ m/[^[:ascii:]]/ );
      next if ( $author->last eq '' );

      push @tmp, 'author:' . $author->last;
    }
    $query_authors = _EscapeString( join( " ", @tmp ) );

    # make a query string containing at most the first two authors
    if ( my $tmp_author = shift(@tmp) ) {
      $query_authors2 = $tmp_author;
    }
    if ( my $tmp_author = shift(@tmp) ) {
      $query_authors2 .= ' ' . $tmp_author;
    }
    $query_authors2 = _EscapeString($query_authors2);
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

    my $query    = $searchUrl . $query_doi . "&as_vis=1";
    my $response = $browser->get($query);
    my $content  = $response->content;

    my $error_level = _check_content($content);
    if ( $error_level == 1 ) {
      NetError->throw( error => 'Google Scholar blocks queries from this IP.' );
    }

    # everythig is fine we can process this page
    if ( $error_level == 0 ) {

      # parse the page and then see if a publication matches
      if ( $pub->title() ) {
        my $page = $self->_parse_googlescholar_page($content);

        # generate guids
        $self->_save_page_to_hash($page);
        my $matchedpub = $self->_find_best_hit( $page, $pub );

        if ($matchedpub) {
          return $matchedpub;
        } else {

          # We resolve the doi using dx.doi.org of the first hit
          if ( $page->[0] ) {
            my $fullpub      = $self->complete_details( $page->[0] );
            my $doi_response = $browser->get( 'http://dx.doi.org/' . $pub->doi );
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
        my $page = $self->_parse_googlescholar_page($content);
        if ( $page->[0] ) {
          my $fullpub = $self->complete_details( $page->[0] );

          # We resolve the doi using dx.doi.org
          my $doi_response = $browser->get( 'http://dx.doi.org/' . $pub->doi );
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
  }

  # If we are here, it means a search using the DOI was not conducted or
  # not successfull. Now we try a query using title and authors.

  #   if ( $query_title ne '' and $query_authors ne '' ) {

  #     # we add "&as_vis=1" to exclude citations and get only those links
  #     # that have stronger support
  #     my $query_string = "$query_title+$query_authors" . "&as_vis=1";
  #     print STDERR "Searching with title and full author list.\n";
  #     print STDERR "$searchUrl$query_string\n";

  #     # Now let's ask GoogleScholar again with Authors/Title
  #     my $query    = $searchUrl . $query_string;
  #     my $response = $browser->get($query);
  #     my $content  = $response->content;

  #     my $error_level = _check_content($content);
  #     if ( $error_level == 1 ) {
  #       NetError->throw( error => 'Google Scholar blocks queries from this IP.' );
  #     }

  #     # everything is fine we can process this page
  #     if ( $error_level == 0 ) {

  #       # parse the page and then see if a publication matches
  #       my $page = $self->_parse_googlescholar_page($content);
  #       # generate guids
  #       $self->_save_page_to_hash($page);
  #       my $matchedpub = $self->_find_best_hit( $page, $pub );
  #       if ($matchedpub) {
  #         return $matchedpub;
  #       }
  #     }
  #   }

  # If we are here we failed to a get a candidate hit with
  # title and full author list search
  # let's try it with a reduced list of authors
  if ( $query_title ne '' and $query_authors2 ne '' ) {

    # we add "&as_vis=1" to exclude citations and get only those links
    # that have stronger support
    my $query_string = "$query_title+$query_authors2" . "&as_vis=1";
    print STDERR "Seaching with title and reduced author list.\n";
    print STDERR "$searchUrl$query_string\n";

    # Now let's ask GoogleScholar again with Authors/Title
    my $query    = $searchUrl . $query_string;
    my $response = $browser->get($query);
    my $content  = $response->content;

    my $error_level = _check_content($content);
    if ( $error_level == 1 ) {
      NetError->throw( error => 'Google Scholar blocks queries from this IP.' );
    }

    # everything is fine we can process this page
    if ( $error_level == 0 ) {

      # parse the page and then see if a publication matches
      my $page = $self->_parse_googlescholar_page($content);

      # generate guids
      $self->_save_page_to_hash($page);
      my $matchedpub = $self->_find_best_hit( $page, $pub );
      if ($matchedpub) {
        return $matchedpub;
      }
    }
  }

  # If we are here then Title+Auhtors failed, and we try to search
  # only with the title and include also citations this time.
  # Final quality check if there are enough words in the title
  # to give a significant match

  my $count_words = ( $query_title =~ tr/\+// );
  if ( $query_title ne '' and $count_words >= 5 ) {
    my $query_string = "$query_title" . "&as_vis=0";
    print STDERR "Searching with title only.\n";
    print STDERR "$searchUrl$query_string\n";

    # Now let's ask GoogleScholar again with Authors/Title
    my $query    = $searchUrl . $query_string;
    my $response = $browser->get($query);
    my $content  = $response->content;

    my $error_level = _check_content($content);
    if ( $error_level == 1 ) {
      NetError->throw( error => 'Google Scholar blocks queries from this IP.' );
    }

    # everything is fine we can process this page
    if ( $error_level == 0 ) {

      # parse the page and then see if a publication matches
      my $page = $self->_parse_googlescholar_page($content);

      # generate guids
      $self->_save_page_to_hash($page);
      my $matchedpub = $self->_find_best_hit( $page, $pub );

      if ($matchedpub) {
        return $matchedpub;
      }
    }
  }

  # If we are here then all search strategies failed.
  NetMatchError->throw( error => 'No match against GoogleScholar.' );
}

# Gets from a list of GoogleScholar hits the one that fits
# the publication title we are searching for best
sub _find_best_hit {
  ( my $self, my $hits_ref, my $orig_pub ) = @_;

  my @google_hits = @{$hits_ref};
  if ( $#google_hits > -1 ) {

    # let's get rid of words that contain none ASCII chars
    # and other bad stuff (often PDF utf-8 issues)
    my @words = ();
    ( my $tmp_orig_title = $orig_pub->title ) =~ s/(\(|\)|-|\.|,|:|;|\{|\}|\?|!|\*)/ /g;
    $tmp_orig_title =~ s/\s+/ /g;
    foreach my $word ( split( /\s+/, $tmp_orig_title ) ) {
      next if ( $word =~ m/([^[:ascii:]])/ );
      next if ( length($word) < 2 );    # skip one letter words
      push @words, $word if ( $word =~ m/^\w+$/ );
    }
    print STDERR "GS - title publication: $tmp_orig_title\n";

    # now we screen each hit and see which one matches best
    my $max_counts = $#words;
    my $best_hit   = -1;

    # we take a look at the top three candidates
    my $max_to_screen = ( $#google_hits < 2 ) ? $#google_hits : 2;
    foreach my $i ( 0 .. $max_to_screen ) {

      # In some cases it is necessary to get the BibTex entry,
      # because sometimes not the full title is displayed. These
      # cases can be identified by the '...' Hex-code 2026
      my $tmp_title;
      if ( $google_hits[$i]->title =~ m/\x{2026}/ ) {
        my $tmp_pub = $self->complete_details( $google_hits[$i] );
        $tmp_title = $tmp_pub->title;
      } else {
        $tmp_title = $google_hits[$i]->title;
      }

      # some preprocessing again
      my @words2 = ();
      $tmp_title =~ s/(\(|\)|-|\.|,|:|;|\{|\}|\?|!|\*)/ /g;
      $tmp_title =~ s/\s+/ /g;
      foreach my $word ( split( /\s+/, $tmp_title ) ) {
        next if ( $word =~ m/([^[:ascii:]])/ );
        push @words2, $word if ( $word =~ m/^\w+$/ );
      }
      $tmp_title = " " . join( " ", @words2 ) . " ";
      print STDERR "GS - title hit $i: $tmp_title\n";

      # let's check how many of the words in the title match
      my $counts = 0;
      foreach my $word (@words) {
        $counts++ if ( $tmp_title =~ m/\s$word\s/i );

        #print "$counts || $word || $tmp_title\n";
      }
      print STDERR "counts: $counts max_counts: $max_counts\n";

      if ( $counts > $max_counts ) {
        $max_counts = $counts;
        $best_hit   = $i;
      }

      # if we fail, we try it a little less restrictive
      if ( $best_hit == -1 and $max_counts >= 10 ) {
        if ( $counts >= $max_counts ) {
          $best_hit = $i;
        }
      }
    }

    # now let's look up the BibTeX record and see if it is really
    # what we are looking for
    if ( $best_hit > -1 ) {
      my $fullpub = $self->complete_details( $google_hits[$best_hit] );
      print STDERR "Input: ",$orig_pub->title,"\n";
      print STDERR $orig_pub->authors,"\n";
      print STDERR "Google Scholar Hit final: ",$fullpub->title,"\n";
      print STDERR $fullpub->authors,"\n";

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
  $tree->utf8_mode(0);
  $content = decode_utf8($content);
  $tree->parse_content($content);

  my %data = (
    authors          => [],
    titles           => [],
    citations        => [],
    urls             => [],
    bibtex           => [],
    versions         => [],
    www_publisher    => [],
    related_articles => [],
    BL               => [],
    description      => []
  );

  # Each entry has a DIV
  my @nodes = $tree->findnodes('/html/body/*/div[@class="gs_r"]');
  if ( $#nodes == -1 ) {
    NetFormatError->throw( error => 'Was not able to parse GoogleScholar HTML correctly.' );
  }

  foreach my $node (@nodes) {

    my ( $title, $url );

    # A link to a web-resource is available
    if ( $node->findnodes('./*/h3/a') ) {
      $title = $node->findvalue('./*/h3/a');
      $url   = $node->findvalue('./*/h3/a/@href');

      # citation only
    } else {

      $title = $node->findvalue('./*/h3');

      # Remove the tags [CITATION] and [BOOK] (and the character
      # afterwards which is a &nbsp;)
      $title =~ s/\[CITATION\].//;
      $title =~ s/\[BOOK\].//;

      $url = '';
    }
    push @{ $data{titles} }, $title;
    push @{ $data{urls} },   $url;

    # Most information is contained in a <span> tag
    my $line = $node->findvalue(q{./font[@size='-1']/span[@class='gs_a']});

    my ( $authors, $citation, $publisher ) = split( / - /, $line );

    # we set _www_publisher, which is used then again in _complete_details
    push @{ $data{www_publisher} }, defined($publisher) ? $publisher : '';

    # sometime the publisher is just a plain IP-address or some URL
    if ( defined $publisher ) {
      undef($publisher) if ( $publisher =~ m/\.[A-Z]{3}$/i );
    }
    if ( defined $publisher ) {
      undef($publisher) if ( $publisher =~ m/\d{3}\./ );
    }

    $citation .= "- $publisher" if ( defined $publisher );

    push @{ $data{authors} },   defined($authors)  ? $authors  : '';
    push @{ $data{citations} }, defined($citation) ? $citation : '';

    # Get the few lines of text Google gives
    my $description = $node->findnodes_as_string(q{.});
    $description =~ s/(.*<\/span>)(.*)(<span\sclass="gs_fl">.*)/$2/;
    $description =~ s/<b>//g;
    $description =~ s/<\/b>//g;
    $description =~ s/<br\s\/>//g;
    push @{ $data{description} }, defined($description) ? $description : '';

    my @links = $node->findnodes('./font[@size="-1"]/span[@class="gs_fl"]/a');

    # Find the BibTeX export links
    my $cluster_link_found = 0;
    my $related_link_found = 0;
    my $BL_link_found      = 0;
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
    push @{ $data{versions} },         '' if ( $cluster_link_found == 0 );
    push @{ $data{related_articles} }, '' if ( $related_link_found == 0 );
    push @{ $data{BL} },               '' if ( $BL_link_found == 0 );
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
    $pub->abstract( $data{description}->[$i] );
    $pub->refresh_fields;
    push @$page, $pub;
  }

  return $page;

}

1;
