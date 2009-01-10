package PaperPile::Library::Source::PubMed;

use Carp;
use Data::Page;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;
use PaperPile::Library;
use PaperPile::Utils;
use XML::Simple;
use 5.010;

extends 'PaperPile::Library::Source';

has 'query'     => ( is => 'rw' );
has 'web_env'   => ( is => 'rw' );
has 'query_key' => ( is => 'rw' );
has '_browser'  => ( is => 'rw', isa => 'LWP::UserAgent' );

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

  $self->_browser( PaperPile::Utils->get_browser );

  my $response  = $self->_browser->get( $esearch . $self->query );
  my $resultXML = $response->content;
  my $result    = XMLin($resultXML);

  $self->web_env( $result->{WebEnv} );
  $self->query_key( $result->{QueryKey} );
  $self->total_entries( $result->{Count} );

  $self->_pager( Data::Page->new() );
  $self->_pager->total_entries( $self->total_entries );
  $self->_pager->entries_per_page( $self->entries_per_page );
  $self->_pager->current_page(1);

  return $self->total_entries;
}

sub page_from_offset {
  ( my $self, my $offset, my $limit ) = @_;

  my $xml = $self->_pubFetch( $offset, $limit );

  my $page = $self->_read_xml($xml);

  $self->_save_page_to_hash($page);

  return $page;

}

sub _pubFetch {

  ( my $self, my $offset, my $limit ) = @_;

  my $query_key = $self->query_key;
  my $web_env   = $self->web_env;

  my $url =
"$efetch&query_key=$query_key&WebEnv=$web_env&retstart=$offset&retmax=$limit";
  my $response  = $self->_browser->get($url);
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

    my $pub = PaperPile::Library::Publication->new();

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
      $pub->journal(
        PaperPile::Library::Journal->new(
          id    => $journal,
          short => $journal,
          name  => $journal,
        )
      );
    }

    my @authors = ();
    my @tmp     = ();
    if ( ref( $cit->{Article}->{AuthorList}->{Author} ) eq 'ARRAY' ) {
      @tmp = @{ $cit->{Article}->{AuthorList}->{Author} };
    } else {
      @tmp = ( $cit->{Article}->{AuthorList}->{Author} );
    }

    foreach my $author (@tmp) {
      push @authors, PaperPile::Library::Author->new(
        last_name => $author->{LastName} ? $author->{LastName} : '',
        initials  => $author->{Initials} ? $author->{Initials} : '',
        suffix    => $author->{Suffix}   ? $author->{Suffix}   : '',
        #collectiveName=>$author->{CollectiveName},
      );
    }

    $pub->authors( [@authors] );
    push @output, $pub;
  }
  return [@output];
}

1;
