### Run with ./perl.pl wrapper!

use strict;

use FindBin;
use lib "$FindBin::Bin/../catalyst/lib";

use Paperpile::Build;

if ( $#ARGV != 0 ) {
  print 'Usage: ./perl.pl build.pl [command]', "\n";
  print 'Commands: dist, initdb, minify',      "\n";
  exit(1);
}

my $command = $ARGV[0];

my $b = Paperpile::Build->new( {
    cat_dir  => '../catalyst',
    ti_dir   => "../titanium",
    dist_dir => '../dist/data',
    yui_jar => '/home/wash/bin/yuicompressor-2.4.2.jar',
  }
);

if ( $command eq 'initdb' ) {
  $b->initdb;
}


if ( $command eq 'dist' ) {
  $b->make_dist('linux64');
  #$b->make_dist('linux32');
}

if ( $command eq 'minify' ) {
  $b->minify;
}

