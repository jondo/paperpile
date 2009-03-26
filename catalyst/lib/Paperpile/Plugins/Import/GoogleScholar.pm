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

has 'query'  => ( is => 'rw' );

my $searchUrl='http://scholar.google.com/scholar?hl=en&lr=&btnG=Search&q=';

sub connect {
  my $self = shift;

  my $browser = Paperpile::Utils->get_browser;
  my $response  = $browser->get( $searchUrl . $self->query );
  my $content = $response->content;

  $self->_page_cache({});

  $self->_page_cache->{0}->{$self->limit}=$content;

  if ($content=~/No pages were found containing/){
    $self->total_entries(0);
    return 0;
  }

  my $tree = HTML::TreeBuilder::XPath->new;
  $tree->parse_content( $content);

  my $stats=$tree->findnodes(q{//td[@align="right"]/font[@size='-1']});

  if ($stats=~/Results \d+ - \d+ of about (\d+) for/){
    $self->total_entries($1);
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
    my $browser  = Paperpile::Utils->get_browser;
    my $response = $browser->get( $searchUrl . $self->query . "&start=$offset" );
    $content = $response->content;
  }

  my $tree = HTML::TreeBuilder::XPath->new;
  $tree->parse_content($content);

  my %data = (
    authors   => [],
    titles    => [],
    citations => [],
    urls      => [],
  );

  my @nodes = $tree->findnodes('//h3');

  foreach my $node (@nodes) {
    my $title = $node->findvalue('./a');
    my $url   = $node->findvalue('./a/@href');
    push @{ $data{titles} }, $title;
    push @{ $data{urls} }, $url;
  }

  @nodes = $tree->findnodes(q{//font[@size='-1']});

  foreach my $node (@nodes) {

    my $line = $node->findvalue(q{./span[@class='a']});

    next if not $line;

    my ($authors, $citation, $publisher)=split(/ - /,$line);

    push @{ $data{authors} }, $authors;
    push @{ $data{citations} }, $citation;
  }

  my $page=[];

  foreach my $i (0.. @{$data{titles}}-1){

    my $pub = Paperpile::Library::Publication->new();

    $pub->title($data{titles}->[$i]);
    $pub->_authors_display($data{authors}->[$i]);
    $pub->_citation_display($data{citations}->[$i]);
    $pub->url($data{urls}->[$i]);

    push @$page, $pub;

  }

  print Dumper($page);

  #$self->_save_page_to_hash($page);
  #return $page;

}


1;
