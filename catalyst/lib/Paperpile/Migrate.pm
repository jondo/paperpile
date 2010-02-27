
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

package Paperpile::Migrate;
use Moose;

use DBI;
use Data::Dumper;

# The version numbers of the current installation
has app_library_version  => ( is => 'rw' );
has app_settings_version => ( is => 'rw' );

# The files to be migrated
has library_db  => ( is => 'rw' );
has settings_db => ( is => 'rw' );

sub get_dbh {

  my ( $self, $file ) = @_;

  my $dbh = DBI->connect( "dbi:SQLite:$file", '', '', { AutoCommit => 1, RaiseError => 1 } );

}

sub migrate {

  my ( $self, $what ) = @_;

  my $file = $what eq 'library' ? $self->library_db : $self->settings_db;

  my $dbh = $self->get_dbh($file);

  ( my $version ) = $dbh->selectrow_array("SELECT value FROM Settings WHERE key='db_version' ");

  my $app_version = $what eq 'library' ? $self->app_library_version : $self->app_settings_version;

  if ( $app_version == $version ) {
    return;
  }

  for my $x ( $version .. $app_version - 1 ) {

    my $y = $x + 1;

    my $lift = "lift_$what\_$x\_$y";

    $self->$lift;

  }

  $dbh->do("UPDATE Settings SET value='$app_version' WHERE key='db_version'");

}

sub lift_library_1_2 {

  # add custom code here

}

sub lift_settings_0_1 {

  # add custom code here

}

no Moose;

__PACKAGE__->meta->make_immutable;
