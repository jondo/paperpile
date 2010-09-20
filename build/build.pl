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
use Paperpile::Utils;


if (! ($#ARGV == 0 || $#ARGV == 1)  ) {
  usage();
  exit(1);
}

my $command = $ARGV[0];

my $platform = '';

if ($ARGV[1]){
  $platform = $ARGV[1];
  if (($platform ne 'osx') && ($platform ne 'linux32') && ($platform ne 'linux64')){
    usage();
  }
}

my $b = Paperpile::Build->new( {
    cat_dir  => '../catalyst',
    qt_dir   => "../qt",
    dist_dir => '../dist/data',
    yui_jar => $ENV{HOME}.'/bin/yuicompressor-2.4.2.jar',
  }
);

if ( $command eq 'initdb' ) {
  $b->initdb;
  exit(0);
}

if ( $command eq 'get_qruntime' ) {
  $b->get_qruntime($platform);
  exit(0);
}


if ( $command eq 'dist' ) {

  if ($platform eq 'all'){
    $b->make_dist('linux64');
    $b->make_dist('linux32');
    $b->make_dist('osx');
  }

  if ($platform){
    $b->make_dist($platform);
  } else {
    $b->make_dist(Paperpile::Utils->get_platform);
  }

  exit(0);
}

if ( $command eq 'minify' ) {
  $b->minify;
  exit(0);
}

if ( $command eq 'dump_includes' ) {
  $b->dump_includes;
  exit(0);
}

if ( $command eq 'push_qruntime' ) {
  $b->push_qruntime;
  exit(0);
}

usage();



sub usage{

  print <<END;

  Usage: ./perl.pl build.pl [command] <platform>

  Commands:

  dist           Create distribution package
  initdb         Initialize database
  minify         Concatenate/minify Javascript and CSS
  dump_includes  Print include statemts for all js/css files
  get_qruntime   Download Qt Runtime library files
  push_qruntime  Publish Qt Runtime library files to server

  Platforms (optional): osx, linux32, linux64


END

}
