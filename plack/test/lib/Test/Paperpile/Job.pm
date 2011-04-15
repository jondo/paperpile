package Test::Paperpile::Job;

use strict;
use Test::More;
use Data::Dumper;
use JSON;
use utf8;

use Paperpile;
use Paperpile::App;
use Paperpile::Queue;

use base 'Test::Paperpile';

sub class { 'Paperpile::Job' }

sub startup : Tests(startup => 1) {
  my ($self) = @_;

  use_ok $self->class;

}

sub save_store : Tests(14) {

  my ($self) = @_;

  ## Create new job from scratch

  my $job = $self->class->new( job_type => "TEST_JOB1" );

  my $id = $job->id;

  like( $id, qr/[0-9A-F]{32}/, "Creating new job object from scratch." );

  ok( -e $job->_freeze_file, "Job file is present." );

  ## Create new job from dump

  $job = $self->class->new( id => $id );

  is( $id, $job->id, "Creating new job object from freeze dump." );

  ## Update job info via different functions

  $job->{info}->{test} = "some text 私はガラス";
  $job->save;
  $job->{info}->{test} = undef;
  $job->restore;
  is( $job->{info}->{test}, "some text 私はガラス", "Saving/restoring object to/from freeze/thaw dump" );

  ok( -e $job->_json_file, "JSON file is present." );

  open( IN, "<".$job->_json_file );
  my $string = '';
  $string .= $_ while (<IN>);
  my $data = decode_json($string);

  is( $data->{info}->{test}, "some text 私はガラス", "Saving/restoring object to/from JSON file" );

  $job->update_info( "test", "456" );
  $job->{info}->{test} = undef;
  $job->restore;
  is( $job->{info}->{test}, "456", "Updating info" );

  open( IN, "<".$job->_json_file );
  $string = '';
  $string .= $_ while (<IN>);
  $data = decode_json($string);

  is( $data->{info}->{test}, "456", "Saving/restoring object to/from JSON file" );

  ## Update job status

  $job->update_status("DONE");
  is( $job->{status}, "DONE", "Updating status. Updated in object." );
  $job->status("PENDING");
  $job->restore;
  is( $job->{status}, "DONE", "Updating status. Updated on disk." );

  $job->status("PENDING");

  my $q = Paperpile::Queue->new();
  $q->clear_all;

  $job->queued(1);
  $q->submit($job);
  $job->update_status("DONE");
  $q->update_stats;

  is( $q->num_done, 1, "Updating status for queued job. Updated in database." );

  ## Deleting jobs

  $job->queued(0);
  $job->remove;
  ok( !( -e $job->_freeze_file ), "Deleting job. Freeze file is removed." );
  ok( !( -e $job->_json_file ),   "Deleting job. JSON file is removed." );

  $job->queued(1);
  $job->remove;
  $q->update_stats;
  is( $q->num_done, 0, "Deleting queued job. Removed from database." );

}

sub run_cancel : Tests(23) {
  my ($self) = @_;

  ## TEST_JOB1 normal job with several stages

  my $job = $self->class->new( job_type => "TEST_JOB1" );

  is( $job->{pid}, -1, "Before running the job pid is -1." );

  $job->run;

  sleep(1);

  $job->restore;
  is( $job->{status},      "RUNNING", "Test job 1. Status is RUNNING" );
  is( $job->{info}->{msg}, "Step1",   "Test job 1. Msg is updated" );
  like( $job->{pid}, qr/\d+/, "Test job 1. PID is set" );
  cmp_ok( $job->{pid}, '!=', $$, "Test job 1. PID is different from main process." );

  sleep(2);

  $job->restore;
  is( $job->{status},      "RUNNING", "Test job 1. Status is still RUNNING" );
  is( $job->{info}->{msg}, "Step2",   "Test job 1. Msg is updated again" );

  sleep(2);

  $job->restore;
  is( $job->{status},      "DONE",  "Test job 1. Status is DONE" );
  is( $job->{info}->{msg}, "Done.", "Test job 1. Msg is updated when done" );
  is( $job->{pid},         -1,      "Job pid is -1 after job finished" );
  is( $job->{duration},    4,       "Job duration is correct." );

  $job->remove;

  ## TEST_JOB3: job that throws exception

  my $job = $self->class->new( job_type => "TEST_JOB3" );
  $job->run;
  sleep(1);
  $job->restore;
  is( $job->{status}, "ERROR",          "Test job 2. Status is ERROR" );
  is( $job->{error},  "Test exception", "Test job 2. Error field is set." );
  is( $job->{pid},    -1,               "Job pid is -1 after job finished" );

  $job->remove;

  ## TEST_JOB4: job that dies from an unknown error

  my $job = $self->class->new( job_type => "TEST_JOB4" );
  $job->run;

  sleep(1);

  $job->restore;
  is( $job->{status}, "ERROR", "Test job 3. Status is ERROR" );
  like( $job->{error}, qr/Unknown exception/, "Test job 3. Error field is set." );
  is( $job->{pid}, -1, "Job pid is -1 after job finished" );

  $job->remove;

  ## CANCEL pending job

  my $job = $self->class->new( job_type => "TEST_JOB1" );

  is( $job->{status}, "PENDING", "Cancel pending job. Status is PENDING" );
  $job->cancel;

  sleep(1);

  $job->restore;
  is( $job->{status}, "ERROR", "Cancel pending job. Status is ERROR" );
  like( $job->{error}, qr/canceled/, "Cancel pending job. Error field is set." );

  $job->remove;

  ## CANCEL running job

  my $job = $self->class->new( job_type => "TEST_JOB1" );
  is( $job->{status}, "PENDING", "Cancel running job. Status is PENDING" );

  sleep(1);

  $job->cancel;

  sleep(1);

  $job->restore;
  is( $job->{status}, "ERROR", "Cancel running job. Status is ERROR" );
  like( $job->{error}, qr/canceled/, "Cancel running job. Error field is set." );

  $job->remove;

}







1;
