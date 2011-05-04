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
