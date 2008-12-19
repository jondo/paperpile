use lib "../lib";
use Test::More 'no_plan';
use Data::Dumper;

BEGIN { use_ok 'PaperPile::Crawler' }

my $crawler=PaperPile::Crawler->new;

$crawler->debug(1);

$crawler->driver_file('data/driver.xml');
$crawler->load_driver();

my $tests=$crawler->get_tests;

# Todo: elsevier article locater, eg: http://linkinghub.elsevier.com/retrieve/pii/S1470-2045(08)70008-1

$tests={manual=>['http://www.liebertonline.com/doi/pdf/10.1089/cmb.2006.0137']};

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

