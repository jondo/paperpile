package Paperpile::Plugins::Import::ACM;

use Carp;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;
use XML::Simple;
use HTML::TreeBuilder::XPath;
use 5.010;

use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Paperpile::Library::Journal;
use Paperpile::Utils;

extends 'Paperpile::Plugins::Import';

# The search query to be send to ACM Portal
has 'query' => ( is => 'rw' );

# The main search URL
# dl=GUIDE for 'The Guide" whatever this is
# dl=Portal for 'The ACM Digital Library'
my $searchUrl = 'http://portal.acm.org/results.cfm?coll=Portal&dl=GUIDE&termshow=matchall&query=';


sub BUILD {
  my $self = shift;
  $self->plugin_name('ACM');
}

sub connect {
  my $self = shift;

  
  my $browser = Paperpile::Utils->get_browser;

  # Get the results
  (my $tmp_query = $self->query) =~ s/\s+/+/g;
  my $response = $browser->get( $searchUrl . $tmp_query );
  
  my $content  = $response->content;

  # save first page in cache to speed up call to first page afterwards
  $self->_page_cache( {} );
  $self->_page_cache->{0}->{ $self->limit } = $content;

  # Nothing found
  if ( $content =~ /was not found. Start a new search or use/ ) {
    $self->total_entries(0);
    return 0;
  }

  # Try to find the number of hits
  # Maybe that could be done faster with XPath, one has to rethink
  if ( $content =~ m/Results\s\d+\s-\s\d+\sof\s([1234567890,]+)/ ) {
    my $number = $1;
    $number =~ s/,//;
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
      my $nr = $offset+1;
      (my $tmp_query = $self->query) =~ s/\s+/+/g;
      my $response = $browser->get( $searchUrl . $tmp_query . '&start=' . $nr );
      $content = $response->content;
  }
  
  # now we parse the HTML for entries
  my $tree = HTML::TreeBuilder::XPath->new;
  $tree->utf8_mode(1);
  $tree->parse_content($content);

  my %data = (
    authors   => [],
    titles    => [],
    citations => [],
    urls      => [],
    bibtex    => [],
    pdf       => []  
  );

  # Each entry is part of an unorder list 
  my @nodes = $tree->findnodes('/html/body/table/tr/td/table/tr[@valign="top"]/td/table');
  
  foreach my $node (@nodes) {
      
      # Title is easy
      my ( $title, $author, $citation, $pdf, $url );
      $title = $node->findvalue('./tr/td/a[@class="medium-text"]');

      # Sometime authors are linked out, sometimes not
      my @author_nodes = $node->findnodes('./tr/td/div/a');
      if ($#author_nodes > -1) {
	  my @tmp = ( );
	  foreach my $author_node (@author_nodes) {
	      push @tmp, @{$author_node->{_content}};
	  }
	  $author = join(", ",@tmp) if ($#tmp > -1);
     } else {
	  $author = $node->findvalue('./tr/td/div[@class="authors"]');
     }

      # Citation can be found easily, we add also the year
      $citation = $node->findvalue('./tr/td/div[@class="addinfo"]');
      if ($node->findvalue('./tr/td[@class="small-text"]') =~ m/.*\s(\d+)\s.*/) {
	  $citation .= " ($1)";
      }

      # Now we look for the URLs for linkout and PDFs
      my $linkout = $node->findvalue('./tr/td/a[@class="medium-text"]/@href');
      $url = 'http://portal.acm.org/'.$linkout;
      my $pdf = $node->findvalue('./tr/td/table/tr/td/table/tr/td/a[@title="Pdf"]/@href');
      $pdf = 'http://portal.acm.org/'.$pdf if ($pdf ne '');
 
      push @{ $data{titles} }, $title;
      push @{ $data{authors} }, $author;
      push @{ $data{citations} }, $citation;
      push @{ $data{pdf} }, $pdf;
      push @{ $data{urls} }, $url;
  }


  # Write output list of Publication records with preliminary
  # information. We save to the helper fields _authors_display and
  # _citation_display which will be displayed in the front end.
  my $page = [];

  foreach my $i ( 0 .. @{ $data{titles} } - 1 ) {
    my $pub = Paperpile::Library::Publication->new();
    $pub->title( $data{titles}->[$i] );
    $pub->_authors_display( $data{authors}->[$i] );
    $pub->_citation_display( $data{citations}->[$i] );
    $pub->linkout( $data{urls}->[$i] );
    $pub->pdf_url( $data{pdf}->[$i] );
    $pub->_details_link( $data{urls}->[$i] );
    $pub->refresh_fields;
    push @$page, $pub;
  }

  # we should always call this function to make the results available
  # afterwards via find_sha1
  $self->_save_page_to_hash($page);

  return $page;

}

# We parse ACM Portal in a two step process. First we scrape off what
# we see and display it unchanged in the front end via
# _authors_display and _citation_display. If the user clicks on an
# entry the missing information is completed from the details page
# where we find the abstract and a BibTeX link. This ensures fast
# search results and avoids too many requests to ACM which is
# potentially harmful.

sub complete_details {

  ( my $self, my $pub ) = @_;

  my $browser = Paperpile::Utils->get_browser;

  # Get the BibTeX
  my $response = $browser->get( $pub->_details_link );
  my $content = $response->content;

  # now we parse the HTML for entries
  my $tree = HTML::TreeBuilder::XPath->new;
  $tree->utf8_mode(1);
  $tree->parse_content($content);

  # finding the abstract is a little bit wired, there seem to be 
  # several ways the page is made up
  my @putative_abstract_nodes = $tree->findnodes('/html/body/div/table/tr/td/div[@class="abstract"]/p');
  my $abstract = '';
  foreach my $node (@putative_abstract_nodes) {
      my $text = $node->as_text();
      next if ($text eq '');
      next if ($text =~ m/^Note:\sOCR\serrors/);
      $abstract = $text;
  }

  # Now we have to find the BibTex link
  my @nodes = $tree->findnodes('/html/body/div/table/tr/td/table/tr/td/table/tr/td/div/a[@class="small-link-text"]');
  (my $bibtex_url = $nodes[1]->attr('onclick')) =~ s/(.*open\(')(.*)(','Bi.*)/$2/;
  $bibtex_url = 'http://portal.acm.org/'.$bibtex_url;
  
  # Create a new Publication object and import the information from the BibTeX string
  $response = $browser->get( $bibtex_url );
  my $bibtex = $response->content;
  my $full_pub = Paperpile::Library::Publication->new();
  $full_pub->import_string( $bibtex, 'BIBTEX' );

  # Add the linkout and PDF url from the old object because it is not in the BibTeX
  # and thus not in the new object
  $full_pub->abstract ($abstract);
  $full_pub->linkout( $pub->linkout );
  $full_pub->pdf_url( $pub->pdf_url );

  # We don't use ACM key
  $full_pub->citekey('');

  # Note that if we change title, authors, and citation also the sha1
  # will change. We have to take care of this.
  my $old_sha1 = $pub->sha1;
  my $new_sha1 = $full_pub->sha1;
  delete( $self->_hash->{$old_sha1} );
  $self->_hash->{$new_sha1} = $full_pub;

  return $full_pub;

}

1;
