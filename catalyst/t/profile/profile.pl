#!/home/wash/play/paperpile/catalyst/perl5/linux64/bin/perl -d:NYTProf -w
##!/home/wash/play/paperpile/catalyst/perl5/linux64/bin/perl -w


BEGIN {
  $ENV{CATALYST_DEBUG} = 0;
}

use strict;
use Data::Dumper;
use lib '../../lib';

use Paperpile;
use Paperpile::Formats;

use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);

`cp /home/wash/.paperdev/paperpile.ppl ./test.ppl`;

my $model = Paperpile::Model::Library->new();
$model->set_dsn( "dbi:SQLite:" . "test.ppl" );


my $file = '/home/wash/jabref.bib';

my $t0 = [gettimeofday];

my $module = Paperpile::Formats->guess_format( $file );

my $f = $module->new( file => $file );

my $data = $f->read();

my $elapsed = tv_interval ($t0);

print "Done reading. $elapsed\n";

my $t1 = [gettimeofday];

$model->insert_pubs( $data, 1);

my $elapsed = tv_interval ($t1);

print "Done importing. $elapsed\n";


