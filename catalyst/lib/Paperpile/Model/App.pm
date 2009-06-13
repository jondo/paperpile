package Paperpile::Model::App;

use strict;
use Carp;
use base 'Paperpile::Model::DBIbase';
use Data::Dumper;
use Moose;

sub init_db {

  my ( $self, $settings ) = @_;

  # Create application settings table
  $self->dbh->do('DROP TABLE IF EXISTS Settings');
  $self->dbh->do("CREATE TABLE Settings (key TEXT, value TEXT)");

  foreach my $key ( keys %$settings ) {
    my $value = $settings->{$key};
    $self->dbh->do("INSERT INTO Settings (key,value) VALUES ('$key','$value')");
  }
}

sub get_setting {

  ( my $self, my $key ) = @_;
  $key = $self->dbh->quote($key);
  ( my $value ) =
    $self->dbh->selectrow_array("SELECT value FROM Settings WHERE key=$key ");
  return $value;
}

sub set_setting {

  ( my $self, my $key, my $value ) = @_;
  $value = $self->dbh->quote($value);
  $key = $self->dbh->quote($key);
  $self->dbh->do("UPDATE Settings SET value=$value WHERE key=$key ");

  return $value;
}

sub settings {

  ( my $self ) = @_;
  my $sth = $self->dbh->prepare("SELECT key,value FROM Settings;");
  my ( $key, $value );
  $sth->bind_columns( \$key, \$value );
  $sth->execute;
  my %output;
  while ( $sth->fetch ) {
    $output{$key} = $value;
  }
  return {%output};
}




1;
