#!/Users/wash/play/paperpile/catalyst/perl5/osx/bin/paperperl -w

use strict;
use Data::Dumper;
use lib '../../lib';

use Paperpile;
use Paperpile::Utils;


my $browser = Paperpile::Utils->get_browser();

my $result = $browser->get("https://encrypted.google.com/");

print STDERR Dumper($result);


#use Paperpile::Migrate;

#use Paperpile::Plugins::Import;
#use Paperpile::Plugins::Import::Duplicates;
#use Text::LevenshteinXS qw(distance);
#my $plugin = Paperpile::Plugins::Import::Duplicates->new(file=>'/home/wash/.paperdev/paperpile.ppl');
#$plugin->connect();
#my $distance = distance('CONSERVEDRNASECONDARYSTRUCTURESINPICORNAVIRIDAEGENOMES','CONSERVEDRNASECONDARYSTRUCTURESINFLAVIVIRIDAEGENOMES');
#print "$distance\n";

#my $mg = Paperpile::Migrate->new();

#`cp /home/wash/tmp/paperpile/data-0.4.3/paperpile.ppl .`;

#$mg->app_library_version( 3 );
#$mg->library_db( '/home/wash/play/paperpile/catalyst/t/profile/paperpile.ppl' );
#$mg->migrate('library');

