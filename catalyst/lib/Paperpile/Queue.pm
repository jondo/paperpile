package Paperpile::Queue;

use Moose;
use Moose::Util::TypeConstraints;

use Paperpile::Utils;
use Paperpile::Exceptions;
use Paperpile::Job;
use Data::Dumper;
use Time::Duration;
use FreezeThaw qw/freeze thaw/;
use File::Temp qw/ tempfile /;
use JSON;
use 5.010;

enum 'Status' => qw(RUNNING WAITING PAUSED);

has 'status' => (
  is      => 'rw',
  isa     => 'Status',
  default => 'WAITING',
  trigger => sub { my $self = shift; $self->save; }
);

has eta         => ( is => 'rw', isa => 'Str', default => "--:--:--" );
has num_pending => ( is => 'rw', isa => 'Int', default => 0 );
has num_done    => ( is => 'rw', isa => 'Int', default => 0 );

sub BUILD {
  my ( $self, $params ) = @_;
  $self->restore;
}

## Save queue object to database

sub save {

  my $self = shift;

  my $serialized = freeze($self);

  my $dbh = Paperpile::Utils->get_queue_model->dbh;

  $dbh->begin_work();
  $serialized = $dbh->quote($serialized);
  $dbh->do("UPDATE Settings SET value=$serialized WHERE key='queue' ");

  $dbh->commit();

}

## Restore queue object from database

sub restore {

  my $self = shift;

  my $dbh = Paperpile::Utils->get_queue_model->dbh;

  $dbh->begin_work();

  ( my $serialized ) = $dbh->selectrow_array("SELECT value FROM Settings WHERE key='queue' ");

  $dbh->commit;

  return if not $serialized;

  ( my $stored ) = thaw($serialized);

  foreach my $key ( $self->meta->get_attribute_list ) {
    $self->$key( $stored->$key );
  }
}

## Adds job object to the queue

sub submit {

  my ( $self, $job ) = @_;

  my $dbh = Paperpile::Utils->get_queue_model->dbh;

  my $id     = $dbh->quote( $job->id );
  my $status = $dbh->quote( $job->status );

  $dbh->do("INSERT INTO Queue (jobid, status) VALUES ($id, $status)");

}

## Returns list of job objects currently in the queue

sub get_jobs {

  my $self = shift;

  my $dbh = Paperpile::Utils->get_queue_model->dbh;

  my $sth = $dbh->prepare("SELECT jobid FROM Queue");

  my ( $job_id);

  $sth->bind_columns( \$job_id);
  $sth->execute;

  my @jobs = ();

  while ( $sth->fetch ) {
    push @jobs, Paperpile::Job->new( { id => $job_id } );
  }

  return [@jobs];

}

## Updates fields "eta", "num_pending" and "num_done" from database

sub update_stats {

  my $self = shift;

  my $dbh = Paperpile::Utils->get_queue_model->dbh;

  my $sth = $dbh->prepare("SELECT jobid, status, duration FROM Queue");

  my ( $job_id, $status, $duration );

  $sth->bind_columns( \$job_id, \$status, \$duration );
  $sth->execute;

  my $sum_duration =  0;
  my $num_pending = 0;
  my $num_done =0;

  while ( $sth->fetch ) {
    if ( $status eq 'PENDING' ) {
      $num_pending++;
    } elsif ( $status eq 'DONE' ) {
      $num_done++;
      $sum_duration+=$duration;
    }
  }

  $self->num_done($num_done);
  $self->num_pending($num_pending);

  if ($num_done>=1){
    my $seconds_left = int($sum_duration/$num_done*$num_pending);
    $self->eta(Time::Duration::duration($seconds_left));
  } else {
    $self->eta('');
  }
}


#sub pause {
#  my $self = shift;
#  $self->restore;
#  $self->status('PAUSED');
#  $self->save;
#}

#sub resume {
#  my $self = shift;
#  $self->restore;
#  $self->status('RUNNING');
#  $self->save;
#}


## Starts pending jobs

sub run {

  my $self = shift;

  use IO::Handle;
  open my $log, ">>", "log";
  $log->autoflush(1);

  #$self->restore;
  my $dbh = Paperpile::Utils->get_queue_model->dbh;

  print $log "Locking database $$\n";

  #$dbh->begin_work();

  $dbh->do('BEGIN EXCLUSIVE TRANSACTION');

  my $curr_job = undef;

  my $max_running = 1;

  my $curr_running = 0;

  print $log "Running remaining jobs $$\n";

  my $sth = $dbh->prepare("SELECT jobid, status FROM Queue");

  my ( $job_id, $status );

  $sth->bind_columns( \$job_id, \$status );
  $sth->execute;

  my @pending = ();

  while ( $sth->fetch ) {
    if ( $status eq 'RUNNING' ) {
      $curr_running++;
    } elsif ( $status eq 'PENDING' ) {
      push @pending, $job_id;
    }
  }

  my @to_be_started = ();

  foreach my $id (@pending) {
    if ( $curr_running < $max_running ) {
      $dbh->do("UPDATE Queue SET status='RUNNING' WHERE jobid='$id'");
      push @to_be_started, $id;
      $curr_running++;
    } else {
      last;
    }
  }

  $dbh->do('COMMIT TRANSACTION');

  foreach my $id (@to_be_started) {
    print $log "Starting job $id $$\n";
    my $job = Paperpile::Job->new( { id => $id } );
    $job->run;
  }

  if ( not @to_be_started ) {
    print $log "No pending jobs left.$$\n";
  }

  print $log "Commiting to database $$\n";

}


## Clears queue completely

sub clear {

  my $self = shift;

  my $dbh = Paperpile::Utils->get_queue_model->dbh;

  my $sth = $dbh->prepare("SELECT jobid, status FROM Queue");

  my ( $job_id, $status );

  $sth->bind_columns( \$job_id, \$status );
  $sth->execute;

  while ( $sth->fetch ) {
    my $job = Paperpile::Job->new( { id => $job_id } );
    unlink($job->file);
  }

  $dbh->do("UPDATE Settings SET value='' WHERE key='queue'");
  $dbh->do("DELETE FROM Queue");

  $self->save;
}


1;
