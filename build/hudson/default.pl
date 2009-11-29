#! catalyst/perl5/linux32/bin/perl -w

# Our build machine is 32 bit and Hudson runs this script from the top
# level in the workspace. So we need the above perl binary.

use strict;

use FindBin;
use lib "$FindBin::Bin/../../catalyst/lib";

use Paperpile::Build;

my $b = Paperpile::Build->new( {
    cat_dir  => 'catalyst',
    ti_dir   => "titanium",
    dist_dir => 'dist/data',
    yui_jar  => $ENV{HOME} . '/bin/yuicompressor-2.4.2.jar',
  }
);

Paperpile::Build->echo("Minifying javascript");
$b->minify;

Paperpile::Build->echo("Making distribution linux64");
$b->make_dist('linux64');

Paperpile::Build->echo("Making distribution linux32");
$b->make_dist('linux32');

exit(0);
