package Paperpile::Plugins::Import::GoogleScholar;

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

# The search query to be send to GoogleScholar
has 'query'           => ( is => 'rw' );

# We need to set a cookie to get links to BibTeX file.
has '_session_cookie' => ( is => 'rw' );

# The main search URL
my $searchUrl = 'http://scholar.google.com/scholar?hl=en&lr=&btnG=Search&q=';

# The URL with the settings form. We use it to turn on BibTeX output.
my $settingsUrl =
  'http://scholar.google.com/scholar_setprefs?output=search&inststart=0&hl=en&lang=all&instq=&submit=Save+Preferences&scis=yes';


sub connect {
  my $self = shift;

  # First set preferences (necessary to show BibTeX export links)
  # We simulate submitting the form which sets a cookie. We save
  # the cookie for this session.

  my $browser = Paperpile::Utils->get_browser;
  $settingsUrl .= 'num=10&scisf=4'; # gives us BibTeX
  $browser->get($settingsUrl);
  $self->_session_cookie( $browser->cookie_jar );

  # Then start real query
  $browser = Paperpile::Utils->get_browser; # get new browser
  $browser->cookie_jar( $self->_session_cookie ); # set the session cookie

  # Get the results
  my $response = $browser->get( $searchUrl . $self->query );
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
  my $stats = $tree->findnodes(q{//td[@align="right"]/font[@size='-1']});
  if ( $stats =~ /Results \d+ - \d+ of\s*(about)?\s*([0123456789,]+) for/ ) {
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
    my $query    = $searchUrl . $self->query . "&start=$offset";
    my $response = $browser->get($query);
    $content = $response->content;
  }

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
  );

  # Each entry has a h3 heading
  my @nodes = $tree->findnodes('//h3');

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

  @nodes = $tree->findnodes(q{//font[@size='-1']});

  foreach my $node (@nodes) {

    # Most information is contained in a <span> tag
    my $line = $node->findvalue(q{./span[@class='a']});
    next if not $line;

    my ( $authors, $citation, $publisher ) = split( / - /, $line );

    $citation .= "- $publisher" if $publisher;

    push @{ $data{authors} },   defined($authors)  ? $authors  : '';
    push @{ $data{citations} }, defined($citation) ? $citation : '';

    my @links = $node->findnodes('./a');

    # Find the BibTeX export links
    foreach my $link (@links) {
      my $url = $link->attr('href');
      next if not $url =~ /\/scholar\.bib/;
      $url = "http://scholar.google.com$url";
      push @{ $data{bibtex} }, $url;
    }
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
  $browser->cookie_jar( $self->_session_cookie );

  # Get the BibTeX
  my $bibtex = $browser->get( $pub->_details_link );
  $bibtex = $bibtex->content;

  # Create a new Publication object and import the information from the BibTeX string
  my $full_pub = Paperpile::Library::Publication->new();
  $full_pub->import_string( $bibtex, 'BIBTEX' );

  # Add the linkout from the old object because it is not in the BibTeX
  #and thus not in the new object

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
