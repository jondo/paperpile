package Paperpile::Model::DBIbase;

## This is a  modified copy of Catalyst::DBI

use strict;
use base 'Catalyst::Model';
use NEXT;
use DBI;
use Data::Dumper;
use FreezeThaw qw/freeze thaw/;

# For now we suppress the NEXT deprecated warning. Should think about porting DBI module...
no warnings 'Class::C3::Adopt::NEXT';

our $VERSION = '0.19';

__PACKAGE__->mk_accessors( qw/_dbh _pid _tid/ );

sub set_settings {
  my ( $self, $settings, $dbh ) = @_;

  $dbh=$self->dbh if !$dbh;

  foreach my $key ( keys %$settings ) {
    my $value = $settings->{$key};

    $self->set_setting($key, $value, $dbh);
    #$dbh->do("REPLACE INTO Settings (key,value) VALUES ('$key','$value')");
  }
}

sub get_setting {

  ( my $self, my $key, my $dbh ) = @_;

  my ($package, $filename, $line) = caller;

  $dbh=$self->dbh if !$dbh;

  $key = $dbh->quote($key);

  ( my $value ) =
    $dbh->selectrow_array("SELECT value FROM Settings WHERE key=$key ");

  return $self->_thaw_value($value);

}

sub set_setting {
  ( my $self, my $key, my $value, my $dbh ) = @_;

  $dbh=$self->dbh if !$dbh;

  # Transparently store hashes, lists and objects by flattening them
  if (ref($value)){
    $value = freeze($value);
  }

  $value = $dbh->quote($value);
  $key = $dbh->quote($key);
  $dbh->do("REPLACE INTO Settings (key,value) VALUES ($key,$value)");

  return $value;
}


sub settings {

  ( my $self, my $dbh ) = @_;

  $dbh=$self->dbh if !$dbh;

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
  my ($self, $value) = @_;

  if (substr($value, 0, 4) eq 'FrT;') {
    ($value) = thaw($value);
  }

  return $value;
}


sub new {
  my $self = shift;
  my ( $c ) = @_;
  $self = $self->NEXT::new( @_ );
  $self->{namespace}               ||= ref $self;
  $self->{additional_base_classes} ||= ();

  if ($c){
    $self->{log} = $c->log;
    $self->{debug} = $c->debug;
  } else {
    $self->{log}=undef;
    $self->{debug}=undef;
  }
  return $self;
}

sub dbh {
	return shift->stay_connected;
}


# Can be set manually if not called from within catalyst where it is
# automatically configured from the config file

sub set_dsn {
  my ($self, $dsn)=@_;
  $self->{dsn}=$dsn;

}

sub get_dsn {
  my ($self)=@_;
  return $self->{dsn};
}


sub stay_connected {
  my $self = shift;
  if ( $self->_dbh ) {
    if ( defined $self->_tid && $self->_tid != threads->tid ) {
      $self->_dbh( $self->connect );
    } elsif ( $self->_pid != $$ ) {
      $self->_dbh->{InactiveDestroy} = 1;
      $self->_dbh( $self->connect );
    } elsif ( !$self->connected ) {
      $self->_dbh( $self->connect );
    }
  } else {
    $self->_dbh( $self->connect );
  }
  return $self->_dbh;
}

sub connected {
  my $self = shift;
  if ( $self->_dbh ) {
    return $self->_dbh->{Active} && $self->_dbh->ping;
  } else {
    return 0;
  }
}

sub connect {
  my $self = shift;
  my $dbh;

  $self->{options} = { AutoCommit => 1, RaiseError => 1 };

  eval { $dbh = DBI->connect( $self->{dsn}, $self->{user}, $self->{password}, $self->{options} ); };
  #$dbh = DBI->connect( $self->{dsn}, $self->{user}, $self->{password}, $self->{options} ); 
  if ($@) {
    $self->{log}->debug(qq{Couldn't connect to the database "$@"}) if $self->{debug};
  } else {
    $self->{log}->debug( 'Connected to the database via dsn:' . $self->{dsn} ) if $self->{debug};
  }
  $self->_pid($$);
  $self->_tid( threads->tid ) if $INC{'threads.pm'};

  # Turn on unicode support explicitely
  $dbh->{sqlite_unicode} = 1;
#<<<<<<< HEAD
 #sqlite_unicode => 1,

#=======
#>>>>>>> osx
 return $dbh;
}


sub disconnect {
  my $self = shift;
  if ( $self->connected ) {
    $self->_dbh->rollback unless $self->_dbh->{AutoCommit};
    $self->_dbh->disconnect;
    $self->_dbh(undef);
  }
}

1;
