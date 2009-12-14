package Paperpile::Queue;

use Moose;
use Moose::Util::TypeConstraints;

use Paperpile::Utils;
use Paperpile::Exceptions;
use Paperpile::Job;
use Data::Dumper;
use Time::Duration;
use FreezeThaw qw/freeze thaw/;
use JSON;
use 5.010;

enum 'Status' => (
  'WAITING',    # No jobs to run or all jobs done
  'RUNNING',    # Queue is processing jobs
  'PAUSED'      # Queue is paused
);

has 'status' => (
  is      => 'rw',
  isa     => 'Status',
  default => 'WAITING',
);

# Maximum number of jobs running at the same time
has max_running => ( is => 'rw', isa => 'Int', default => 2 );

# Estimated time to completion
has eta => ( is => 'rw', isa => 'Str', default => "--:--:--" );

# Number of remaining jobs (running jobs + waiting jobs)
has num_pending => ( is => 'rw', isa => 'Int', default => 0 );

# Number of jobs finished (either successfully or failed)
has num_done => ( is => 'rw', isa => 'Int', default => 0 );

has _dbh => ( is => 'rw');

sub BUILD {
  my ( $self, $params ) = @_;
  $self->restore;
}

sub dbh {

  my $self = shift;

  if (not $self->_dbh){
    $self->_dbh(Paperpile::Utils->get_queue_model->dbh);
  }

  return $self->_dbh;
}

## Save queue object to database

sub save {

  my $self = shift;

  $self->_dbh(undef);

  my $serialized = freeze($self);

  my $dbh = Paperpile::Utils->get_queue_model->dbh;

  $self->dbh->begin_work();
  $serialized = $dbh->quote($serialized);
  $self->dbh->do("UPDATE Settings SET value=$serialized WHERE key='queue' ");

  $self->dbh->commit();

}

## Restore queue object from database

sub restore {

  my $self = shift;

  $self->dbh->begin_work();

  ( my $serialized ) = $self->dbh->selectrow_array("SELECT value FROM Settings WHERE key='queue' ");

  $self->dbh->commit;

  return if not $serialized;

  ( my $stored ) = thaw($serialized);

  foreach my $key ( $self->meta->get_attribute_list ) {
    next if $key eq '_dbh';
    $self->$key( $stored->$key );
  }
}

## Add job to the queue

sub submit {

  my ( $self, $jobs ) = @_;

  if (ref($jobs) ne 'ARRAY'){
    $jobs = [$jobs];
  }

  $self->dbh->begin_work;

  foreach my $job (@$jobs){
    my $id     = $self->dbh->quote( $job->id );
    my $status = $self->dbh->quote( $job->status );
    $self->dbh->do("INSERT INTO Queue (jobid, status) VALUES ($id, $status)");
  }

  $self->dbh->commit;

}

## Return list of job objects currently in the queue

sub get_jobs {

  my $self = shift;

  my $sth = $self->dbh->prepare("SELECT jobid FROM Queue");

  my ($job_id);

  $sth->bind_columns( \$job_id );
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

  my $sth = $self->dbh->prepare("SELECT jobid, status, duration FROM Queue");

  my ( $job_id, $status, $duration );

  $sth->bind_columns( \$job_id, \$status, \$duration );
  $sth->execute;

  my $sum_duration = 0;
  my $num_pending  = 0;
  my $num_done     = 0;

  while ( $sth->fetch ) {
    if ( $status eq 'PENDING' or $status eq 'RUNNING' ) {
      $num_pending++;
    } elsif ( $status eq 'DONE' ) {
      $num_done++;
      $sum_duration += $duration;
    }
  }

  $self->num_done($num_done);
  $self->num_pending($num_pending);

  if ( $num_done >= 1 ) {
    my $seconds_left = int( $sum_duration / $num_done * $num_pending );
    $self->eta( Time::Duration::duration($seconds_left) );
  } else {
    $self->eta('');
  }

}


## Starts queue. All jobs are run until not jobs are left. Jobs are
## run in parallel with at most max_running at the same time.

sub run {

  my $self = shift;

  # We don't run new jobs if paused
  return if $self->status eq 'PAUSED';

  # To avoid race-conditions make sure we get a proper read/write lock
  # via an exclusive transaction;
  $self->dbh->do('BEGIN EXCLUSIVE TRANSACTION');

  # Get list of jobs that need to be started next
  my $sth = $self->dbh->prepare("SELECT jobid, status FROM Queue");
  my ( $job_id, $status );
  $sth->bind_columns( \$job_id, \$status );
  $sth->execute;

  my $curr_running = 0;
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
    if ( $curr_running < $self->max_running ) {
      $self->dbh->do("UPDATE Queue SET status='RUNNING' WHERE jobid='$id'");
      push @to_be_started, $id;
      $curr_running++;
    } else {
      last;
    }
  }

  $self->dbh->do('COMMIT TRANSACTION');

  # If no jobs are running and no more jobs left to start we set
  # status to 'WAITING'
  if ($curr_running == 0 and @to_be_started == 0){
    $self->status('WAITING');
    $self->save;
  }
  # else we create job objects from the ids and call their run
  # function
  else {
    foreach my $id (@to_be_started) {
      my $job = Paperpile::Job->new( { id => $id } );
      $job->run;
    }
    $self->status('RUNNING');
    $self->save;
  }
}

## Pause queue, running jobs are finished but no new jobs are started

sub pause {
  my $self = shift;
  $self->restore;
  $self->status('PAUSED');
  $self->save;
}

## Start queue again after pause

sub resume {
  my $self = shift;
  $self->restore;
  $self->status('RUNNING');
  $self->run;
  $self->save;
}


## Clears queue completely

sub clear {

  my $self = shift;

  my $sth = $self->dbh->prepare("SELECT jobid, status FROM Queue");

  my ( $job_id, $status );

  $sth->bind_columns( \$job_id, \$status );
  $sth->execute;

  while ( $sth->fetch ) {
    my $job = Paperpile::Job->new( { id => $job_id } );

    unlink( $job->_file );
  }

  $self->dbh->do("UPDATE Settings SET value='' WHERE key='queue'");
  $self->dbh->do("DELETE FROM Queue");

  $self->save;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;


