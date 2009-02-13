package PaperPile::Model::DBIbase;

## The Catalyst::DBI model could not be used 'stand-alone' outside
## Catalyst and had some other annoying things. So I use a modified
## copy of it here.

use strict;
use base 'Catalyst::Model';
use NEXT;
use DBI;
use Data::Dumper;

our $VERSION = '0.19';

__PACKAGE__->mk_accessors( qw/_dbh _pid _tid/ );

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


# Sets can be set manually if not called from within catalyst where it is
# automatically configured from the config file

sub set_dsn {
  my ($self, $dsn)=@_;
  $self->{dsn}=$dsn;

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

  eval { $dbh = DBI->connect( $self->{dsn}, $self->{user}, $self->{password}, $self->{options} ); };
  if ($@) { 
    $self->{log}->debug(qq{Couldn't connect to the database "$@"}) if $self->{debug} 

  }
  else {
    $self->{log}->debug( 'Connected to the database via dsn:' . $self->{dsn} ) if $self->{debug};
  }
  $self->_pid($$);
  $self->_tid( threads->tid ) if $INC{'threads.pm'};

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
