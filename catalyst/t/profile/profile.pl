#!/home/wash/play/paperpile/catalyst/perl5/linux64/bin/paperperl -w

##!/home/wash/play/paperpile/catalyst/perl5/linux64/bin/paperperl -d:NYTProf -w

BEGIN {
  $ENV{CATALYST_DEBUG} = 0;
}

use strict;
use Data::Dumper;
use lib '../../lib';

use Paperpile;
use Paperpile::Migrate;

#use Paperpile::Plugins::Import;
#use Paperpile::Plugins::Import::Duplicates;
#use Text::LevenshteinXS qw(distance);
#my $plugin = Paperpile::Plugins::Import::Duplicates->new(file=>'/home/wash/.paperdev/paperpile.ppl');
#$plugin->connect();
#my $distance = distance('CONSERVEDRNASECONDARYSTRUCTURESINPICORNAVIRIDAEGENOMES','CONSERVEDRNASECONDARYSTRUCTURESINFLAVIVIRIDAEGENOMES');
#print "$distance\n";

my $mg = Paperpile::Migrate->new();

`cp /home/wash/tmp/paperpile/data-0.4.3/paperpile.ppl .`;

$mg->app_library_version( 3 );
$mg->library_db( '/home/wash/play/paperpile/catalyst/t/profile/paperpile.ppl' );
$mg->migrate('library');

