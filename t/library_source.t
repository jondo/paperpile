use strict;
use warnings;
use Data::Dumper;

use Test::More 'no_plan';

use lib "../lib";

BEGIN { use_ok 'PaperPile::Library::Source::File' }


# test1.ris contains 67 entries
my $source=PaperPile::Library::Source::File->new(file=>'data/test1.ris');

$source->connect;

# test1.ris contains 67 entries
my $counter=0;
while (my $pub = $source->next){
  $counter++;
}

is ($counter,67,'Loading entries via next');
is ($source->total_entries,67,'Setting variable total_entries');
