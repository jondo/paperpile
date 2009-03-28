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

has 'query'           => ( is => 'rw' );
has '_session_cookie' => ( is => 'rw' );

my $settingsUrl =
  'http://scholar.google.com/scholar_setprefs?output=search&inststart=0&hl=en&lang=all&instq=&submit=Save+Preferences&scis=yes';
my $searchUrl = 'http://scholar.google.com/scholar?hl=en&lr=&btnG=Search&q=';

sub connect {
  my $self = shift;

  # First set preferences (necessary to show BibTeX export links)
  # We simulate submitting the form which sets a cookie. We save
  # the cookie for this session.

  my $browser = Paperpile::Utils->get_browser;
  $settingsUrl .= 'num=10&scisf=4';
  $browser->get($settingsUrl);

  $self->_session_cookie( $browser->cookie_jar );

  #print STDERR Dumper($self->_session_cookie);

  # Then start query and parse number of hits; save first page in
  # cache to speed up call to first page afterwards

  $browser = Paperpile::Utils->get_browser;
  $browser->cookie_jar( $self->_session_cookie );

  my $response = $browser->get( $searchUrl . $self->query );
  my $content  = $response->content;

  $self->_page_cache( {} );

  $self->_page_cache->{0}->{ $self->limit } = $content;

  if ( $content =~ /No pages were found containing/ ) {
    $self->total_entries(0);
    return 0;
  }

  my $tree = HTML::TreeBuilder::XPath->new;
  $tree->utf8_mode(1);

  $tree->parse_content($content);

  my $stats = $tree->findnodes(q{//td[@align="right"]/font[@size='-1']});

  if ( $stats =~ /Results \d+ - \d+ of\s*(about)?\s*([0123456789,]+) for/ ) {
    my $number = $2;
    $number =~ s/,//g;
    $number = 1000 if ( $number > 1000 );    # Google does not provide more than 1000 results
    $self->total_entries($number);
  } else {
    croak('Something is wrong with the results page.');
  }

  return $self->total_entries;
}



sub page {
  ( my $self, my $offset, my $limit ) = @_;

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

  # Write output list of Publication records with preliminary information
  my $page = [];

  foreach my $i ( 0 .. @{ $data{titles} } - 1 ) {
    my $pub = Paperpile::Library::Publication->new();
    $pub->title( $data{titles}->[$i] );
    $pub->_authors_display( $data{authors}->[$i] );
    $pub->_citation_display( $data{citations}->[$i] );
    $pub->url( $data{urls}->[$i] );
    $pub->_details_link( $data{bibtex}->[$i] );
    $pub->refresh_fields;
    push @$page, $pub;
  }

  $self->_save_page_to_hash($page);

  return $page;

}


sub complete_details {

  ( my $self, my $pub ) = @_;

  my $browser = Paperpile::Utils->get_browser;
  $browser->cookie_jar( $self->_session_cookie );

  my $old_sha1=$pub->sha1;

  my $bibtex=$browser->get($pub->_details_link);

  $bibtex=$bibtex->content;

  my $full_pub = Paperpile::Library::Publication->new();
  $full_pub->import_string($bibtex,'BIBTEX');

  $full_pub->url($pub->url);

  my $new_sha1=$full_pub->sha1;

  delete($self->_hash->{ $old_sha1 });

  $self->_hash->{ $new_sha1 } = $full_pub;

  return $full_pub;

}






1;
