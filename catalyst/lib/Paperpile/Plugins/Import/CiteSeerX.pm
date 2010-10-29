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


package Paperpile::Plugins::Import::CiteSeerX;

use Carp;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;
use XML::Simple;
use HTML::TreeBuilder::XPath;
use HTML::Element;
use Lingua::EN::NameParse;
use 5.010;

use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Paperpile::Utils;

extends 'Paperpile::Plugins::Import';

# The search query to be send to CiteSeerX
has 'query' => ( is => 'rw' );

# The main search URL
my $searchUrl = 'http://citeseerx.ist.psu.edu/search?submit=Search&sort=rel&q=';

sub BUILD {
  my $self = shift;
  $self->plugin_name('CiteSeerX');
}

sub connect {
  my $self = shift;

  # First we get a LWP user agent. We always should get it via the
  # Utils function because this way we get a correctly configured
  # browser. Additional configuration can be added afterwards if
  # needed.

  my $browser = Paperpile::Utils->get_browser;

  # We have to modify the query string to fit citeseerX needs
  my @tmp_words = split( / /, $self->query );
  my $query_string = join( '+', @tmp_words );

  # Get the results
  my $response = $browser->get( $searchUrl . $query_string );
  my $content  = $response->content;

  # save first page in cache to speed up call to first page afterwards
  $self->_page_cache( {} );
  $self->_page_cache->{0}->{ $self->limit } = $content;

  # If nothing is found, we return that we have found 0 documents
  if ( $content =~ /did not match any documents/ ) {
    $self->total_entries(0);
    return 0;
  }

  # We parse the HTML via XPath
  my $tree = HTML::TreeBuilder::XPath->new;
  $tree->utf8_mode(1);
  $tree->parse_content($content);

  # Try to find the number of hits
  my $stats = $tree->findnodes(q{/html/body/div/div/div/div/div/div[@class="left_content"]});

  if ( $stats =~ /(\s)([0123456789,]+)(\sdocuments\sfound.*)/ ) {
    my $number = $2;
    $number =~ s/,//g;
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

    # We have to modify the query string to fit citeseerX needs
    my @tmp_words = split( / /, $self->query );
    my $query_string = join( '+', @tmp_words );

    # Get the results
    my $response = $browser->get( $searchUrl . $query_string . "&start=$offset" );
    $content = $response->content;
  }

  # Now we parse the HTML for information of interest
  my $tree = HTML::TreeBuilder::XPath->new;
  $tree->utf8_mode(1);
  $tree->parse_content($content);

  my %data = (
    authors   => [],
    titles    => [],
    citations => [],
    urls      => [],
    details   => [],
  );

  # Each document entry is listed in an ul-element
  my @nodes = $tree->findnodes('/html/body/div/div/div/div/div/div/div/ul');

  foreach my $node (@nodes) {

    # title is easy to find, and does not change anymore
    my $title = $node->findvalue('./li/a/em');
    push @{ $data{titles} }, $title;

    # now we parse the author line
    my $tmp = $node->findvalue('./li[@class="author char6 padded"]');
    ( my $authors = $tmp ) =~ s/\x{2014}.*//;
    $authors =~ s/^by\s//;
    push @{ $data{authors} }, $authors;

    # perhaps there is something like a year or a journal
    my $citation_tmp = '';
    if ( $tmp =~ m/\x{2014}/ ) {
      my @temp = split( /\x{2014}/, $tmp );

      for my $i ( 1 .. $#temp ) {
        $citation_tmp .= " $temp[$i]";
      }
    }
    push @{ $data{citations} }, $citation_tmp;

    # finally get the details link
    my @links = $node->findnodes('./li/a[@class="remove doc_details"]');
    my $url   = "http://citeseerx.ist.psu.edu" . $links[0]->attr('href');
    push @{ $data{details} }, $url;

    # direct link to cached pdf
    ( my $doi = $links[0]->attr('href') ) =~ s/\/viewdoc\/summary;//;
    my $pdf_url = "http://citeseerx.ist.psu.edu/viewdoc/download?$doi&rep=rep1&type=pdf";

  }

  # Write output list of Publication records with preliminary
  # information and full information. Title and authors do not
  # change if we call complete_details. Citation, though, may change
  # as volume or issue are provided. So citation info is just
  # preliminary stored in citation_display.
  my $page = [];

  foreach my $i ( 0 .. @{ $data{titles} } - 1 ) {
    my $pub = Paperpile::Library::Publication->new();

    # no modifiction is neeeded, title can be used as is
    $pub->title( $data{titles}->[$i] );

    # The authors provided by citeseerx are somewhat crapy
    # Sometimes you find an author named something like
    # 'Department of Biochemisty'. Therefore we call
    # Lingua::EN::NameParse as used in PfdExtract.
    my %args = (
      auto_clean     => 1,
      force_case     => 1,
      lc_prefix      => 1,
      initials       => 3,
      allow_reversed => 1
    );

    my $parser = new Lingua::EN::NameParse(%args);

    my @tmp_authors = split( /,/, $data{authors}->[$i] );
    my @authors = ();

    if ( $data{authors}->[$i] =~ m/Unknown\sAuthors/i ) {
      $pub->authors('NN');
    } else {
      foreach my $tmp_author (@tmp_authors) {
        my $error = $parser->parse($tmp_author);
        if ( $error == 0 ) {
          my $correct_casing = $parser->case_all_reversed;
          ( my $last, my $first ) = split( /,/, $correct_casing );

          # make a new author object
          push @authors,
            Paperpile::Library::Author->new(
            last  => $last,
            first => $first,
            jr    => '',
            )->normalized;

        }
      }
      $pub->authors( join( ' and ', @authors ) );
    }

    # citations may change upon complete_details call,
    # so we store only preliminary information
    $pub->_citation_display( $data{citations}->[$i] );

    #  $pub->linkout( $data{urls}->[$i] );
    # pdf_url still has to be set

    # details link for complete_details call
    $pub->_details_link( $data{details}->[$i] );
    $pub->refresh_fields;
    push @$page, $pub;
  }

  # we should always call this function to make the results available
  # afterwards via find_sha1
  $self->_save_page_to_hash($page);

  return $page;

}

# We parse CiteSeerX in a two step process. First we scrape off
# what we see and display it more or less unchanged (authors are
# already correctly parsed) in the front end via
# _citation_display. If the user clicks on an
# entry the missing information is completed from the BibTeX
# entry there. This ensures fast search results and avoids too many
# requests to CiteSeerX which is potentially harmful.

sub complete_details {

  ( my $self, my $pub ) = @_;

  my $browser = Paperpile::Utils->get_browser;

  # Get the details page inlcuding the abstract and the bibtex entry
  my $details = $browser->get( $pub->_details_link );
  my $content = $details->content;

  # Create a new Publication object
  my $full_pub = Paperpile::Library::Publication->new();

  # Now we parse the HTML for information of interest
  my $tree = HTML::TreeBuilder::XPath->new;
  $tree->utf8_mode(1);
  $tree->parse_content($content);

  # let's find the bibtex entry first
  # Note, that even the title can change!
  my $bibtex = $tree->findvalue('/html/body/div/div/div/div/div/div/div/div[@class="content"]');
  $bibtex =~ s/(.*)(@.*)/$2/;
  $bibtex =~ s/\x{A0}/ /g;

  # sometimes the requested site is simply not there at CiteSeerX
  # then there is no Bibtex entry available and we die
  if ( $bibtex !~ m/@/ ) {
    $full_pub->authors( $pub->authors );
    $full_pub->title( $pub->title );

    # now we should raise an error
    # ERRRRRRRROOOOOOOORRRRRRRRR
  } else {

    $full_pub->import_string( $bibtex, 'BIBTEX' );

    # since we have already parsed the authors before, and we did
    # in more clever way, we overwrite the authors field with the
    # old values
    $full_pub->authors( $pub->authors );

    # now we look for the abstract
    my $abstract = $tree->findvalue('/html/body/div/div/div/div/p[@class="para4"]');
    if ($abstract) {
      $abstract =~ s/^Abstract.//;
      $full_pub->abstract($abstract);
    } else {
      $full_pub->abstract('');
    }
  }

  # Add the linkout from the old object as it is not in the Bibtex
  $full_pub->linkout( $pub->linkout );

  # Note that if we change title, authors, and citation also the sha1
  # will change. We have to take care of this.
  my $old_sha1 = $pub->sha1;
  my $new_sha1 = $full_pub->sha1;
  delete( $self->_hash->{$old_sha1} );
  $self->_hash->{$new_sha1} = $full_pub;

  return $full_pub;

}

1;
