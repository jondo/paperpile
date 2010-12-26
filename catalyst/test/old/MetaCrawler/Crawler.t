BEGIN {
  $ENV{CATALYST_DEBUG}=0;
}

use lib "../../lib";
use Test::More 'no_plan';
use strict;
use Data::Dumper;
use Paperpile;
use Paperpile::Library::Publication;
use Paperpile::MetaCrawler;

my $crawler = Paperpile::MetaCrawler->new;

# Show debug output
$crawler->debug(1);

# Load crawler file
$crawler->driver_file('../../data/meta-crawler.xml');
$crawler->load_driver();

# This is the list of all tests
my $tests = $crawler->get_tests;

#my $tests = { manual => ['http://www.biomedcentral.com/1471-2105/9/248'] };

foreach my $site ( keys %$tests ) {
  my $test_no = 1;
  foreach my $test ( @{ $tests->{$site} } ) {
    my $pub = undef;
    my $url = $test->{url};
    eval { $pub = $crawler->search_file($url) };
    print STDERR $@ if ($@);
    ok( $pub, "$site test $test_no: getting data for $url" );
  SKIP: {
      skip "No bibliographic data found, skipping more tests for $site test $test_no" if not defined $pub;
      foreach my $key (keys %$test){
        next if $key eq 'url';
        is( $pub->$key, $test->{$key}, "$site test $test_no: $key" );
      }
    }
    $test_no++;
  }
}

