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

sub begin_transaction {

  my ($self) = @_;

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

# Returns unique lock for the current sqlite database
sub get_lock_file {

  my ($self) = @_;

  my $f = $self->{file};

  $f =~ s|/|_|g;
  $f =~ s|\.|_|g;
  $f =~ s|^_||;
  $f =~ s|__|_|;

  return $f;

}

sub commit_transaction {

  my ($self) = @_;

  $self->_txdbh->commit;

  $self->_lock->unlock( $self->get_lock_file );
  $self->_lock(undef);
  $self->_txdbh(undef);

}

sub rollback_transaction {

  my ($self) = @_;

  $self->_txdbh->rollback;

  $self->_lock->unlock( $self->get_lock_file );
  $self->_lock(undef);
  $self->_txdbh(undef);
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

sub dbh {

  my $self = shift;

  if (!$self->_dbh){
    return $self->connect;
  } else {
    return $self->_dbh;
  }
}

sub connect {
  my $self = shift;
  my $dbh;

  if (not defined $self->file){
    die("Tried to connect to database of undefined name.");
  }

  $self->{options} = { AutoCommit => 1, RaiseError => 1 };

  my $dsn = "dbi:SQLite:".$self->{file};

  eval { $dbh = DBI->connect( $dsn, $self->{user}, $self->{password}, $self->{options} ); };

  if ($@) {
    die("Couldn't connect to the database ". $self->file. "(". $@ . ")");
  } else {
    print STDERR "Connected to database file:" . $self->{file}, "\n" ;
  }

  # Turn on unicode support explicitely
  $dbh->{sqlite_unicode} = 1;

  $self->_dbh($dbh);

  return $dbh;
}

#sub disconnect {
#  my $self = shift;
#  if ( $self->connected ) {
#    $self->_dbh->rollback unless $self->_dbh->{AutoCommit};
#    $self->_dbh->disconnect;
#    $self->_dbh(undef);
#  }
#}

1;
