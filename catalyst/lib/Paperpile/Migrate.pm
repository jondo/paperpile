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
use File::Copy;

use Paperpile::Library::Publication;

# The version numbers of the current installation
has app_library_version  => ( is => 'rw' );
has app_settings_version => ( is => 'rw' );

# The files to be migrated
has library_db  => ( is => 'rw' );
has settings_db => ( is => 'rw' );

sub get_dbh {

  my ( $self, $file ) = @_;

  my $dbh = DBI->connect( "dbi:SQLite:$file", '', '', { AutoCommit => 1, RaiseError => 1 } );

  return $dbh;
}

sub migrate {

  my ( $self, $what ) = @_;

  # Get version number required for current installation and the
  # actual version number of the database file
  my $file = $what eq 'library' ? $self->library_db : $self->settings_db;
  my $dbh = $self->get_dbh($file);
  ( my $version ) = $dbh->selectrow_array("SELECT value FROM Settings WHERE key='db_version' ");
  my $app_version = $what eq 'library' ? $self->app_library_version : $self->app_settings_version;

  # We are up-to-date and don't have to do anyting
  if ( $app_version == $version ) {
    return;
  }

  # Call lift function for each version step
  for my $x ( $version .. $app_version - 1 ) {
    my $y    = $x + 1;
    my $lift = "lift_$what\_$x\_$y";
    $self->$lift;
  }
}

## Add a new column and fix sha1s

sub lift_library_1_2 {

  my ($self) = @_;

  $self->backup_library_file();

  my $dbh = $self->get_dbh( $self->library_db );

  $dbh->begin_work;

  eval {

    ### Add new column to tag table
    $dbh->do("ALTER TABLE tags ADD COLUMN sort_order INTEGER");

    ### Fill new sort_order values
    my $sth = $dbh->prepare("SELECT rowid FROM tags;");

    my $rowid;
    $sth->bind_columns( \$rowid );
    $sth->execute;

    my $counter = 0;

    while ( $sth->fetch ) {
      $dbh->do("UPDATE Tags SET sort_order=$counter WHERE rowid=$rowid");
      $counter++;
    }

    ### Make sure every entry has a correct sha1 (there was a bug so
    ### some entries did not get a sha1 stored in the database)
    $self->update_sha1s($dbh);

    ### If we made it here, we can update the database version
    $dbh->do("UPDATE Settings SET value=2 WHERE key='db_version'");

  };

  if ($@) {
    $dbh->rollback;
    die("Error while updating library: $@");
  }

  $dbh->commit;

}

sub lift_settings_1_2 {
}

sub backup_library_file {

  my ($self) = @_;

  copy( $self->library_db, $self->library_db . ".backup" )
    or die("Could not backup library file. Aborting migration ($!)");

}

# Make sha1s stored in database consistent with current sha1
# function. Originally written to fix sha1 bug in 0.4.2 but can be
# re-used whenever the sha1 function changes.

sub update_sha1s {

  my ($self, $dbh) = @_;

  my $sth = $dbh->prepare("SELECT rowid, * FROM Publications;");

  $sth->execute;

  my %sha1_seen;

  while ( my $row = $sth->fetchrow_hashref() ) {

    my $data = {};

    foreach my $key ( keys %$row ) {

      next if $key eq 'sha1';

      my $value = $row->{$key};

      if ( defined $value and $value ne '' ) {
        $data->{$key} = $value;
      }
    }

    my $rowid = $row->{rowid};
    my $pub   = Paperpile::Library::Publication->new($data);

    my $updated_sha1 = $pub->sha1;

    my $new_title = undef;

    # In the *very* unlikely case that our new sha1 function produces
    # duplicates for entries that were different before, we force them
    # to be different by adding a random number to the title
    if ($sha1_seen{$updated_sha1}){
      $data->{title}= $data->{title} . " " . int(rand(100));
      $new_title = $data->{title};
      $pub   = Paperpile::Library::Publication->new($data);
      $updated_sha1 = $pub->sha1;
    }

    if ($updated_sha1 ne $row->{sha1}){
      $dbh->do("UPDATE Publications SET sha1='$updated_sha1' WHERE rowid=$rowid");
      # Also update the new title when it was changed
      if ($new_title){
        $dbh->do("UPDATE Publications SET title='$new_title' WHERE rowid=$rowid");
      }
    }

    $sha1_seen{$updated_sha1}=1;

  }
}

no Moose;

__PACKAGE__->meta->make_immutable;
