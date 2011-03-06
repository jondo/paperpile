package Paperpile::App::Context;

use Mouse;

has 'request' => ( is => 'rw' );
has 'app'     => ( is => 'rw' );
has 'stash'   => ( is => 'rw', default => sub {return {};} );

sub config {

  my ($self) = @_;

  return $self->app->config;

}

sub model {

  my ( $self, $name ) = @_;

  return $self->app->get_model($name);

}

sub path_to {

  my $self = shift;

  return $self->app->path_to(@_);

}

sub params {

  my $self = shift;

  return $self->request->parameters;

}



1;
