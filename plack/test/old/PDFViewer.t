use strict;
use warnings;
use Data::Dumper;

use Test::More 'no_plan';

use lib "../lib";

use Paperpile::Library;

BEGIN { use_ok 'Paperpile::PDFviewer' }

my $pv = Paperpile::PDFviewer->new(
  file          => 'data/nature.pdf',
  canvas_width  => 800,
  canvas_height => 100
);
$pv->init;

print $pv->render_page( 1, 1.0 );



#$pv->destroy;

