use strict;
use warnings;
use Data::Dumper;

use Test::More 'no_plan';

use lib "../lib";

use PaperPile::Library;

BEGIN { use_ok 'PaperPile::PDFviewer' }

my $pv = PaperPile::PDFviewer->new(
  file          => 'data/nature.pdf',
  canvas_width  => 800,
  canvas_height => 100
);
$pv->init;

print $pv->render_page( 1, 1.0 );



#$pv->destroy;

