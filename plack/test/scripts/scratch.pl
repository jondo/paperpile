#!../../perl5/linux64/bin/paperperl -w

## Add code to generate test data or ad-hoc tests here.

use strict;
use lib "../../lib";

use Paperpile::App;
use Paperpile::Library::Publication;
use Paperpile::Plugins::Import::GoogleScholar;
use Paperpile::MetaCrawler;
use Paperpile::MetaCrawler::Targets::Bibtex;

Paperpile::MetaCrawler::Targets::Bibtex->new();

my $pub =
  Paperpile::Library::Publication->new(
  title => "Strategies for measuring evolutionary conservation of RNA secondary structures" );

$pub->create_guid();

#my $plugin = Paperpile::Plugins::Import::GoogleScholar->new();
#my $matchedpub = $plugin->match($pub);

my $crawler = Paperpile::MetaCrawler->new;
$crawler->jobid("123");
$crawler->debug(0);
$crawler->driver_file( Paperpile::App->path_to( 'data', 'meta-crawler.xml' ) );
$crawler->load_driver();

my $fullpub = undef;
#eval { $fullpub = $crawler->search_file( $pub->best_link ) };

$fullpub = $crawler->search_file("http://www.biomedcentral.com/1471-2105/9/122") ;
