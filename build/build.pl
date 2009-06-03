#!/usr/bin/perl -w

use strict;
use Module::ScanDeps;
use Data::Dumper;
use File::Path;
use File::Find;
use File::Spec::Functions qw(catfile);
use File::Copy::Recursive qw(fcopy);

my $platform   = 'linux64';
my $cat_dir    = '../catalyst';
my $target_dir = '/home/wash/tmp/dist/';

my @ignore = ( qr{[~#]}, qr{/tmp/}, qr{/t/}, qr{\.gitignore}, );

my $modules = scan_deps(
  files   => ['testrun.pl'],
  execute => 1,
);

foreach my $m ( sort {$a->{key} cmp $b->{key}} values %$modules ) {

  my $relative=$m->{key};

  # relative path is not correct for some autoloads, adjust manually
  $relative=$1 if $relative=~/\/.*\/(auto\/.*)$/;

  print $m->{type}, ": ", $relative, "\n";

  fcopy( $m->{file}, catfile( $target_dir, 'lib', $relative ) ) or die($!);

}

my @list = ();

find( {
    no_chdir => 1,
    wanted   => sub {
      my $name = $File::Find::name;
      return if -d $name;
      foreach my $r (@ignore) {
        return if $name =~ $r;
      }
      push @list, File::Spec->abs2rel( $name, $cat_dir );
      }
  },
  $cat_dir
);

foreach my $file (@list) {

  my ( $volume, $dir, $base ) = File::Spec->splitpath($file);

  $dir = catfile( $target_dir, $dir );
  mkpath($dir) if !-d $dir;

  fcopy( catfile( $cat_dir, $file ), catfile( $target_dir, $file ) ) or die($!);

  #print( File::Spec->catfile( $cat_dir, $file ), "  ", File::Spec->catfile( $target_dir, $file ) );
  #fcopy( File::Spec->catfile( $cat_dir, $file ), File::Spec->catfile( $target_dir, $file ) )
  #  or print("\n$@\n");

}

