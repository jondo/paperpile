package Test::Paperpile::Model::SQLite;

use strict;
use Test::More;
use Test::Exception;
use File::Copy;

use utf8;

use Paperpile;

use base 'Test::Paperpile';

sub class { 'Paperpile::Model::SQLite' }

sub startup : Test(startup => 1) {
  my ($self) = @_;

  use_ok $self->class;
  $self->clean_workspace;

  $self->{db_file} = Paperpile->path_to( 'test', 'workspace', 'test.db' );

  copy( Paperpile->path_to( 'db', 'user.db' ), $self->{db_file} );

}

sub connect : Tests(4) {

  my ($self) = @_;

  my $model = Paperpile::Model::SQLite->new( file => $self->{db_file} );

  my $dbh = $model->connect;

  isa_ok( $dbh, "DBI::db","Connect returns handle:");

  $model->file(undef);

  dies_ok { $model->connect } 'Dies on undefined file name';

  $model = Paperpile::Model::SQLite->new( file => $self->{db_file} );

  $dbh = $model->dbh;

  isa_ok( $dbh , "DBI::db", "dbh returns handle:");

  is($model->dbh,$dbh, "Get same dbh on second call.");

}

sub transactions : Tests(10) {

  my ($self) = @_;

  my $model = Paperpile::Model::SQLite->new( file => $self->{db_file} );


  # Complete transaction with commit

  my $dbh = $model->begin_transaction;

  isa_ok( $dbh, "DBI::db", "begin_transaction returns handle:" );

  is( $model->begin_transaction, $dbh, "Get same dbh on second call of begin_transaction" );

  my $lock_file = Paperpile->tmp_dir . "/" . $model->get_lock_file .".lock";

  ok( -e $lock_file, "Lock file exists" );
  ok( $model->in_transaction,   "in_transaction returns true" );

  $dbh->do("INSERT INTO Settings (key,value) VALUES ('test','value1')");

  $model->commit_transaction;

  ok( !(-e $lock_file), "Lock file does not exist" );
  ok( !($model->in_transaction),   "in_transaction returns false" );
  $self->row_ok($dbh, "Settings", "key='test'", {value=>'value1'}, "Check if update was made in db");

  # Transaction with rollback

  $dbh = $model->begin_transaction;
  $dbh->do("INSERT INTO Settings (key,value) VALUES ('test2','value2')");

  $model->rollback_transaction;

  ok( !(-e $lock_file), "Lock file does not exist" );
  ok( !($model->in_transaction),   "in_transaction returns false" );
  $self->row_count_ok($dbh, "Settings", "key='test2'", 0 , "Check if update was rolled back in db");



}

sub settings : Tests(4) {

  my ($self) = @_;

  my $model = Paperpile::Model::SQLite->new( file => $self->{db_file} );

  ### Set/get simple value
  $model->set_setting( "key1", "value1" );
  my $value = $model->get_setting("key1");

  is( $value, "value1", "Get/set simple setting." );

  $model->set_setting( "unicode", "оживлённым" );
  my $value = $model->get_setting("unicode");

  is( $value, 'оживлённым', "Get/set unicode value" );

  ### Set/get complex value
  my $hash = { 'subkey1' => 'subvalue1', 'subkey2' => 'subvalue2' };

  $model->set_setting( "key2", $hash );
  $value = $model->get_setting("key2");

  is_deeply( $value, $hash, "Get/set complex setting." );

  ### Set/get complete settings

  $model->dbh->do('DELETE FROM Settings;');

  my $data = { key1 => 'value1', key2 => 'value2' };

  $model->set_settings($data);

  $value = $model->settings;

  is_deeply( $value, $data, "Get/set complete settings." );



}

1;
