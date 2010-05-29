# Copyright 2009, 2010 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.  You should have received a
# copy of the GNU General Public License along with Paperpile.  If
# not, see http://www.gnu.org/licenses.

package Paperpile::Controller::Ajax::Queue;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;

use Data::Dumper;

sub grid : Local {

  my ( $self, $c ) = @_;

  my $start  = $c->request->params->{start}  || 0;
  my $limit  = $c->request->params->{limit}  || 0;
  my $filter = $c->request->params->{filter} || 'all';

  my @data = ();

  my $q = Paperpile::Queue->new();

  $q->update_stats;

  my $jobs;

  if ( $filter eq 'all' ) {

    $jobs = $q->get_jobs();

  } elsif ( $filter eq 'done' ) {

    $jobs = $q->get_jobs('DONE');

  } elsif ( $filter eq 'error' ) {

    $jobs = $q->get_jobs('ERROR');

  }

  foreach my $job ( @{$jobs} ) {
    my $tmp = $job->as_hash;

    $tmp->{size}       = $tmp->{info}->{size};
    $tmp->{downloaded} = $tmp->{info}->{downloaded};

    delete( $tmp->{info} );
    push @data, $tmp;

  }

  my $total_entries = scalar @data;

  my $end = ( $start + $limit - 1 );

  @data = @data[ $start .. ( ( $end > $#data ) ? $#data : $end ) ];

  my %metaData = (
    totalProperty => 'total_entries',
    root          => 'data',
    id            => 'id',
    fields        => [
      'id',              'type',    'status',  'progress', 'error',    'size',
      'downloaded',      'message', 'citekey', 'title',    'citation', 'authors',
      'authors_display', 'linkout', 'journal', 'pdf',      'doi'
    ]
  );

  $c->stash->{total_entries} = $total_entries;
  $c->stash->{data}          = [@data];
  $c->stash->{metaData}      = {%metaData};

}

sub update : Local {
  my ( $self, $c ) = @_;

  my $get_queue = $c->request->params->{get_queue};

  my $data = {};

  if ($get_queue) {
    my $q = Paperpile::Queue->new();
    $q->update_stats;
    $data->{queue} = $q->as_hash;
  }

  my $ids = $c->request->params->{ids} || [];

  if ( ref($ids) ne 'ARRAY' ) {
    $ids = [$ids];
  }

  my $jobs = {};
  my $pubs = {};

  my @pub_list = ();
  foreach my $id ( @{$ids} ) {
    my $job = Paperpile::Job->new( { id => $id } );
    if (defined $job->pub) {
      my $pub = $job->pub;
      push @pub_list, $pub;
      $jobs->{$id} = $job->as_hash;
    }
  }

  $pubs = $self->_collect_pub_data( \@pub_list, [ 'pdf', 'pdf_name', '_search_job', '_metadata_job' ] );
  $data->{jobs} = $jobs;
  $data->{pubs} = $pubs;

  $c->stash->{data} = $data;
}

## Cancel one or more jobs

sub cancel_jobs : Local {

  my ( $self, $c ) = @_;

  my $ids = $c->request->params->{ids};

  if ( ref($ids) ne 'ARRAY' ) {
    if ( $ids eq 'all' ) {
      my $q    = Paperpile::Queue->new();
      my $jobs = $q->get_jobs;
      my @arr  = map { $_->id } @$jobs;
      $ids = \@arr;
    } else {
      $ids = [$ids];
    }
  }

  my @pub_list = ();
  foreach my $id (@$ids) {
    my $job = Paperpile::Job->new( { id => $id } );
    my $pub = $job->pub;
    push @pub_list, $pub;
    $job->cancel;
  }

  my $q = Paperpile::Queue->new();
  $q->run;

  my $pubs = $self->_collect_pub_data( \@pub_list, [ 'pdf', 'pdf_name', '_search_job','_metadata_job' ] );
  my $data = {};
  $data->{pubs}      = $pubs;
  $data->{job_delta} = 1;
  $c->stash->{data}  = $data;
  $c->detach('Paperpile::View::JSON');
}

# Removes finished (successful OR failed) jobs from the queue.

sub clear_jobs : Local {

  my ( $self, $c ) = @_;
  my $q     = Paperpile::Queue->new();
  my $guids = $q->clear;

  my $pubs;
  for my $guid (@$guids) {
    $pubs->{$guid} = { _search_job => undef, _metadata_job => undef };
  }
  $c->stash->{data}->{pubs}      = $pubs;
  $c->stash->{data}->{job_delta} = 1;
}

sub remove_jobs : Local {

  my ( $self, $c ) = @_;

  my $ids = $c->request->params->{ids};

  if ( ref($ids) ne 'ARRAY' ) {
    $ids = [$ids];
  }

  my @pub_list = ();
  foreach my $id (@$ids) {
    my $job = Paperpile::Job->new( { id => $id } );
    my $pub = $job->pub;
    $pub->_search_job(undef);
    $pub->_metadata_job(undef);
    push @pub_list, $pub;
    $job->interrupt('CANCEL');
    $job->remove;
  }

  my $pubs = $self->_collect_pub_data( \@pub_list, ['_search_job','_metadata_job'] );

  my $q = Paperpile::Queue->new();
  $q->update_stats;

  my $data;
  $data->{pubs}  = $pubs;
  $data->{queue} = $q->as_hash;

  $c->stash->{data} = $data;

}

sub retry_jobs : Local {

  my ( $self, $c ) = @_;

  my $ids = $c->request->params->{ids};

  if ( ref($ids) ne 'ARRAY' ) {
    $ids = [$ids];
  }

  my $q   = Paperpile::Queue->new();
  my $dbh = Paperpile::Utils->get_queue_model->dbh;

  my @pub_list = ();
  foreach my $id (@$ids) {
    my $job = Paperpile::Job->new( { id => $id } );

    $job->reset();

    my $idq = $dbh->quote( $job->id );
    ( my $rowid ) = $dbh->selectrow_array("SELECT rowid FROM queue WHERE jobid=$idq");

    $job->_rowid($rowid);

    #$dbh->do("DELETE FROM Queue WHERE jobid=$id;");

    $q->submit($job);

    my $pub = $job->pub;
    push @pub_list, $pub;
  }

  $q->run();

  my $pubs = $self->_collect_pub_data( \@pub_list, [ '_job_id', '_search_job','_metadata_job' ] );
  my $data = {};
  $data->{pubs} = $pubs;
  $c->stash->{data} = $data;
  $c->detach('Paperpile::View::JSON');
}

sub clear : Local {

  my ( $self, $c ) = @_;

  my $q = Paperpile::Queue->new();
  $q->clear;

}

## Pauses the queue

sub pause_resume : Local {
  my ( $self, $c ) = @_;

  my $q = Paperpile::Queue->new();

  if ( $q->status eq 'PAUSED' ) {
    $q->resume;
  } else {
    $q->pause;
  }

  $c->stash->{queue}     = $q->as_hash;
  $c->stash->{job_delta} = 1;
  $c->detach('Paperpile::View::JSON');
}

# Duplicated from controller/ajax/crud.pm . Should combine somewhere.
sub _collect_pub_data {
  my ( $self, $pubs, $fields ) = @_;

  my %output = ();
  foreach my $pub (@$pubs) {
    my $hash       = $pub->as_hash;
    my $pub_fields = {};
    if ($fields) {
      map { $pub_fields->{$_} = $hash->{$_} } @$fields;
    } else {
      $pub_fields = $hash;
    }
    $output{ $hash->{guid} } = $pub_fields;
  }

  return \%output;
}

1;
