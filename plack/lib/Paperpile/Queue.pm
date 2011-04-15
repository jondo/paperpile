
# Copyright 2009-2011 Paperpile
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


package Paperpile::Queue;

use Mouse;
use Mouse::Util::TypeConstraints;
use Paperpile;
use Paperpile::Utils;
use Paperpile::Exceptions;
use Paperpile::Job;
use Data::Dumper;
use Time::Duration;
use FreezeThaw qw/freeze thaw/;
use JSON;
use 5.010;

enum 'QueueStatus' => (
  'WAITING',    # No jobs to run or all jobs done
  'RUNNING',    # Queue is processing jobs
  'PAUSED'      # Queue is paused
);

has 'status' => (
  is      => 'rw',
  isa     => 'QueueStatus',
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

# Number of jobs finished (either successfully or failed)
has num_error => ( is => 'rw', isa => 'Int', default => 0 );

# Job statistics, split up by types.
has types => ( is => 'rw', default => sub {return {};});

# List of currently running jobs
has running_jobs => ( is => 'rw', isa => 'ArrayRef', default => sub {[]} );

has _dbh => ( is => 'rw');

sub BUILD {
  my ( $self, $params ) = @_;
  $self->restore;
}

sub dbh {

  my $self = shift;

  if (not $self->_dbh){
    $self->_dbh(Paperpile::Utils->get_model("Queue")->dbh);
  }

  return $self->_dbh;
}

## Save queue object to database

sub save {

  my $self = shift;

  $self->update_stats;

  my $dbh_tmp = $self->_dbh;

  $self->_dbh(undef);

  my $serialized = freeze($self);

  $self->_dbh($dbh_tmp);

  # Test for existence of queue value in database.
  (my $existing_serialized) = $self->dbh->selectrow_array("SELECT value FROM Settings WHERE key='queue'");

  $serialized = $self->dbh->quote($serialized);
  if (defined $existing_serialized) {
    $self->dbh->do("UPDATE Settings SET value=$serialized WHERE key='queue'");
  } else {
    $self->dbh->do("INSERT INTO Settings VALUES ('queue',$serialized)");
  }

}

## Restore queue object from database

sub restore {

  my $self = shift;

  ( my $serialized ) = $self->dbh->selectrow_array("SELECT value FROM Settings WHERE key='queue' ");

  # Seems not really necessary to freeze/thaw itself if not stored
  # before. However, simplifying it led to errors and I leave it for
  # now
  if (not $serialized) {
    $self->save;
    my $dbh_tmp = $self->_dbh;
    $self->_dbh(undef);
    $serialized = freeze($self);
    $self->_dbh($dbh_tmp);
  }

  ( my $stored ) = thaw($serialized);

  foreach my $key ( $self->meta->get_attribute_list ) {
    next if $key eq '_dbh';
    next if $key eq 'running_jobs';
    $self->$key( $stored->$key );
  }
}

## Add job to the queue

sub submit {

  my ( $self, $jobs ) = @_;

  if (ref($jobs) ne 'ARRAY'){
    $jobs = [$jobs];
  }

  $self->dbh->do('BEGIN EXCLUSIVE TRANSACTION');

  foreach my $job (@$jobs){
    my $id     = $self->dbh->quote( $job->id );
    my $status = $self->dbh->quote( $job->status );
    my $hidden = $self->dbh->quote( $job->hidden );
    my $type = $self->dbh->quote( $job->job_type);
    my $guid = $self->dbh->quote( $job->pub->guid );

    # We re-insert on the same position when a rowid is given (used in retry_jobs)
    if (defined $job->_rowid){
      my $rowid = $job->_rowid;
      $self->dbh->do("REPLACE INTO Queue (rowid, jobid, status, hidden, type, guid, error, duration) VALUES ($rowid, $id, $status, $hidden, $type, $guid, 0, 0)");
    } else {
      $self->dbh->do("INSERT INTO Queue (jobid, status, hidden, type, guid, error, duration) VALUES ($id, $status, $hidden, $type, $guid, 0, 0)");
    }
  }

  $self->save;

  $self->dbh->commit;

}


## Return list of job objects currently in the queue

sub get_jobs {
  my $self = shift;
  my $status = shift || '';

  if (ref $status eq 'ARRAY') {
      my @statuses = @$status;
      @statuses = map {$self->dbh->quote($_)} @statuses;
      $status = join(",",@statuses);
  } elsif ($status ne '') {
      $status = $self->dbh->quote($status);
  }

  my $sth;
  if ($status ne '') {
    $sth = $self->dbh->prepare("SELECT jobid,status FROM Queue WHERE status IN ($status);");
  } else {
    $sth = $self->dbh->prepare("SELECT jobid,status FROM Queue;");
  }

  my ($job_id,$status2);

  $sth->bind_columns( \$job_id, \$status2 );
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

  my $sth = $self->dbh->prepare("SELECT jobid, status, hidden, type, duration FROM Queue");

  my ( $job_id, $status, $hidden, $type, $duration );

  $sth->bind_columns( \$job_id, \$status, \$hidden, \$type, \$duration );
  $sth->execute;

  my $sum_duration = 0;
  my $num_pending  = 0;
  my $num_done     = 0;
  my $num_error    = 0;

  my @running =();

  # Collect job statistics collated by type.
  my $types;
  while ( $sth->fetch ) {
    my $t = $types->{$type};
    if ( !defined $t ) {
      $t                = {};
      $t->{num_pending} = 0;
      $t->{num_done}    = 0;
      $t->{num_error}   = 0;
      $t->{name}        = $type;    # This could be improved.
      $types->{$type}   = $t;
    }

    if ($status eq 'RUNNING'){
      push @running, $job_id;
    }

    if ($hidden == 1) {
      next;
    }

    if ( $status eq 'PENDING' or $status eq 'RUNNING' ) {
      $t->{num_pending}++;
      $num_pending++;
    } elsif ( $status eq 'DONE' ) {
      $t->{num_done}++;
      $num_done++;
      $sum_duration += $duration;
    } elsif ( $status eq 'ERROR' ) {
      $t->{num_error}++;
      $num_error++;
    }
  }
  $self->running_jobs([@running]);

  # Turn it into an array form.
  my @type_arr = ();
  map { push @type_arr, $types->{$_} } keys %$types;
  $self->types( \@type_arr );

  $self->num_done($num_done);
  $self->num_pending($num_pending);
  $self->num_error($num_error);

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

#  $self->restore;
#  return if ($self->status eq 'PAUSED');

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

sub cancel_all {
  my $self = shift;

  $self->dbh->do('BEGIN EXCLUSIVE TRANSACTION');

  my $sth = $self->dbh->prepare("SELECT jobid, status FROM Queue");

  my ( $job_id, $status );

  $sth->bind_columns( \$job_id, \$status );
  $sth->execute;

  while ( $sth->fetch ) {
    my $job = Paperpile::Job->new( { id => $job_id } );

    if ( $job->status eq 'RUNNING' ) {
      $job->interrupt('CANCEL');
    }

    if ($job->status eq 'PENDING'){
      $job->error( $job->noun . ' canceled.' );
      $job->status('ERROR');
    }

    $job->save;
  }

  $self->dbh->do("UPDATE Queue SET status='ERROR' WHERE (status='PENDING')");

  $self->dbh->commit;

}


## Clears queue completely

sub clear_all {

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
  $self->status('WAITING');
  $self->save;
}

## Clear all finished jobs

sub clear {

  my $self = shift;

  my $sth = $self->dbh->prepare("SELECT jobid, status FROM Queue WHERE (status = 'DONE' OR status ='ERROR')");

  my ( $job_id, $status );

  $sth->bind_columns( \$job_id, \$status );
  $sth->execute;

  my @guids=();

  while ( $sth->fetch ) {
    my $job = Paperpile::Job->new( { id => $job_id } );
    push @guids, $job->{pub}->{guid} if (defined $job->{pub}->{guid});
    unlink( $job->_file );
  }

  $self->dbh->do("DELETE FROM Queue WHERE (status = 'DONE' OR status ='ERROR')");

  $self->save;

  return [@guids];
}




sub as_hash {
  my $self = shift;

  $self->update_stats;

  my %hash = ();

  foreach my $key ( $self->meta->get_attribute_list ) {
    my $value = $self->$key;

    if ( $key ~~ [ 'num_pending', 'num_done', 'num_error' ] ) {
      $value += 0;
    }

    if ( $key eq 'types' ) {
      $hash{$key} = $value;
    }

    next if (ref( $self->$key ) && $key ne 'running_jobs');

    $hash{$key} = $value;
  }

  return {%hash};
}

1;



