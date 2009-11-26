package Paperpile::Controller::Ajax::Queue;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Paperpile::PdfExtract;

use Data::Dumper;
use File::Find;
use File::Path;
use File::Compare;
use File::Basename;
use File::stat;
use MooseX::Timestamp;
use POSIX qw(ceil floor);

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
      'eta', 'pdf'
    ]
  );

  $c->stash->{total_entries} = $total_entries;

  $c->stash->{data}     = [@data];
  $c->stash->{metaData} = {%metaData};
  $c->detach('Paperpile::View::JSON');

}

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

sub clear :Local {

  my ( $self, $c ) = @_;

  my $q = Paperpile::Queue->new();
  $q->clear;

}

sub pause :Local {

  my ( $self, $c ) = @_;

  my $q = Paperpile::Queue->new();
  $q->pause;
}

sub resume :Local {

  my ( $self, $c ) = @_;

  my $q = Paperpile::Queue->new();
  $q->resume;
}


sub get_running : Local {

  my ( $self, $c ) = @_;

  my $limit = $c->request->params->{limit};

  my $q = Paperpile::Queue->new();

  my @jobs =  @{ $q->jobs };

  my $i = 0;

  my $is_running=0;

  while ($i <= $#jobs){
    if ($jobs[$i]->status eq 'RUNNING'){
      $is_running=1;
      last;
    }
    $i++;
  }

  my $page = -1;
  my $index = -1;

  if ($is_running){
    $page = floor($i/$limit)+1;
    $index = $i % $limit;
  }

  $c->stash->{page} = $page;
  $c->stash->{index} = $index;

}


1;
