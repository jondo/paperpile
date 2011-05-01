package Test::Paperpile::Utils;

use strict;
use Test::More;
use File::Path;
use Data::Dumper;

use base 'Test::Paperpile';

sub class { 'Paperpile::Utils' }

sub startup : Tests(startup => 1) {

  my ($self) = @_;

  use_ok $self->class;

}


sub copy_file : Tests(12) {

  my ($self) = @_;

  $self->clean_workspace;
  mkpath( $self->workspace );

  ## Copy file with suffix

  my $source = Paperpile->path_to( "test", "data", "Misc", "wang08.pdf" );
  my $dest = Paperpile->path_to( "test", "workspace", "copied.pdf" );

  my $copied_file = Paperpile::Utils->copy_file( $source, $dest );

  is( $copied_file, $self->workspace . "/copied.pdf", "Returns correct file name" );
  ok( -e $dest, "File was copied" );

  ## Copy file again and test if disambiguation was correct

  $copied_file = Paperpile::Utils->copy_file( $source, $dest );

  is( $copied_file, $self->workspace . "/copied_1.pdf", "Returns correct file name with _1.pdf suffix" );
  ok( -e $dest, "File was copied" );

  $copied_file = Paperpile::Utils->copy_file( $source, $dest );

  is( $copied_file, $self->workspace . "/copied_2.pdf", "Returns correct file name with _2.pdf suffix" );
  ok( -e $dest, "File was copied" );

  ## Copy file without suffix and test also disambiguation here

  $source = Paperpile->path_to( "test", "data", "Misc", "wang08.pdf" );
  $dest = Paperpile->path_to( "test", "workspace", "nosuffix" );

  $copied_file = Paperpile::Utils->copy_file( $source, $dest );

  is( $copied_file, $self->workspace . "/nosuffix", "Returns correct file name for file without suffix" );
  ok( -e $dest, "File without suffix was copied" );

  $copied_file = Paperpile::Utils->copy_file( $source, $dest );

  is( $copied_file, $self->workspace . "/nosuffix_1", "Returns correct file name with _1 for file without suffix" );
  ok( -e $dest, "File without suffix was copied" );

  $source = Paperpile->path_to( "test", "data", "Misc", "wang08.pdf" );
  $dest = Paperpile->path_to( "test", "workspace", "subfolder", "copied.pdf" );

  ## Test if subfolder is created

  $copied_file = Paperpile::Utils->copy_file( $source, $dest );

  is( $copied_file, $self->workspace . "/subfolder/copied.pdf", "Returns correct file name in subfolder" );
  ok( -e $dest, "File was copied and subfolder was created" );


  $self->clean_workspace;

}

sub misc : Tests(8) {

  my ($self) = @_;

  my $file = Paperpile->path_to( "test", "data", "Misc", "wang08.pdf" );

  my $md5 = Paperpile::Utils->calculate_md5($file);

  is( $md5, "a0c03eb326100497af5788ae54e54ce4", "calculate_md5: MD5 hash is correct" );

  my $guid = Paperpile::Utils->generate_guid;

  like($guid, qr/^[0-9A-F]{32}$/, "generate_guid: Got valid guid");

  my $time_stamp = Paperpile::Utils->gm_timestamp;

  like($time_stamp, qr/^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d$/, "gm_timestamp: Got valid time stamp");

  my $domain = Paperpile::Utils->domain_from_url("http://www.google.com");
  is($domain, "google.com", "domain_from_url: http://www.google.com");

  $domain = Paperpile::Utils->domain_from_url("http://google.com");
  is($domain, "google.com", "domain_from_url: http://google.com");

  $domain = Paperpile::Utils->domain_from_url("http://subdomain.google.com");
  is($domain, "subdomain.google.com", "domain_from_url: http://subdomain.google.com");


}

sub store_retrieve : Tests(2) {

  my ($self) = @_;

  my $data = { test => 123 };

  Paperpile::Utils->store( "test", $data );

  my $restored = Paperpile::Utils->retrieve( "test");

  is_deeply($restored, $data, "Hash reference stored and retrieved");

  my $restored = Paperpile::Utils->retrieve( "unknown");

  is($restored, undef , "Unknown handle return undef");

}


1;
