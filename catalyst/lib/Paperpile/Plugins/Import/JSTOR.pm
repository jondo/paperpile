package Paperpile::Plugins::Import::JSTOR;

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

# The search query to be send to JSTOR
has 'query' => ( is => 'rw' );

# The main search URL
my $searchUrl = 'http://www.jstor.org/action/doBasicSearch?dc=All+Disciplines&Query=';


sub BUILD {
  my $self = shift;
  $self->plugin_name('JSTOR');
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
  if ( $content =~ /No Items Matched Your Search/ ) {
    $self->total_entries(0);
    return 0;
  }

  # We parse the HTML via XPath
  my $tree = HTML::TreeBuilder::XPath->new;
  $tree->utf8_mode(1);
  $tree->parse_content($content);

  # Try to find the number of hits
  my $stats = $tree->findnodes(q{/html/body/div/div/div/div/form/div/p[@id='resultsBlock']});
  if ( $stats =~ /Results.*of\s(\d+)\sfor/ ) {
    my $number = $1;
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
    my $searchUrl_new = 'http://www.jstor.org/action/doBasicResults?hp=25&la=&wc=on&gw=jtx&jcpsi=1&artsi=1&Query='.$tmp_query.'&si='.$nr.'&jtxsi='.$nr;
    my $response = $browser->get( $searchUrl_new );
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
  
  my @nodes = $tree->findnodes('/html/body/div/div/div/div/form/fieldset/ul/li');
  
  foreach my $node (@nodes) {

    my ( $title, $author, $citation, $bibtex, $pdf, $url );
    $title = $node->findvalue('./ul/li/a[@class="title"]');
    $author = $node->findvalue('./ul/li/a[@class="author"]');
    $citation = $node->findvalue('./ul/li[@class="sourceInfo"]');
    $bibtex = $node->findvalue('./ul/li/span/a[@class="exportArticle"]/@href');
    $bibtex =~ s/exportSingleCitation\?/downloadSingleCitation?format=bibtex&include=abs&/;
    $bibtex = 'http://www.jstor.org'.$bibtex;
    (my $suffix = $bibtex) =~ s/(.*suffix=)//;
    $pdf = 'http://www.jstor.org/stable/pdfplus/'.$suffix.'.pdf';
    $url = 'http://www.jstor.org/stable/'.$suffix;
    push @{ $data{titles} }, $title;
    push @{ $data{authors} },   $author;
    push @{ $data{citations} },   $citation;
    push @{ $data{bibtex} }, $bibtex;
    push @{ $data{pdf} }, $pdf;
    push @{ $data{urls} }, $url;
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
    $pub->pdf_url( $data{pdf}->[$i] );
    $pub->_details_link( $data{bibtex}->[$i] );
    $pub->refresh_fields;
    push @$page, $pub;
  }

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

  # Get the BibTeX
  my $bibtex = $browser->get( $pub->_details_link );
  $bibtex = $bibtex->content;

  # Create a new Publication object and import the information from the BibTeX string
  my $full_pub = Paperpile::Library::Publication->new();
  $full_pub->import_string( $bibtex, 'BIBTEX' );

  # Add the linkout from the old object because it is not in the BibTeX
  #and thus not in the new object

  $full_pub->linkout( $pub->linkout );
  $full_pub->pdf_url( $pub->pdf_url );

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

1;
