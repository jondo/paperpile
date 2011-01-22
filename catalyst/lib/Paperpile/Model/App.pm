# Copyright 2009, 2010 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public License for more details.  You should have
# received a copy of the GNU Affero General Public License along with
# Paperpile.  If not, see http://www.gnu.org/licenses.


package Paperpile::Model::App;

use strict;
use Carp;
use base 'Paperpile::Model::SQLite';
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
