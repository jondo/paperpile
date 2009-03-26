use strict;
use warnings;
use Data::Dumper;
use Test::More 'no_plan';
use lib "../../../lib";

BEGIN { use_ok 'Paperpile::Plugins::Import::GoogleScholar' }

binmode STDOUT, ":utf8"; # avoid unicode errors when printing to STDOUT

my $source=Paperpile::Plugins::Import::GoogleScholar->new(query=>'Washietl');

$source->limit(10);
$source->connect;

$source->page(0,10);

#my $pubs=$source->page_from_offset(0,10);
#print Dumper($pubs);





