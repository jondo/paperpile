package Paperpile::Controller::Ajax::Queue;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Paperpile::PdfExtract;
use Data::Dumper;
use 5.010;
use File::Find;
use File::Path;
use File::Compare;
use File::Basename;
use File::stat;
use MooseX::Timestamp;

sub grid : Local {

  my ( $self, $c ) = @_;

  my $sort = $c->request->params->{sort};
  my $dir = $c->request->params->{dir};

  my @data = ();

  my $q = Paperpile::Queue->new();

  $q->_dump;

  foreach my $job ( @{ $q->jobs } ) {
    push @data, $job->as_hash;

    # For simplicity, simply push info for complete queue to each item
    # in the list
    $data[$#data]->{num_pending}  = $q->num_pending;
    $data[$#data]->{num_done}     = $q->num_done;
    $data[$#data]->{queue_status} = $q->status;
    $data[$#data]->{eta} = $q->eta;

    print STDERR $q->num_pending, "   ", $q->num_done, "\n";

  }



  if ($sort){
    if ($sort eq 'title'){
      my $field ='title';

      if ($dir eq 'ASC'){
        @data = sort {$a->{title} cmp $b->{title}} @data;
      } else {
        @data = sort {$b->{title} cmp $a->{title}} @data;
      }
    }

    if ($sort eq 'title'){
      if ($dir eq 'ASC'){
        @data = sort {$a->{title} cmp $b->{title}} @data;
      } else {
        @data = sort {$b->{title} cmp $a->{title}} @data;
      }
    }

  }


  my %metaData = (
    root   => 'data',
    id     => 'id',
    fields => [
      'id', 'type', 'status', 'progress', 'error', 'citekey', 'title','citation','authors',
      'num_pending', 'num_done', 'queue_status', 'eta'
    ]
  );

  $c->stash->{data}     = [@data];
  $c->stash->{metaData} = {%metaData};
  $c->detach('Paperpile::View::JSON');

}

sub clear :Local {

  my ( $self, $c ) = @_;

  my $q = Paperpile::Queue->new();
  $q->clear;

}





1;
