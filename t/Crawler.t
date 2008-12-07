use lib "../lib";
use Test::More 'no_plan';
use Data::Dumper;

BEGIN { use_ok 'PaperPile::Crawler' }

my $test1='http://www.plosgenetics.org/article/info%3Adoi%2F10.1371%2Fjournal.pgen.0030079';
my $test2='http://www.biomedcentral.com/1471-2105/9/248';
my $test3='http://dx.doi.org/10.1186/1471-2105-9-248';

my $crawler=PaperPile::Crawler->new;


$crawler->driver_file('data/driver.xml');
$crawler->load_driver();

#print Dumper($crawler->_driver);

$crawler->search_file($test2);


