package Plack::Handler::Custom;
use strict;

use parent qw( Paperpile::Server );

sub new {
  my ( $class, %args ) = @_;
  bless {%args}, $class;
}

sub run {
  my ( $self, $app ) = @_;
  $self->_server->run($app);
}

sub _server {
  my $self = shift;
  Paperpile::Server->new(%$self);
}

1;

