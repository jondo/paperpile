package Test::Paperpile::Queue;

use strict;
use Test::More;
use Data::Dumper;
use File::Copy;

use Paperpile;


use base 'Test::Paperpile';

sub class { 'Paperpile::Queue' }

sub startup : Tests(startup => 1) {
  my ($self) = @_;

  # Start with a fresh copy of queue.db
  copy( Paperpile->path_to('db/queue.db'), Paperpile->config->{'queue_db'} );

  use_ok $self->class;

}

sub basic : Tests(10) {
  my ($self) = @_;

  my $q = Paperpile::Queue->new;

  isa_ok( $q->dbh, 'DBI::db', "get db handle" );

  $q->max_running(10);
  $q->save;
  $q->max_running(0);
  $q->restore;

  is( $q->max_running, 10, "Save restore object to/from database" );

  my $job1 = Paperpile::Job->new( job_type => "TEST_JOB1" );
  my $job2 = Paperpile::Job->new( job_type => "TEST_JOB1" );
  my $job3 = Paperpile::Job->new( job_type => "TEST_JOB1" );

  $job1->update_info("name", "job1");
  $job2->update_info("name", "job2");
  $job3->update_info("name", "job3");

  $q->submit($job1);

  ( my $count ) = $q->dbh->selectrow_array("SELECT count(*) FROM Queue;");

  is( $count, 1, "Submit job1 to queue. Count is 1." );

  $q->submit( [ $job2, $job3 ] );

  ( $count ) = $q->dbh->selectrow_array("SELECT count(*) FROM Queue;");

  is( $count, 3, "Submit job2 and job3 to queue. Count is 3." );

  my $jobs = $q->get_jobs;

  is( @$jobs, 3, "Get jobs via get_jobs. Count is ok." );

  is( $jobs->[0]->info->{name}, "job1", "Get jobs via get_jobs. Job 1 is correct." );
  is( $jobs->[1]->info->{name}, "job2", "Get jobs via get_jobs. Job 2 is correct." );
  is( $jobs->[2]->info->{name}, "job3", "Get jobs via get_jobs. Job 3 is correct." );





}




1;
