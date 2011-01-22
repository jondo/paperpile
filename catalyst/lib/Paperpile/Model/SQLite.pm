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

package Paperpile::Model::SQLite;

use strict;
use base 'Catalyst::Model';
use Moose;
use DBI;
use Data::Dumper;
use LockFile::Simple;
use FreezeThaw qw/freeze thaw/;

has 'file'    => ( is => 'rw' );
has '_dbh'   => ( is => 'rw' );
has '_txdbh' => ( is => 'rw' );
has '_lock' => ( is => 'rw' );


sub connect {

  my ($self) = @_;

  if ( not defined $self->file ) {
    die("Tried to connect to database of undefined name.");
  }

  $self->{options} = { AutoCommit => 1, RaiseError => 1 };

  my $dbh;
  my $dsn = "dbi:SQLite:" . $self->{file};

  eval { $dbh = DBI->connect( $dsn, $self->{user}, $self->{password}, $self->{options} ); };

  if ($@) {
    die( "Couldn't connect to " . $self->file . "(" . $@ . ")" );
  } else {
    $self->log( "Connected to: " . $self->{file} );
  }

  # Turn on unicode support explicitely
  $dbh->{sqlite_unicode} = 1;

  $self->_dbh($dbh);

  return $dbh;
}

sub dbh {

  my $self = shift;

  if (!$self->_dbh){
    return $self->connect;
  } else {
    return $self->_dbh;
  }
}

sub begin_transaction {

  my ($self) = @_;

  $self->log("Begin transaction on ". $self->file);

  if ( defined $self->_txdbh ) {
    return $self->_txdbh;
  } else {
    my $dbh = $self->dbh;

    # Explicitly lock transaction with external lock file in
    # /tmp. Should avoid locking issues in NFS based file systems

    my $lock = LockFile::Simple->make(
      -format => Paperpile->config->{tmp_dir} . "/%f.lock",
      -delay     => 1,     # Wait 1 second between next try to get lock on file
      -max       => 30,    # Try at most 30 times, i.e. timeout is 30 seconds
      -autoclean => 1,     # Clean lockfile when process ends
    );

    $lock->lock( $self->get_lock_file )
      || die( "Could not get lock on " . $self->{file} . ". Giving up." );

    $dbh->do('BEGIN EXCLUSIVE TRANSACTION');

    $self->_lock($lock);
    $self->_txdbh($dbh);

    return $dbh;
  }
}

sub commit_transaction {

  my ($self) = @_;

  $self->log("Commit transaction on ".$self->file);

  $self->_txdbh->commit;

  $self->_lock->unlock( $self->get_lock_file );
  $self->_lock(undef);
  $self->_txdbh(undef);

}

sub rollback_transaction {

  my ($self) = @_;

  $self->log("Rollback transaction on ".$self->file);

  $self->_txdbh->rollback;

  $self->_lock->unlock( $self->get_lock_file );
  $self->_lock(undef);
  $self->_txdbh(undef);
}


# Returns unique lock for the current sqlite database
sub get_lock_file {

  my ($self) = @_;

  my $f = $self->{file};

  # Make a nice file-name out of the full path
  $f =~ s|/|_|g;
  $f =~ s|\.|_|g;
  $f =~ s|^_||;
  $f =~ s|__|_|;

  return $f;

}

sub set_settings {
  my ( $self, $settings, $dbh ) = @_;

  $dbh = $self->dbh if !$dbh;

  foreach my $key ( keys %$settings ) {
    my $value = $settings->{$key};

    $self->set_setting( $key, $value, $dbh );
  }
}

sub get_setting {

  ( my $self, my $key, my $dbh ) = @_;

  my ( $package, $filename, $line ) = caller;

  $dbh = $self->dbh if !$dbh;

  $key = $dbh->quote($key);

  ( my $value ) = $dbh->selectrow_array("SELECT value FROM Settings WHERE key=$key ");

  return $self->_thaw_value($value);

}

sub set_setting {
  ( my $self, my $key, my $value, my $dbh ) = @_;

  $dbh = $self->dbh if !$dbh;

  # Transparently store hashes, lists and objects by flattening them
  if ( ref($value) ) {
    $value = freeze($value);
  }

  $value = $dbh->quote($value);
  $key   = $dbh->quote($key);
  $dbh->do("REPLACE INTO Settings (key,value) VALUES ($key,$value)");

  return $value;
}

sub settings {

  ( my $self, my $dbh ) = @_;

  $dbh = $self->dbh if !$dbh;

  my $sth = $dbh->prepare("SELECT key,value FROM Settings;");
  my ( $key, $value );
  $sth->bind_columns( \$key, \$value );

  $sth->execute;

  my %output;

  while ( $sth->fetch ) {
    $output{$key} = $self->_thaw_value($value);
  }

  return {%output};

}

# If it was a flattened object, restore it transparently
sub _thaw_value {
  my ( $self, $value ) = @_;

  if ( substr( $value, 0, 4 ) eq 'FrT;' ) {
    ($value) = thaw($value);
  }

  return $value;
}

sub log {

  my ($self, $msg) = @_;

  print STDERR "[info] $msg (pid:$$)\n";

}

1;
