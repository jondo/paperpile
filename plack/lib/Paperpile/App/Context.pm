package Paperpile::App::Context;

use Mouse;
use Paperpile;
use Paperpile::Utils;

has 'request' => ( is => 'rw' );
has 'app'     => ( is => 'rw' );
has 'stash'   => ( is => 'rw', default => sub {return {};} );

sub config {

  my ($self) = @_;

  return Paperpile->config;

}

sub model {

  my ( $self, $name ) = @_;

  return Paperpile::Utils->get_model($name);

}

sub path_to {

  my $self = shift;

  return Paperpile->path_to(@_);

}

sub params {

  my $self = shift;

  return $self->request->parameters;

}



1;
