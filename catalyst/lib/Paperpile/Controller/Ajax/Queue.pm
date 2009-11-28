package Paperpile::Controller::Ajax::Queue;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;

use Data::Dumper;

sub grid : Local {

  my ( $self, $c ) = @_;

  my $start = $c->request->params->{start};
  my $limit = $c->request->params->{limit};

  my @data = ();

  my $q = Paperpile::Queue->new();

  $q->update_stats;

  foreach my $job ( @{ $q->get_jobs } ) {
    my $tmp = $job->as_hash;
    delete($tmp->{info});
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
      'id',    'type',     'status',  'progress',    'error',    'citekey',
      'title', 'citation', 'authors', 'num_pending', 'num_done', 'queue_status',
      'eta', 'pdf', 'doi'
    ]
  );

  $c->stash->{total_entries} = $total_entries;

  $c->stash->{data}     = [@data];
  $c->stash->{metaData} = {%metaData};
  $c->detach('Paperpile::View::JSON');

}

## Returns job information for one or more job ids.

sub jobs : Local {

  my ( $self, $c ) = @_;

  my $ids = $c->request->params->{ids};

  if (ref($ids) ne 'ARRAY'){
    $ids = [$ids];
  }

  my $data={};

  foreach my $id (@$ids){
    my $job = Paperpile::Job->new({id=>$id});

    $data->{$id}=$job->as_hash;
  }

  $c->stash->{data} = $data;

}

## Cancel one or more jobs

sub cancel_jobs : Local {

  my ( $self, $c ) = @_;

  my $ids = $c->request->params->{ids};

  if (ref($ids) ne 'ARRAY'){
    $ids = [$ids];
  }

  foreach my $id (@$ids){
    my $job = Paperpile::Job->new({id=>$id});

    $job->interrupt('CANCEL');

    print STDERR Dumper($job);

    $job->save;

  }
}

## Clears the queue

sub clear :Local {

  my ( $self, $c ) = @_;

  my $q = Paperpile::Queue->new();
  $q->clear;

}

## Pauses the queue

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


1;
