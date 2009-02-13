package PaperPile::Library::Source::PubMed;

use Carp;
use Data::Page;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;
use XML::Simple;
use 5.010;

use PaperPile::Library::Publication;
use PaperPile::Library::Author;
use PaperPile::Library::Journal;
use PaperPile::Utils;

extends 'PaperPile::Library::Source';

has 'query'     => ( is => 'rw' );
has 'web_env'   => ( is => 'rw' );
has 'query_key' => ( is => 'rw' );

my $esearch =
"http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=PubMed&usehistory=y&retmax=1&term=";
my $efetch =
"http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?retmode=xml&db=PubMed";
my $elink_linkout =
"http://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?retmode=ref&cmd=prlinks&db=PubMed&";
my $elink_related =
"http://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?dbfrom=pubmed&db=pubmed&id=";
my $espell =
  "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/espell.fcgi?&db=PubMed&term=";
my $epost =
  "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/epost.fcgi?db=pubmed&id=";

sub connect {
  my $self = shift;

  my $browser=PaperPile::Utils->get_browser;

  my $response  = $browser->get( $esearch . $self->query );
  my $resultXML = $response->content;

  print STDERR Dumper($resultXML);

  my $result    = XMLin($resultXML);

  $self->web_env( $result->{WebEnv} );
  $self->query_key( $result->{QueryKey} );
  $self->total_entries( $result->{Count} );

  return $self->total_entries;
}

sub page {
  ( my $self, my $offset, my $limit ) = @_;

  my $xml = $self->_pubFetch( $offset, $limit );

  my $page = $self->_read_xml($xml);

  $self->_linkOut($page);

  $self->_save_page_to_hash($page);

  return $page;

}


sub _linkOut {

  ( my $self, my $pubs) = @_;

  my %pub_hash=();

  my @ids=();
  foreach my $pub (@$pubs){
    push @ids, $pub->{pmid};
    $pub_hash{$pub->{pmid}}=$pub;
  }

  my $ids=join(',',@ids);

  my $browser= PaperPile::Utils->get_browser;

  my $url = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?retmode=xml&cmd=prlinks&db=PubMed&id=$ids";

  my $response  = $browser->get($url);

  print STDERR Dumper($url, "   " ,$response->content);

  my $result = XMLin( $response->content);

  #print STDERR Dumper($result->{LinkSet}->{IdUrlList}->{IdUrlSet});

  #print STDERR $result->{LinkSet}->{IdUrlList}->{IdUrlSet};

  foreach my $entry (@{$result->{LinkSet}->{IdUrlList}->{IdUrlSet}}){

    my $id=$entry->{Id};

    # got an error message
    if (defined $entry->{Info}){
      $pub_hash{$id}->url('');
    } else {
      $pub_hash{$id}->url($entry->{ObjUrl}->{Url});
      # Adjust the url otherwise it won't get displayed correctly
      my $icon_url=$entry->{ObjUrl}->{IconUrl};
      $icon_url=~s/entrez/corehtml/;
      $pub_hash{$id}->icon($icon_url);
    }
  }


}


sub _pubFetch {

  ( my $self, my $offset, my $limit ) = @_;

  my $browser= PaperPile::Utils->get_browser;
  my $query_key = $self->query_key;
  my $web_env   = $self->web_env;

  my $url =
"$efetch&query_key=$query_key&WebEnv=$web_env&retstart=$offset&retmax=$limit";
  my $response  = $browser->get($url);
  my $resultXML = $response->content;

  return $resultXML;

}

sub _read_xml {

  ( my $self, my $xml ) = @_;

  my $result = XMLin( $xml, keyattr => ['IdType'], SuppressEmpty => 1 );

  my @output = ();

  my @list;

  if ( ref( $result->{PubmedArticle} ) eq 'ARRAY' ) {
    @list = @{ $result->{PubmedArticle} };
  }
  else {
    @list = ( $result->{PubmedArticle} );
  }

  foreach my $article (@list) {

    my $cit = $article->{MedlineCitation};

    my $pub = PaperPile::Library::Publication->new(pubtype=>'JOUR');

    if (not $pub->pmid( $cit->{PMID})){
      die();
    }

    $pub->pmid( $cit->{PMID} );

    my $volume = $cit->{Article}->{Journal}->{JournalIssue}->{Volume};
    my $issue  = $cit->{Article}->{Journal}->{JournalIssue}->{Issue};
    my $year   = $cit->{Article}->{Journal}->{JournalIssue}->{PubDate}->{Year};
    my $month  = $cit->{Article}->{Journal}->{JournalIssue}->{PubDate}->{Month};
    my $pages  = $cit->{Article}->{Pagination}->{MedlinePgn};
    my $abstract = $cit->{Article}->{Abstract}->{AbstractText};
    my $title    = $cit->{Article}->{ArticleTitle};
    my $status   = $article->{PubmedData}->{PublicationStatus};
    my $journal  = $cit->{MedlineJournalInfo}->{MedlineTA};


    my $doi =
      $article->{PubmedData}->{ArticleIdList}->{ArticleId}->{doi}->{content};

    $pub->volume($volume)     if $volume;
    $pub->issue($issue)       if $issue;
    $pub->year($year)         if $year;
    $pub->month($month)       if $month;
    $pub->pages($pages)       if $pages;
    $pub->abstract($abstract) if $abstract;
    $pub->title($title)       if $title;
    $pub->doi($doi)           if $doi;

    if ($journal) {
      my $jid=$journal;
      $pub->journal($journal),
    }

    my @authors = ();
    my @tmp     = ();
    if ( ref( $cit->{Article}->{AuthorList}->{Author} ) eq 'ARRAY' ) {
      @tmp = @{ $cit->{Article}->{AuthorList}->{Author} };
    } else {
      @tmp = ( $cit->{Article}->{AuthorList}->{Author} );
    }

    foreach my $author (@tmp) {

      if ($author->{CollectiveName}){
        push @authors, PaperPile::Library::Author->new(
                                                       last =>  '{'.$author->{CollectiveName}.'}',
                                                       first  => '',
                                                       jr    => '',
                                                      )->normalized;
      } else {
        push @authors, PaperPile::Library::Author->new(
                                                       last => $author->{LastName} ? $author->{LastName} : '',
                                                       first  => $author->{Initials} ? $author->{Initials} : '',
                                                       jr    => $author->{Suffix}   ? $author->{Suffix}   : '',
                                                      )->normalized;
      }

      }
    $pub->authors( join(' and ',@authors) );
    push @output, $pub;
  }
  return [@output];
}

1;
