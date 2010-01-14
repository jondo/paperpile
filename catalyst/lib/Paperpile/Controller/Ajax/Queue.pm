package Paperpile::Controller::Ajax::Queue;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;

use Data::Dumper;

sub grid : Local {

  my ( $self, $c ) = @_;

  my $start = $c->request->params->{start};
  $start = 0 unless (defined $start);
  my $limit = $c->request->params->{limit};
  $limit = 1000 unless (defined $limit);

  my $hide_success = $c->request->params->{hide_success};
  $hide_success = 0 unless (defined $hide_success);

  my @data = ();

  my $q = Paperpile::Queue->new();

  $q->update_stats;

  my $jobs;
  if ($hide_success) {
    $jobs = $q->get_jobs(['PENDING','RUNNING','ERROR']);
  } else {
    $jobs = $q->get_jobs();
  }

  foreach my $job ( @{$jobs} ) {
    my $tmp = $job->as_hash;
    #delete($tmp->{info});
    push @data, $tmp;

    # For simplicity, simply push info for complete queue to each item
    # in the list
    $data[$#data]->{num_pending}  = $q->num_pending;
    $data[$#data]->{num_done}     = $q->num_done;
    $data[$#data]->{queue_status} = $q->status;
    $data[$#data]->{eta}          = $q->eta;
  }

  my $total_entries = scalar @data;

  my $end = ( $start + $limit - 1 );

  @data = @data[ $start .. ( ( $end > $#data ) ? $#data : $end ) ];

  my %metaData = (
    totalProperty => 'total_entries',
    root          => 'data',
    id            => 'id',
    fields        => [
      'id',    'type',     'status',  'progress',    'error',    'info', 'message', 'citekey',
      'title', 'citation', 'authors', 'num_pending', 'num_done', 'queue_status',
      'eta', 'pdf', 'doi'
    ]
  );

  $c->stash->{total_entries} = $total_entries;

  $c->stash->{data}     = [@data];
  $c->stash->{metaData} = {%metaData};
  $c->detach('Paperpile::View::JSON');

}

sub overview: Local {
  my ( $self, $c ) = @_;

  my $start = $c->request->params->{start};
  my $limit = $c->request->params->{limit};

  my $q = Paperpile::Queue->new();
  $q->update_stats;

  $c->stash->{queue} = $q->as_hash;
  $c->detach('Paperpile::View::JSON');
}


## Returns job information for one or more job ids.

sub jobs : Local {

  my ( $self, $c ) = @_;

#  print STDERR "REQUEST RECEIVED FOR JOBS LIST\n";

  my $ids = $c->request->params->{ids} || [];
  my $ignore_ids = $c->request->params->{ignore_ids} || '';

  my @ignore_arr = split(',',$ignore_ids);
  my %ignore_hash;
  map {$ignore_hash{$_}=1} @ignore_arr;

  if (ref($ids) ne 'ARRAY'){
    if ($ids eq 'active_jobs') {
      my @js = ();
      my $q = Paperpile::Queue->new();
      foreach my $job ( @{ $q->get_jobs('RUNNING') } ) {
	push @js,$job->id;
      }
      foreach my $job ( @{ $q->get_jobs('DONE') } ) {
	push @js,$job->id;
      }
      foreach my $job ( @{ $q->get_jobs('ERROR') } ) {
	push @js,$job->id;
      }
      $ids = [@js];

    } else {
      $ids = [$ids];
    }
  }

  # Remove 'ignored' IDs from the list.
  my @filtered_ids = ();
  foreach my $id (@$ids) {
      push @filtered_ids, $id unless defined $ignore_hash{$id};
  }
  $ids = \@filtered_ids;
  print STDERR join(",",@$ids)."\n";

  my $jobs={};
  my $pubs={};

  my @pub_list = ();
  foreach my $id (@{$ids}){
    my $job = Paperpile::Job->new({id=>$id});
    my $status = $job->status;

    my $pub = $job->pub;
    push @pub_list, $pub;
    $jobs->{$id} = $job->as_hash;
  }

  $pubs = $self->_collect_pub_data(\@pub_list,['pdf','_search_job','_search_job_progress','_search_job_msg','_search_job_error','_search_job_status']);
  my $data={};
  $data->{jobs} = $jobs;
  $data->{pubs} = $pubs;
  my $q = Paperpile::Queue->new();
  $data->{queue} = $q->as_hash;

  $c->stash->{data} = $data;
  $c->detach('Paperpile::View::JSON');
}

## Cancel one or more jobs

sub cancel_jobs : Local {

  my ( $self, $c ) = @_;

  my $ids = $c->request->params->{ids};

  if (ref($ids) ne 'ARRAY'){
    if ($ids eq 'all') {
      my $q = Paperpile::Queue->new();
      my $jobs = $q->get_jobs;
      my @arr = map {$_->id} @$jobs;
      $ids = \@arr;
    } else {
      $ids = [$ids];
    }
  }

  my @pub_list = ();
  foreach my $id (@$ids){
    my $job = Paperpile::Job->new({id=>$id});
    my $pub = $job->pub;
    push @pub_list, $pub;
    $job->cancel;
  }

  my $q = Paperpile::Queue->new();
  $q->run;

  my $pubs = $self->_collect_pub_data(\@pub_list,['pdf','_search_job','_search_job_progress','_search_job_msg','_search_job_error']);
  my $data={};
  $data->{pubs} = $pubs;
  $data->{job_delta} = 1;
  $c->stash->{data} = $data;
  $c->detach('Paperpile::View::JSON');
}

# Removes finished (successful OR failed) jobs from the queue.

sub clean_jobs : Local {

  my ( $self, $c ) = @_;

  my $ids = $c->request->params->{ids};

  if (ref($ids) ne 'ARRAY'){
    if ($ids eq 'all') {
      my $q = Paperpile::Queue->new();
      my $jobs = $q->get_jobs;
      my @arr = map {$_->id} @{$jobs};
      $ids = \@arr;
    } else {
      $ids = [$ids];
    }
  }

  foreach my $id (@$ids){
    my $job = Paperpile::Job->new({id=>$id});

    if ($job->status eq 'DONE') {
	$job->remove;
    }

    # Consider "canceled" jobs for cleaning too.
    if ($job->status eq 'ERROR' && $job->error =~ /cancel/i) {
	$job->remove;
    }
  }

  $c->stash->{job_delta} = 1;
  $c->detach('Paperpile::View::JSON');
}


sub remove_jobs : Local {

  my ( $self, $c ) = @_;

  my $ids = $c->request->params->{ids};

  if (ref($ids) ne 'ARRAY'){
    $ids = [$ids];
  }

  my @pub_list = ();
  foreach my $id (@$ids){
    my $job = Paperpile::Job->new({id=>$id});
    my $pub = $job->pub;
    print STDERR "PUB PUB PUB: $pub\n";
    push @pub_list, $pub;

    $job->interrupt('CANCEL');
    $job->remove;
  }

  my $pubs = $self->_collect_pub_data(\@pub_list,['_job_id','_search_job','_search_job_progress','_search_job_msg','_search_job_error']);
  my $data={};
  $data->{pubs} = $pubs;
  $c->stash->{data} = $data;
  $c->detach('Paperpile::View::JSON');

}

sub retry_jobs: Local {

  my ( $self, $c ) = @_;

  my $ids = $c->request->params->{ids};

  if (ref($ids) ne 'ARRAY'){
    $ids = [$ids];
  }

  my @pub_list = ();
  foreach my $id (@$ids){
    my $job = Paperpile::Job->new({id=>$id});

    $job->reset();

    my $q = Paperpile::Queue->new();
    my $dbh = Paperpile::Utils->get_queue_model->dbh;
    my $id = $dbh->quote( $job->id );
    $dbh->do("DELETE FROM Queue WHERE jobid=$id;");

    $q->submit($job);

    my $pub = $job->pub;
    push @pub_list, $pub;    
  }

  my $q = Paperpile::Queue->new();
  $q->run();

  my $pubs = $self->_collect_pub_data(\@pub_list,['_job_id','_search_job','_search_job_progress','_search_job_msg','_search_job_error']);
  my $data={};
  $data->{pubs} = $pubs;
  $c->stash->{data} = $data;
  $c->detach('Paperpile::View::JSON');
}

sub clear :Local {

  my ( $self, $c ) = @_;

  my $q = Paperpile::Queue->new();
  $q->clear;

}

## Pauses the queue

sub pause_resume :Local {
  my ( $self, $c) = @_;
  
  my $q = Paperpile::Queue->new();

  if ($q->status eq 'PAUSED') {
      $q->resume;
  } else {
      $q->pause;
  }

  $c->stash->{queue} = $q->as_hash;
  $c->stash->{job_delta} = 1;
  $c->detach('Paperpile::View::JSON');
}

sub pause :Local {

  my ( $self, $c ) = @_;

  my $q = Paperpile::Queue->new();
  $q->pause;
}

## Starts queue again

sub resume :Local {

  my ( $self, $c ) = @_;

  my $q = Paperpile::Queue->new();
  $q->resume;
}

# Duplicated from controller/ajax/crud.pm . Should combine somewhere.
sub _collect_pub_data {
  my ( $self, $pubs, $fields ) = @_;

  my %output = ();
  foreach my $pub (@$pubs) {
    print STDERR " --> $pub\n";
    my $hash = $pub->as_hash;
    my $pub_fields = { };
    if ($fields) {
      map {$pub_fields->{$_} = $hash->{$_}} @$fields;
    } else {
      $pub_fields = $hash;
    }
    $output{ $hash->{sha1} } = $pub_fields;
  }
  
  return \%output;
}

1;
