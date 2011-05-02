package Test::Paperpile::Utils;

use strict;
use Test::More;
use Test::Exception;
use File::Path;
use Data::Dumper;

use Paperpile::Library::Publication;

use base 'Test::Paperpile';

sub class { 'Paperpile::Utils' }

sub startup : Tests(startup => 1) {

  my ($self) = @_;

  use_ok $self->class;

}

sub A_misc : Tests(6) {

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


sub B_copy_file : Tests(12) {

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

sub C_store_retrieve : Tests(2) {

  my ($self) = @_;

  my $data = { test => 123 };

  Paperpile::Utils->store( "test", $data );

  my $restored = Paperpile::Utils->retrieve( "test");

  is_deeply($restored, $data, "Hash reference stored and retrieved");

  my $restored = Paperpile::Utils->retrieve( "unknown");

  is($restored, undef , "Unknown handle return undef");

}

sub D_session : Tests(3) {

  my ($self) = @_;

  Paperpile->init_tmp_dir;

  my $data = Paperpile::Utils->session;

  is_deeply( $data, {}, "Empty session returns empty hash" );

  my $hash = { field1 => 'value1', field2 => 'value2' };

  Paperpile::Utils->session(undef, $hash);

  $data = Paperpile::Utils->session;

  is_deeply( $data, $hash, "Save and restore hash data" );

  $hash->{field1} = 'new value';
  $hash->{field2} = undef;

  Paperpile::Utils->session(undef, $hash);

  $data = Paperpile::Utils->session;

  is_deeply( $data, {field1=>'new value'}, "Update/Delete key from session data" );

}

sub E_get_model : Tests(9) {

  my ($self) = @_;

  $self->setup_workspace;

  # First unset session variable with location of library db
  Paperpile::Utils->session( undef, { library_db => undef } );

  foreach my $type ( 'App', 'User', 'Library', 'Queue' ) {

    my $object = Paperpile::Utils->get_model($type);
    my $dbh    = $object->dbh;

    isa_ok( $object, "Paperpile::Model::$type" );
    isa_ok( $dbh,    "DBI::db" );

  }

  # Set session variable with location of library db
  Paperpile::Utils->session( undef, { library_db => "file_defined_in_session.db" } );

  my $object = Paperpile::Utils->get_model('Library');

  is( $object->file, "file_defined_in_session.db",
    "Library model file defined in session variable" );

}


sub F_extpdf : Tests(3) {

  my ($self) = @_;

  foreach my $binary ( 'extpdf', 'shash' ) {

    my $file = Paperpile::Utils->get_binary($binary);

    ok( $file, "$binary exists and is executable" );

  }

  ## Todo: Test environment variable on OS X

  my $output = Paperpile::Utils->extpdf(
    { command => 'INFO', inFile => Paperpile->path_to( "test", "data", "Misc", "wang08.pdf" ) } );

  is($output->{status}, "OK", "Run extpdf");

  # Don't know how to silence STDERR which is annoying in test output, so I skip this test for now:
  #throws_ok {Paperpile::Utils->extpdf({ command => 'INFO', inFile =>  'missing' })} "ExtpdfError","Error thrown";

}

sub G_uniquify_pubs : Tests(3) {


  my $pub1 = Paperpile::Library::Publication->new(title => "Test");
  my $pub2 = Paperpile::Library::Publication->new(title => "Test");
  my $pub3 = Paperpile::Library::Publication->new(title => "Other title");

  my $data = [$pub1, $pub2, $pub3];

  Paperpile::Utils->uniquify_pubs($data);

  is($pub2->title,'Test (Duplicate 1)', "Title is modified");
  isnt($pub1->sha1,$pub2->sha1, "Sha1s are different now");


}


1;
