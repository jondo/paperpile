package Paperpile::Queue;

use Moose;
use Moose::Util::TypeConstraints;

use Paperpile::Utils;
use Paperpile::Exceptions;
use Paperpile::Job;
use Data::Dumper;
use File::Temp qw/ tempfile /;
use JSON;
use 5.010;

enum 'Status' => qw(RUNNING WAITING DONE);
has 'jobs'  => ( is => 'rw', isa => 'ArrayRef[Paperpile::Job]', default => sub { [] });
has 'status' => ( is => 'rw', isa => 'Status', default=>'WAITING' );


sub BUILD {
  my ( $self, $params ) = @_;
  $self->restore;
}


sub add_job {

  my ($self, $job) = @_;

  push @{$self->jobs}, $job;


}

sub save {

  my $self = shift;

  Paperpile::Utils->store('queue', $self);

}


sub update_job {

  my ($self, $job) = @_;

  foreach my $i (0..@{$self->jobs}-1){

    next if $self->jobs->[$i]->id ne $job->id;

    $self->jobs->[$i] = $job;

  }

  $self->save;

}

sub restore {

  my $self = shift;

  my $stored= Paperpile::Utils->retrieve('queue');

  return if not $stored;

  foreach my $key ( $self->meta->get_attribute_list ) {
    $self->$key($stored->$key);
  }

}

sub run {

  my $self = shift;

  $self->status('RUNNING');

  while (1){

    my $curr_job = undef;

    foreach my $job (@{$self->jobs}){

      if ($job->status eq 'PENDING'){
        $curr_job = $job;
        last;
      }
    }

    last if not $curr_job;
    $curr_job->run;

  }

  $self->status('DONE');

}


# Debugging

sub _dump {

  my $self = shift;

  foreach my $i (0..@{$self->jobs}-1){

    my $j = $self->jobs->[$i];

    print STDERR join ("  ", $j->id, $j->status, $j->progress, $j->error), "\n";


  }

}



1;
