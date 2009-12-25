#!/usr/bin/perl -w

BEGIN{
  $ENV{CATALYST_DEBUG}=0;
}

use strict;
use File::Find;
use File::Copy::Recursive qw(fcopy rcopy dircopy);
use Data::Dumper;

use lib "../lib/";

use Paperpile;
use Paperpile::Build;

my $builder = Paperpile::Build->new();

`mkdir /home/wash/tmp/updates/patch-2_to_3-linux64`;
$builder->create_patch( '/home/wash/tmp/updates/paperpile-0.2-linux64',
                        '/home/wash/tmp/updates/paperpile-0.3-linux64',
                        '/home/wash/tmp/updates/patch-2_to_3-linux64',
                      );
