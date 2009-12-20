#!/usr/bin/perl -w

use strict;
use File::Find;
use File::Copy::Recursive qw(fcopy dircopy);
use Data::Dumper;

use lib "../lib/";


my $builder = Paperpile::Build->new();

$builder->create_patch( '/home/wash/tmp/ViennaRNA-1.6.4', '/home/wash/tmp/ViennaRNA-1.7');

`rm -rf /home/wash/tmp/patched`;
`cp -r /home/wash/tmp/ViennaRNA-1.6.4 /home/wash/tmp/patched`;

apply_patch('/home/wash/tmp/patched', 'patch');

sub apply_patch {

  my ( $dest_dir, $patch_dir ) = @_;

  find( {
      no_chdir => 1,
      wanted   => sub {
        my $file_abs = $File::Find::name;
        my $file_rel = File::Spec->abs2rel( $file_abs, $patch_dir );
        next if $file_rel eq '__DIFF__';
        fcopy( $file_abs, "$dest_dir/$file_rel" );
        }
    },
    $patch_dir
  );

  open( DIFF, "<$patch_dir/__DIFF__" )
    || die("Could not read __DIFF__ listing in patch directory ( $!)");

  while (<DIFF>) {
    my ( $status, $file ) = split;

    if ( $status eq 'D' ) {
      print "deleting $file\n";
      unlink("$dest_dir/$file");
    }
  }
}

