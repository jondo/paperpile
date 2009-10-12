package Paperpile::Queue;

use Moose;
use Moose::Util::TypeConstraints;

use Paperpile::Utils;
use Paperpile::Exceptions;
use Paperpile::Job;
use Data::Dumper;
use Time::Duration;
use File::Temp qw/ tempfile /;
use JSON;
use 5.010;

enum 'Status' => qw(RUNNING WAITING PAUSED);
has 'jobs' => ( is => 'rw', isa => 'ArrayRef[Paperpile::Job]', default => sub { [] } );

has 'status' => ( is => 'rw', isa => 'Status', default => 'WAITING', trigger => sub {my $self = shift; $self->save;} );
has eta         => ( is => 'rw', isa => 'Str', default => "--:--:--" );
has num_pending => ( is => 'rw', isa => 'Int', default => 0 );
has num_done    => ( is => 'rw', isa => 'Int', default => 0 );

sub BUILD {
  my ( $self, $params ) = @_;
  $self->restore;
}

sub add_job {

  my ( $self, $job ) = @_;

  push @{ $self->jobs }, $job;

}

sub save {

  my $self = shift;

  Paperpile::Utils->store( 'queue', $self );

}

sub update_job {

  my ( $self, $job ) = @_;

  foreach my $i ( 0 .. @{ $self->jobs } - 1 ) {

    next if $self->jobs->[$i]->id ne $job->id;

    $self->jobs->[$i] = $job;

  }

  $self->save;

}


sub restore {

  my $self = shift;

  my $stored = Paperpile::Utils->retrieve('queue');

  return if not $stored;

  foreach my $key ( $self->meta->get_attribute_list ) {
    $self->$key( $stored->$key );
  }

  $self->_update_stats;

}

sub pause {

  my $self = shift;

  $self->restore;
  $self->status('PAUSED');
  $self->save;

}

sub resume {

  my $self = shift;

  $self->restore;
  $self->status('RUNNING');
  $self->save;

}


sub run {

  my $self = shift;

  # If queue is already running or paused don't start a new process
  if ($self->status ne 'WAITING'){
    return;
  } else {

    $self->status('RUNNING');
    $self->save;

    while (1) {

      $self->restore;

      if ($self->status eq 'PAUSED'){
        sleep(1);
        next;
      }

      my $curr_job = undef;

      foreach my $job ( @{ $self->jobs } ) {

        if ( $job->status eq 'PENDING' ) {
          $curr_job = $job;
          last;
        }
      }

      last if not $curr_job;
      $curr_job->run;
    }

    $self->status('WAITING');
  }

}

sub clear {

  my $self = shift;

  if ($self->status eq 'WAITING'){
    $self->jobs([]);
  }

  $self->_update_stats;
  $self->save;

}

sub _update_stats {

  my $self = shift;

  my $num_pending = 0;
  my $num_done    = 0;

  my $sum_duration = 0;

  foreach my $job ( @{ $self->jobs } ) {
    if ( $job->status eq 'PENDING' or $job->status eq 'RUNNING' ) {
      $num_pending++;
    } else {
      $sum_duration+=$job->duration;
      $num_done++;
    }
  }

  if ($num_done>=1){
    my $seconds_left = int($sum_duration/$num_done*$num_pending);
    $self->eta(Time::Duration::duration($seconds_left));
  } else {
    $self->eta('');
  }

  $self->num_pending($num_pending);
  $self->num_done($num_done);

}

# Debugging

sub _dump {

  my $self = shift;

  foreach my $i ( 0 .. @{ $self->jobs } - 1 ) {

    my $j = $self->jobs->[$i];

    print STDERR join( "  ", $j->id, $j->status, $j->progress, $j->error ), "\n";

  }

}

1;
