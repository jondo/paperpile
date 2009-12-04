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

my ( $day, $month, $year ) = (localtime)[ 3, 4, 5 ];

$month+=1;
$year+=1900;

my $tag = sprintf("%02d-%02d-%04d", $month, $day, $year);

Paperpile::Build->echo("Minifying javascript");
$b->minify;

Paperpile::Build->echo("Making distribution linux64");
$b->make_dist('linux64', $ENV{BUILD_NUMBER});

Paperpile::Build->echo("Making distribution linux32");
$b->make_dist('linux32', $ENV{BUILD_NUMBER});


chdir "dist/data";
`rm ../*tar.gz`;
for my $platform ('linux32','linux64'){
   Paperpile::Build->echo("Packaging $platform");
  `mv $platform paperpile`;
  `tar czf ../paperpile-$tag-$platform.tar.gz paperpile`;
  `mv paperpile $platform`;
}

chdir "../..";



Paperpile::Build->echo("Deploy catalyst app to /scratch/catalyst/nightly");
`rm -rf /scratch/catalyst/nightly/*`;
`cp -r dist/data/linux32/catalyst/* /scratch/catalyst/nightly`;
`mkdir /scratch/catalyst/nightly/log`;

Paperpile::Build->echo("Starting instance via FastCGI");
system("~/bin/catalyst_nightly.sh restart");

exit($? >> 8);
