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

  my @data = ();

  my $q = Paperpile::Queue->new();

  foreach my $job ( @{ $q->jobs } ) {
    push @data, $job->as_hash;
  }

  my %metaData = (
    root   => 'data',
    id     => 'id',
    fields => [ 'id', 'title', 'type', 'status', 'progress', 'error' ]
  );


  $c->stash->{num_pending} = $q->num_pending;
  $c->stash->{num_done} = $q->num_done;
  $c->stash->{data} = [ @data ];
  $c->stash->{metaData} = {%metaData};
  $c->detach('Paperpile::View::JSON');

}





1;
