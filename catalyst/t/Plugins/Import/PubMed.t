use strict;
use warnings;
use Data::Dumper;
use Test::More 'no_plan';
use lib "../lib";

BEGIN { use_ok 'Paperpile::Library::Plugins::Import::GoogleScholar' }

my $source=Paperpile::Library::Source::PubMed->new(query=>'Stadler');

$source->connect;




#my $pubs=$source->page_from_offset(0,10);
#print Dumper($pubs);





