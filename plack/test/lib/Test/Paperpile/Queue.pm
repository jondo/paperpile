package Test::Paperpile::Queue;

use strict;
use Test::More;
use Data::Dumper;
use File::Copy;
use JSON;

use Paperpile;


use base 'Test::Paperpile';

sub class { 'Paperpile::Queue' }

sub startup : Tests(startup => 1) {
  my ($self) = @_;

  # Start with a fresh copy of queue.db
  copy( Paperpile->path_to('db/queue.db'), Paperpile->config->{'queue_db'} );

  use_ok $self->class;

}

sub basic : Tests(34) {
  my ($self) = @_;

  my $q = Paperpile::Queue->new;


  ## Get DB handle
  isa_ok( $q->dbh, 'DBI::db', "get db handle" );

  ## Save restore from/to database and JSON file
  $q->max_running(10);
  $q->save;
  $q->max_running(0);
  $q->restore;

  is( $q->max_running, 10, "Save restore object to/from database" );

  open( IN, "<".$q->_json_file );
  my $string = '';
  $string .= $_ while (<IN>);
  my $data = decode_json($string);

  is( $data->{max_running}, 10, "Save restore object to/from json file" );


  ## Submit jobs

  my $job1 = Paperpile::Job->new( job_type => "TEST_JOB1", queued => 1 );
  my $job2 = Paperpile::Job->new( job_type => "TEST_JOB1", queued => 1 );
  my $job3 = Paperpile::Job->new( job_type => "TEST_JOB1", queued => 1 );

  $job1->update_info( "name", "job1" );
  $job2->update_info( "name", "job2" );
  $job3->update_info( "name", "job3" );

  $q->submit($job1);

  ( my $count ) = $q->dbh->selectrow_array("SELECT count(*) FROM Queue;");

  is( $count, 1, "Submit job1 to queue. Count is 1." );

  $q->submit( [ $job2, $job3 ] );

  ($count) = $q->dbh->selectrow_array("SELECT count(*) FROM Queue;");

  is( $count, 3, "Submit job2 and job3 to queue. Count is 3." );

  ## Get jobs and job statistics

  my $jobs = $q->get_jobs;

  is( @$jobs, 3, "Get all jobs via get_jobs. Count is ok." );

  is( $jobs->[0]->info->{name}, "job1", "Get jobs via get_jobs. Job 1 is correct." );
  is( $jobs->[1]->info->{name}, "job2", "Get jobs via get_jobs. Job 2 is correct." );
  is( $jobs->[2]->info->{name}, "job3", "Get jobs via get_jobs. Job 3 is correct." );

  $q->update_stats;

  is( $q->num_pending, 3, "Statistics 1. All three jobs are pending." );
  is( $q->num_done,    0, "Statistics 1. None are done." );
  is( $q->num_error,   0, "Statistics 1. None have errors." );

  $jobs = $q->get_jobs('PENDING');
  is( @$jobs, 3, "Statistics 1. Get all pending jobs. Count is ok." );

  $jobs = $q->get_jobs(['RUNNING', 'DONE','ERROR']);
  is( @$jobs, 0, "Statistics 1. All other jobs Count is ok." );

  $job1->update_status('RUNNING');

  $q->update_stats;

  is( $q->num_pending, 3, "Statistics 2. All three jobs are pending." );
  is( $q->num_done,    0, "Statistics 2. None are done." );
  is( $q->num_error,   0, "Statistics 2. None have errors." );

  $jobs = $q->get_jobs('PENDING');
  is( @$jobs, 2, "Statistics 2. Get all pending jobs. Count is ok." );

  $jobs = $q->get_jobs('RUNNING');
  is( @$jobs, 1, "Statistics 2. Get all running jobs. Count is ok." );

  $jobs = $q->get_jobs(['DONE', 'ERROR']);
  is( @$jobs, 0, "Statistics 2. Get all finished jobs. Count is ok." );

  $job1->update_status('DONE');

  $q->update_stats;

  is( $q->num_pending, 2, "Statistics 3. Two jobs are pending." );
  is( $q->num_done,    1, "Statistics 3. One job is done." );
  is( $q->num_error,   0, "Statistics 3. None have errors." );

  $jobs = $q->get_jobs('DONE');
  is( @$jobs, 1, "Statistics 3. Get all finished jobs. Count is ok." );

  $job2->update_status('ERROR');

  $q->update_stats;

  is( $q->num_pending, 1, "Statistics 4. One job is pending." );
  is( $q->num_done,    1, "Statistics 4. One job is done." );
  is( $q->num_error,   1, "Statistics 4. One job has errors." );

  $jobs = $q->get_jobs('ERROR');
  is( @$jobs, 1, "Statistics 4. Get all jobs with errors. Count is ok." );

  ## Cancel jobs

  # Don't use status 'RUNNING' for cancel because they are not really running.
  $job1->update_status('PENDING');
  $job2->update_status('PENDING');
  $job3->update_status('DONE');

  $q->cancel_all;

  ($count) = $q->dbh->selectrow_array("SELECT count(*) FROM Queue WHERE status='ERROR';");

  is( $count, 2, "Cancel all. Two jobs have now status ERROR" );
  $jobs = $q->get_jobs('ERROR');

  like( $jobs->[0]->{error}, qr/canceled/, "Job 1 was canceled." );
  like( $jobs->[1]->{error}, qr/canceled/, "Job 2 was canceled." );

  $job1->update_status('PENDING');
  $job2->update_status('ERROR');
  $job3->update_status('DONE');

  ## Clear jobs

  $q->clear;

  ($count) = $q->dbh->selectrow_array("SELECT count(*) FROM Queue;");

  is( $count, 1, "clear. One pending job left" );
  $jobs = $q->get_jobs;

  is( $jobs->[0]->info->{name}, "job1", "clear. Job1 is still left" );

  $q->clear_all;

  ($count) = $q->dbh->selectrow_array("SELECT count(*) FROM Queue;");

  is( $count, 0, "clear_all. All jobs cleared." );

}


sub running : Tests(14) {

  my ($self) = @_;

  my $q = Paperpile::Queue->new;

  ## First run one after another

  my $job1 = Paperpile::Job->new( job_type => "TEST_JOB2", queued => 1 );
  my $job2 = Paperpile::Job->new( job_type => "TEST_JOB2", queued => 1 );

  $job1->update_info( "name", "job1" );
  $job2->update_info( "name", "job2" );

  $q->submit($job1);
  $q->submit($job2);

  $q->max_running(1);

  $q->run;

  sleep(1);

  my $jobs = $q->get_jobs('RUNNING');

  is( @$jobs, 1, "Running queue sequential. One job is running." );
  is( $jobs->[0]->{info}->{name}, "job1", "Running queue sequential. Job 1 is running.");

  sleep(2);

  my $jobs = $q->get_jobs('RUNNING');

  is( @$jobs, 1, "Running queue sequential. One job is running." );
  is( $jobs->[0]->{info}->{name}, "job2", "Running queue sequential. Job 2 is running.");

  sleep(2);

  my $jobs = $q->get_jobs('DONE');

  is( @$jobs, 2, "Running queue sequential. Both jobs done." );


  ## Run two job simultanously

  $q->clear_all();

  $job1 = Paperpile::Job->new( job_type => "TEST_JOB2", queued => 1 );
  $job2 = Paperpile::Job->new( job_type => "TEST_JOB2", queued => 1 );

  $job1->update_info( "name", "job1" );
  $job2->update_info( "name", "job2" );

  my $q = Paperpile::Queue->new;

  $q->submit($job1);
  $q->submit($job2);

  $q->max_running(2);

  $q->run;

  sleep(1);

  my $jobs = $q->get_jobs('RUNNING');

  is( @$jobs, 2, "Running queue in parallel. Tow jobs running." );
  is( $jobs->[0]->{info}->{name}, "job1", "Running queue in parallel. Job 1 is running.");
  is( $jobs->[1]->{info}->{name}, "job2", "Running queue in parallel. Job 2 is running.");

  sleep(2);

  my $jobs = $q->get_jobs('DONE');

  is( @$jobs, 2, "Running queue. Both jobs done." );

  ## Run two jobs with pause/resume

  $q->clear_all();

  $job1 = Paperpile::Job->new( job_type => "TEST_JOB2", queued => 1 );
  $job2 = Paperpile::Job->new( job_type => "TEST_JOB2", queued => 1 );

  $job1->update_info( "name", "job1" );
  $job2->update_info( "name", "job2" );

  $q->submit($job1);
  $q->submit($job2);

  $q->max_running(1);

  $q->run;
  $q->pause;

  sleep(1);

  my $jobs = $q->get_jobs('RUNNING');

  is( @$jobs, 1, "Running queue with pause/resume. One job is running." );
  is( $jobs->[0]->{info}->{name}, "job1", "Running queue sequential. Job 1 is running.");

  sleep(2);

  my $jobs = $q->get_jobs('RUNNING');

  is( @$jobs, 0, "Running queue with pause/resume. No job is running." );

  $q->resume;

  sleep(1);

  my $jobs = $q->get_jobs('RUNNING');

  is( @$jobs, 1, "Running queue with pause/resume. One job is running." );
  is( $jobs->[0]->{info}->{name}, "job2", "Running queue sequential. Job 2 is running.");

}



1;
