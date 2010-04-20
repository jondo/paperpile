### Run with ./perl.pl wrapper!

# Copyright 2009, 2010 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.  You should have received a
# copy of the GNU General Public License along with Paperpile.  If
# not, see http://www.gnu.org/licenses.


BEGIN {
  $ENV{CATALYST_DEBUG} = 0;
}

use strict;

use FindBin;
use lib "$FindBin::Bin/../catalyst/lib";

use Paperpile;
use Paperpile::Build;

if ( $#ARGV != 0 ) {
  print 'Usage: ./perl.pl build.pl [command]', "\n";
  print 'Commands: dist, initdb, minify, dump_includes, get_titanium', "\n";
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

if ( $command eq 'get_titanium' ) {
  $b->get_titanium;
}


if ( $command eq 'dist' ) {
  $b->make_dist('linux64');
  $b->make_dist('linux32');
  $b->make_dist('osx');
}

if ( $command eq 'minify' ) {
  $b->minify;
}

if ( $command eq 'dump_includes' ) {
  $b->dump_includes;
}
