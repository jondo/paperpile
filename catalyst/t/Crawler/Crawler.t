use lib "../../lib";
use Test::More 'no_plan';
use strict;
use Data::Dumper;

BEGIN { use_ok 'Paperpile::Crawler' }

my $crawler=Paperpile::Crawler->new;

$crawler->debug(0);
#$crawler->driver_file('../data/short.xml');
$crawler->driver_file('../data/driver.xml');
$crawler->load_driver();

my $tests=$crawler->get_tests;

#$tests={manual=>['http://www.indianjcancer.com/article.asp?issn=0019-509X;year=2007;volume=44;issue=1;spage=36;epage=37;aulast=Agrawal']};

foreach my $site (keys %$tests){
  my $test_no=1;
  foreach my $test (@{$tests->{$site}}){
    my $file=$crawler->search_file($test);
    ok ($file, "$site: getting pdf-url for $test");
  SKIP: {
      skip "No valid url found, not downloading PDF" if not defined $file;
      #is($crawler->fetch_pdf($file, "downloads/$site\_test$test_no.pdf"),1,"$site: downloading PDF");
      is($crawler->check_pdf($file),1,"$site: checking if PDF");
    }
    $test_no++;
  }
  #last;
}

#print Dumper($crawler->_driver);
#my $file=$crawler->search_file($test4);
#$crawler->fetch_pdf($file, 'downloaded.pdf');
#print "$file\n";

