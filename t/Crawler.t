use lib "../lib";
use Test::More 'no_plan';
use Data::Dumper;

BEGIN { use_ok 'PaperPile::Crawler' }

my $crawler=PaperPile::Crawler->new;

$crawler->debug(1);

$crawler->driver_file('data/driver.xml');
$crawler->load_driver();

my $tests=$crawler->get_tests;

#$tests={manual=>['http://dx.doi.org/10.1186/1471-2105-9-248']};

foreach my $site (keys %$tests){
  foreach my $test (@{$tests->{$site}}){
    my $file=$crawler->search_file($test);
    isnt ($file, undef, "$site: getting pdf-url for $test");
  SKIP: {
      skip "No valid url found, not downloading PDF" if not defined $file;
      is($crawler->fetch_pdf($file, 'downloaded.pdf'),1,"$site: downloading PDF");
    }
  }
}

#print Dumper($crawler->_driver);
#my $file=$crawler->search_file($test4);
#$crawler->fetch_pdf($file, 'downloaded.pdf');
#print "$file\n";

