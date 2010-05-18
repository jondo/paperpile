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

package Paperpile::Plugins::Import::ArXiv;

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
use Paperpile::Utils;

extends 'Paperpile::Plugins::Import';

# agruber
# The search query to be send to ArXiv
has 'query' => ( is => 'rw' );

# The main search URL
my $searchUrl    = 'http://export.arxiv.org/api/query?search_query=';
my $searchUrl_ID = 'http://export.arxiv.org/api/query?id_list=';

sub BUILD {
  my $self = shift;
  $self->plugin_name('ArXiv');
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

  return join( "+AND+", @tmp );
}

# Format the query sent to ArXiv. This means escaping
# things like non-alphanumeric characters and joining words with '+'.

sub FormatQueryString {
  my $self  = shift;
  my $query = $_[0];

  my @tmp = split( / /, $query );
  foreach my $i ( 0 .. $#tmp ) {
    $tmp[$i] = 'all:' . uri_escape( $tmp[$i] );
  }

  return join( "+AND+", @tmp );
}

sub FormatQueryStringID {
  my $self  = shift;
  my $query = $_[0];

  my @tmp = split( / /, $query );
  foreach my $i ( 0 .. $#tmp ) {
    $tmp[$i] = uri_escape( $tmp[$i] );
  }

  return join( ";", @tmp );
}

sub connect {
  my $self = shift;

  my $browser = Paperpile::Utils->get_browser;

  my $query_string = $self->FormatQueryString( $self->query );

  my $response = $browser->get( $searchUrl . $query_string . '&max_results=500' );
  my $result = XMLin( $response->content, ForceArray => 1 );

  # Determine the number of hits
  my $number  = 0;
  my @entries = ();
  if ( $result->{entry} ) {
    @entries = @{ $result->{entry} };
    $number  = $#entries + 1;
    $self->total_entries($number);
  } else {

    # if we did not find anything, it does not necessarily mean
    # that there is really noting. The user might just have provided
    # an ArXiv Id, which has to retrieved by other ways
    $query_string = $self->FormatQueryStringID( $self->query );
    $response     = $browser->get( $searchUrl_ID . $query_string );
    $result       = XMLin( $response->content, ForceArray => 1 );
    if ( $result->{entry} ) {
      @entries = @{ $result->{entry} };
      $number  = $#entries + 1;
      if ( $number == 1 ) {
        if ( $result->{entry}->[0]->{title}->[0] eq 'Error' ) {
          $self->total_entries(0);
          return 0;
        }
      }
      $self->total_entries($number);
    } else {
      $self->total_entries(0);
      return 0;
    }
  }

  # We store the results so that they can be retrieved afterwards
  # We keep the way of storage that is used in other Plugins
  # The problem is that ArXiv supports paging, i.e. you can
  # retrieve results xx to xx, however you get all results at once
  # So there is no need to store them page-wise
  $self->_page_cache( {} );
  $self->_page_cache->{0}->{0} = \@entries;

  # Return the number of hits
  return $self->total_entries;
}

sub page {
  ( my $self, my $offset, my $limit ) = @_;

  # Get the content of the page via cache
  my @content;
  if ( $self->_page_cache->{0}->{0} ) {
    @content = @{ $self->_page_cache->{0}->{0} };
  }

  # let's first move the entries we want to parse to
  # a separate array
  my @tmp_content = ();
  my $max = ( $#content < $offset + $limit - 1 ) ? $#content : $offset + $limit - 1;
  foreach my $i ( $offset .. $max ) {
    push @tmp_content, $content[$i];
  }

  # then parse the results page
  my $page = $self->_parse_arxiv_page( \@tmp_content );

  $self->_save_page_to_hash($page);

  return $page;

}

# the functionality of parsing the ArXiv results page
# implemented originally in the sub "page" was moved to this
# separate sub as it is needed by the sub "match" too.
# it returns an array reference of publication objects
sub _parse_arxiv_page {

  ( my $self, my $content_ref ) = @_;

  my @content = @{$content_ref};
  my $page    = [];

  foreach my $i ( 0 .. $#content ) {
    my $entry = $content[$i];

    # Title and abstract are easy, they are regular elements
    my $title    = join( ' ', @{ $entry->{title} } );
    my $abstract = join( ' ', @{ $entry->{summary} } );
    $title =~ s/\n//g;
    $title =~ s/\s+/ /g;

    # Now we add the authors
    my @authors = ();

    foreach my $author ( @{ $entry->{author} } ) {
      push @authors,
        Paperpile::Library::Author->new()->parse_freestyle( $author->{name}->[0] )->bibtex();
    }

    # If there is a journal reference, we can parse it and
    # fill the following fields

    my $journal = '';
    my $year    = '';
    my $volume  = '';
    my $issue   = '';
    my $pages   = '';
    my $comment = '';
    my $pubtype = 'MISC';
    if ( $entry->{'arxiv:journal_ref'} ) {
      my $journal_line = @{ $entry->{'arxiv:journal_ref'} }[0]->{content};
      $journal_line =~ s/\n//g;
      $journal_line =~ s/\s+/ /g;
      ( $journal, $year, $volume, $issue, $pages, $comment ) = parseJournalLine($journal_line);
      $pubtype = 'ARTICLE' if ( $journal ne '' );

      # NOTE: if there is something in comment and journal is empty
      # then we were not able to parse the journal string correctly
    }

    if ( !$year ) {
      my $date = join( ' ', @{ $entry->{published} } );
      if ( $date =~ /(\d\d\d\d)-(\d\d)/ ) {
        $year = $1;
      }
    }

    my $doi = '';
    if ( $entry->{'arxiv:doi'} ) {
      $doi = @{ $entry->{'arxiv:doi'} }[0]->{content};
    }

    my $pub = Paperpile::Library::Publication->new( pubtype => $pubtype );

    my $abs = join( ' ', @{ $entry->{id} } );

    my $pdf = $abs;
    $pdf =~ s/\/abs\//\/pdf\//;

    my $id = $abs;
    $id =~ s!http://arxiv\.org/abs/!arXiv:!;

    if ( $pubtype ne 'ARTICLE' ) {
      $pub->howpublished('Preprint');
    }

    $pub->linkout($abs);
    $pub->eprint($id);
    $pub->_pdf_url($pdf);

    $pub->title($title)       if $title;
    $pub->abstract($abstract) if $abstract;
    $pub->authors( join( ' and ', @authors ) );
    $pub->volume($volume)   if ( $volume  ne '' );
    $pub->issue($issue)     if ( $issue   ne '' );
    $pub->year($year)       if ( $year    ne '' );
    $pub->pages($pages)     if ( $pages   ne '' );
    $pub->journal($journal) if ( $journal ne '' );
    $pub->journal($comment) if ( $journal eq '' and $comment ne '' );
    $pub->doi($doi) if ( $doi ne '' );

    $pub->refresh_fields;
    push @$page, $pub;
  }

  return $page;
}

sub parseJournalLine {
  my $line    = $_[0];
  my $backup  = $line;
  my $journal = '';
  my $year    = '';
  my $volume  = '';
  my $issue   = '';
  my $pages   = '';
  my $strange = '';
  my $comment = '';

  my $debug = 0;

  # some preprocessing
  $line =~ s/-+/-/g;
  $line =~ s/\s-\s/-/g;
  $line =~ s/\s-/-/g;
  $line =~ s/~/-/g;
  $line =~ s/\.$//;
  $line =~ s/\./. /g;
  $line =~ s/:/ /g;
  $line =~ s/,/ /g;
  $line =~ s/;/ /g;
  $line =~ s/\(/ (/g;
  $line =~ s/\)/) /g;

  # sometime there is TeX in it
  $line =~ s/\\bf//g;
  $line =~ s/{//g;
  $line =~ s/}//g;

  $line =~ s/\s+/ /g;

  # get rid of month/date stuff
  $line =~
    s/(.*)(\d{0,2}\s?(january|february|march|mar\.|april|may|june|july|august|Aug\.|september|october|Oct\.|november|Nov\.|december|Dec\.))\s((19|20)\d\d)(.*)/$1$4$6/gi;
  $line =~
    s/(.*)((january|february|march|mar\.|april|may|june|july|august|Aug\.|september|october|Oct\.|november|Nov\.|december|Dec\.)\s\d{0,2}\s?)((19|20)\d\d)(.*)/$1$4$6/gi;

  # get rid of some pages stuff
  $line =~ s/(.*)(\(\d+\spages\))(.*)/$1$3/;

  $line .= ' ';

  # sometime there is no space between a word and the number (eg. journal and volume)
  my @tmp = split( //, $line );
  for my $i ( 0 .. $#tmp - 1 ) {
    $tmp[$i] = $tmp[$i] . ' ' if ( $tmp[$i] =~ m/[A-Z]/i and $tmp[ $i + 1 ] =~ m/[1-9]/ );
  }
  $line = join( '', @tmp );

  print "   PREPROC: $line\n" if ( $debug == 1 );

  # first we use regular expressions to parse things that are obvious

  # ======================= PAGES ===========================
  # so far I have seen pages like the following:
  # 1) pages ???-???
  # 2) pp. ???-???
  # 2a) pp. ????~???
  # 3) p. ???-???
  # 4) p ???-???

  if ( $line =~ m/((pp\.?|p\.?|pages)\s?\d+-\d+)\D*/ ) {
    $pages = $1;
    $line =~ s/$pages//;
    print "   MODIFIED: $line\n" if ( $debug == 1 );
    $pages =~ s/(.*\D)(\d+-\d+)/$2/;
  }

  # 4) ???-???
  # 4a) S???-????
  # 4b) R???-????
  if ( $line =~ m/\s((R|S)*\s*\d+-\d+)\D/ and $pages eq '' ) {
    $pages = $1;
    $line  =~ s/$pages\s//;
    $pages =~ s/[^\d|-]//g;
    print "   MODIFIED: $line\n" if ( $debug == 1 );
  }

  # 5) R ???-R ???
  # 6) S ???-S ???
  # 6a) L ???-L ???
  if ( $line =~ m/\s((R|S|L)\s\d+-(R|S|L)\s\d+)\s/ and $pages eq '' ) {
    $pages = $1;
    $line  =~ s/$pages\s//;
    $pages =~ s/[^\d|-]//g;
    print "   MODIFIED: $line\n" if ( $debug == 1 );
  }

  # 7) S ???
  # 8) R ???
  # 9) L ???
  if ( $line =~ m/\s((R|S|L)\s\d+)\s/ and $pages eq '' ) {
    $pages = $1;
    $line  =~ s/$pages\s//;
    $pages =~ s/[^\d|-]//g;
    print "   MODIFIED: $line\n" if ( $debug == 1 );
  }

  # ======================= VOLUME ===========================
  # 1) Vol. ??
  # 2) vol. ??
  # 3) Volume ??
  # 4) v. ??
  # 5) v ??

  if ( $line =~ m/\s((Vol\.?|Volume|v\.?)\s\d+)\D*/i ) {
    $volume = $1;
    $line   =~ s/$volume//;
    $volume =~ s/\D//g;
    print "   MODIFIED: $line\n" if ( $debug == 1 );
  }

  # ======================= ISSUE ===========================
  # 1) Number ??
  # 2) No. ??\w
  # 2) No ??
  # 3) N ??
  # 4) n. ??
  # 5) Issue ??

  if ( $line =~ m/\s((No\.?|number|N|n\.|Issue)\s\d+[A-Za-z]?)\D*/i ) {
    $issue = $1;
    $line  =~ s/$issue//;
    $issue =~ s/\D//g;
    print "   MODIFIED: $line\n" if ( $debug == 1 );
  }

  # 6) (?)
  if ( $line =~ m/\s(\(\d\d?\))\s/i and $issue eq '' ) {
    $issue = $1;
    $line  =~ s/\($issue\)//;
    $issue =~ s/\D//g;
    print "   MODIFIED: $line\n" if ( $debug == 1 );
  }

  # 7) (?-?)
  # 8) (?/?)
  if ( $line =~ m/\s(\(\d+-\d+\))\s/i and $issue eq '' ) {
    $issue = $1;
    $line  =~ s/\($issue\)//;
    $issue =~ s/(.*)(\d+-\d+)(.*)/$2/g;
    print "   MODIFIED: $line\n" if ( $debug == 1 );
  }
  if ( $line =~ m/\s(\(\d+\/\d+\))\s/i and $issue eq '' ) {
    $issue = $1;
    $line  =~ s/\($issue\)//;
    $issue =~ s/(.*)(\d+\/\d+)(.*)/$2/g;
    print "   MODIFIED: $line\n" if ( $debug == 1 );
  }

  # ====================== YEAR ==============================
  # 1) (19xx) or (20xx)
  if ( $line =~ m/(\((19|20)\d\d\))/i ) {
    $year = $1;
    $line =~ s/\($year\)//;
    $year =~ s/\D//g;
    print "   MODIFIED: $line\n" if ( $debug == 1 );
  }

  # 2) (??/??/19xx) or (??/??/20xx)
  if ( $line =~ m/(\(\d\d\/\d\d\/(19|20)\d\d\))/i ) {
    $year = $1;
    $line =~ s/\($year\)//;
    $year =~ s/(.*)((19|20)\d\d)(\))/$2/g;
    print "   MODIFIED: $line\n" if ( $debug == 1 );
  }

# 3) (?? month 19|20xx)
#if ($line =~ m/(\(.*(january|february|march|april|may|june|july|august|september|october|november|december)\s(19|20)\d\d\))/i)
#{
# 	$year = $1;
#	$line =~ s/\($year\)//;
#	$year =~ s/(.*)((19|20)\d\d)(\))/$2/g;
#	print "   MODIFIED: $line\n" if ($debug == 1);
#}

  # ====================== STRANGE NUMBERS ===================
  # 1) 0??????? sometime article numnbers
  my @strange_numbers = ();
  my $flag_0          = 1;
  while ( $flag_0 == 1 ) {
    $flag_0 = 0;
    if ( $line =~ m/\s([A-Z]?0\d+)\s/ ) {
      $strange = $1;
      push @strange_numbers, $strange;
      $line =~ s/$strange//;
      print "   MODIFIED: $line\n" if ( $debug == 1 );
      $flag_0 = 1;
    }
  }

  # ====================== JOURNAL NAME ===================
  # 1) until we see two spaces
  # 2) until we see a number

  if ( $line =~ m/(^[A-Z|\s|\.|&]+)\s\s/i ) {
    $journal = $1;
    $line =~ s/$journal//;
    print "   MODIFIED: $line\n" if ( $debug == 1 );
  }

  if ( $line =~ m/(^[A-Z|\s|\.|&]+)\s\d/i and $journal eq '' ) {
    $journal = $1;
    $line =~ s/$journal//;
    print "   MODIFIED: $line\n" if ( $debug == 1 );
  }

  # ====================== VOLUME AGAIN ===================
  # next number

  if ( $line =~ m/(^\s*\d+[A-Z]?)\s/i and $volume eq '' ) {
    my $tmp1 = $1;
    if ( $tmp1 =~ m/^\d+$/ ) {
      if ( $tmp1 < 5000 ) {
        $volume = $tmp1;
        $line =~ s/$volume//;
        print "   MODIFIED: $line\n" if ( $debug == 1 );
      }
    } else {
      $volume = $tmp1;
      $line =~ s/$volume//;
      print "   MODIFIED: $line\n" if ( $debug == 1 );
    }
  }

  # ====================== VOLUME/ISSUE ===================
  if ( $line =~ m/(^\s*\d+\/\d+)\s/i and $volume eq '' and $issue eq '' ) {
    my $tmp0 = $1;
    ( $volume, $issue ) = split( /\//, $tmp0 );
    $line =~ s/$tmp0//;
    print "   MODIFIED: $line\n" if ( $debug == 1 );
  }

  # ================ STILL SOMETHING LEFT? =================
  if ( $line =~ m/(^\s*\d+)\s/ ) {
    my $tmp1 = $1;
    my $flag = 0;
    if ( $tmp1 < 10 and $issue eq '' and $pages ne '' ) {
      $issue = $tmp1;
      $line =~ s/$issue//;
      print "   MODIFIED: $line\n" if ( $debug == 1 );
      $flag = 1;
    }
    if ( $tmp1 < 10000 and $pages eq '' and $flag == 0 ) {
      $pages = $tmp1;
      $line =~ s/$pages//;
      print "   MODIFIED: $line\n" if ( $debug == 1 );
    }
  }

  # ================ STILL YEAR LEFT? =================
  if ( $line =~ m/(^\s*\d+)\s/ ) {
    my $tmp1 = $1;
    my $flag = 0;
    if ( $tmp1 >= 1900 and $tmp1 <= 2099 and $year eq '' ) {
      $year = $tmp1;
      $line =~ s/$year//;
      print "   MODIFIED: $line\n" if ( $debug == 1 );
    } else {

      # we just remove it
      $line =~ s/$tmp1//;
      push @strange_numbers, $tmp1;
      print "   MODIFIED: $line\n" if ( $debug == 1 );

    }
  }

  # some postprocessing and control
  $journal =~ s/\s+/ /g;
  $journal =~ s/\s$//;
  $volume  =~ s/\s//g;
  $pages   =~ s/\s//g;
  $year    =~ s/\s//g;
  $issue   =~ s/\s//g;
  $line    =~ s/\s+/ /g;
  $comment .= join( " ", @strange_numbers ) if ( $#strange_numbers > -1 );
  my $length = length($line);

  # if there is something left
  if ( length($line) > 1 ) {

    # looks fine, the rest is set as comment
    my $flag_1 = 0;
    if ( $journal ne '' and $year ne '' and $pages ne '' and $volume ne '' ) {
      $comment .= " $line";
      $flag_1 = 1;
    }
    if ( $journal ne '' and $year ne '' and $volume ne '' and length($line) < 10 ) {
      $comment .= " $line";
      $flag_1 = 1;
    }
    if ( $flag_1 == 0 ) {
      $journal = '';
      $year    = '';
      $volume  = '';
      $issue   = '';
      $pages   = '';
      $comment = $backup;
    }
  }

  return ( $journal, $year, $volume, $issue, $pages, $comment );
}

# match function to match a given publication object against ArivX.

sub match {

  ( my $self, my $pub ) = @_;

  my $query_doi      = '';
  my $query_arxiv_id = '';
  my $query_title    = '';
  my $query_authors  = '';

  # First we format the three query strings properly. Besides
  # HTML escaping we remove words that contain non-alphnumeric
  # characters. These words can cause severe problems.

  # 1) DOIs are sometimes supported, but Arxiv Ids work best. It is at the
  # moment stored in pmid
  $query_doi      = _EscapeString( $pub->doi )  if ( $pub->doi );
  $query_arxiv_id = _EscapeString( $pub->arxivid ) if ( $pub->arxivid );

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

      my @stopwords = (
        'about', 'com',   'for',  'from', 'how', 'that', 'the', 'this', 'was', 'what',
        'when',  'where', 'will', 'with', 'und', 'and',  'www'
      );

      my $flag = 0;
      foreach my $stop_word (@stopwords) {
        if ( lc($word) eq $stop_word ) {
          $flag = 1;
          last;
        }
      }
      next if ( $flag == 1 );

      # Add Title-tag
      push @tmp, "ti:$word";
    }
    $query_title = _EscapeString( join( " ", @tmp ) );
  }

  # 3) Authors. We just use each author's last name
  if ( $pub->authors ) {
    my @tmp = ();
    foreach my $author ( @{ $pub->get_authors } ) {

      # words that contain non-alphnumeric and non-ascii
      # characters are removed
      next if ( $author->last =~ m/[^\w\s-]/ );
      next if ( $author->last =~ m/[^[:ascii:]]/ );

      push @tmp, 'au:' . $author->last;
    }
    $query_authors = _EscapeString( join( " ", @tmp ) );
  }

  my $browser = Paperpile::Utils->get_browser;

  # let's first see if we have an arXiv identifier
  if ( $query_arxiv_id ne '' ) {
    my $query = $searchUrl_ID . $query_arxiv_id;

    #print STDERR "$query\n";
    my $response = $browser->get($query);
    my $result = XMLin( $response->content, ForceArray => 1 );

    if ( $result->{entry} ) {
      my @content = @{ $result->{entry} };
      my @tmp     = @{ $self->_parse_arxiv_page( \@content ) };

      if ( $#tmp == 0 ) {
        return $self->_merge_pub( $pub, $tmp[0] );
      }
    }
  }

  # if search with the arxiv id did not work or was not
  # conducted, we start a search using the title and authors
  if ( $query_title ne '' and $query_authors ne '' ) {
    my $query = $searchUrl . $query_title . '+AND+' . $query_authors . '&max_results=10';

    #print STDERR "$query\n";
    my $response = $browser->get($query);
    my $result = XMLin( $response->content, ForceArray => 1 );

    if ( $result->{entry} ) {
      my @content = @{ $result->{entry} };
      my $page    = $self->_parse_arxiv_page( \@content );

      my $matchedpub = $self->_find_best_hit( $page, $pub );

      if ($matchedpub) {
        print STDERR "Found a match using Authors/Title as query.\n";
        return $matchedpub;
      }
    }
  }

  # last chance with title only
  if ( $query_title ne '' ) {
    my $query = $searchUrl . $query_title . '&max_results=10';

    #print STDERR "$query\n";
    my $response = $browser->get($query);
    my $result = XMLin( $response->content, ForceArray => 1 );

    if ( $result->{entry} ) {
      my @content = @{ $result->{entry} };
      my $page    = $self->_parse_arxiv_page( \@content );

      my $matchedpub = $self->_find_best_hit( $page, $pub );

      if ($matchedpub) {
        print STDERR "Found a match using Title as query.\n";
        return $matchedpub;
      }
    }
  }

  # if we are here, then we were not succesful
  NetMatchError->throw( error => 'No match against ArXiv.' );
}

# Gets from a list of ArXiv hits the one that fits
# the publication title we are searching for best
sub _find_best_hit {
  ( my $self, my $hits_ref, my $orig_pub ) = @_;

  my @hits = @{$hits_ref};
  if ( $#hits > -1 ) {

    # let's get rid of words that contain none ASCII chars
    # and other bad stuff (often PDF utf-8 issues)
    my @words = ();
    ( my $tmp_orig_title = $orig_pub->title ) =~ s/(\(|\)|-|\.|,|:|;|\{|\}|\?|!)/ /g;
    $tmp_orig_title =~ s/\s+/ /g;
    foreach my $word ( split( /\s+/, $tmp_orig_title ) ) {
      next if ( $word =~ m/([^[:ascii:]])/ );
      next if ( length($word) < 2 );    # skip one letter words
      push @words, $word if ( $word =~ m/^\w+$/ );
    }

    # now we screen each hit and see which one matches best
    my $max_counts = $#words;
    my $best_hit   = -1;
    foreach my $i ( 0 .. $#hits ) {

      # some preprocessing again
      my @words2    = ();
      my $tmp_title = $hits[$i]->title;
      $tmp_title =~ s/(\(|\)|-|\.|,|:|;|\{|\}|\?|!)/ /g;
      $tmp_title =~ s/\s+/ /g;
      foreach my $word ( split( /\s+/, $tmp_title ) ) {
        next if ( $word =~ m/([^[:ascii:]])/ );
        push @words2, $word if ( $word =~ m/^\w+$/ );
      }
      $tmp_title = " " . join( " ", @words2 ) . " ";

      # let's check how many of the words in the title match
      my $counts = 0;
      foreach my $word (@words) {
        $counts++ if ( $tmp_title =~ m/\s$word\s/ );
      }
      if ( $counts > $max_counts ) {
        $max_counts = $counts;
        $best_hit   = $i;
      }
    }

    # some last controls
    if ( $best_hit > -1 ) {

      #if ( $self->_match_title( $hits[$best_hit]->title, $orig_pub->title ) ) {
      return $self->_merge_pub( $orig_pub, $hits[$best_hit] );

      #}
    }
  }

  return undef;
}

1;
