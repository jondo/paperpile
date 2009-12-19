use lib "../../lib";
use Test::More 'no_plan';
use strict;
use Data::Dumper;
use Paperpile::Library::Publication;

BEGIN {
  use_ok 'Paperpile::Crawler';
}

my $crawler = Paperpile::Crawler->new;

# Show debug output
$crawler->debug(1);

# Load standard crawler file
$crawler->driver_file('../../data/pdf-crawler.xml');
$crawler->load_driver();

# This is the list of all tests
my $tests = $crawler->get_tests;

# For testing individual sites you can override the tests array and
# put in your own test-cases

#$tests = { manual => ['http://www.nature.com/doifinder/10.1038/ng1108-1262'] };

foreach my $site ( keys %$tests ) {
  my $test_no = 1;
  foreach my $test ( @{ $tests->{$site} } ) {
    my $file;
    eval { $file = $crawler->search_file($test) };
    print STDERR $@ if ($@);
    ok( $file, "$site: getting pdf-url for $test" );
  SKIP: {
      skip "No valid url found, not downloading PDF" if not defined $file;

      # Either download PDF or just check first few bytes for correct PDF header
      #is($crawler->fetch_pdf($file, "downloads/$site\_test$test_no.pdf"),1,"$site: downloading PDF");
      is( $crawler->check_pdf($file), 1, "$site: checking if PDF" );
    }
    $test_no++;
  }
}

