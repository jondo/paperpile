package Paperpile::Controller::Screens;

use strict;
use warnings;
use parent 'Catalyst::Controller';


sub patterns : Local {
  my ( $self, $c ) = @_;
  $c->stash->{template} = 'patterns.mas';
  $c->forward('Paperpile::View::Mason');
}

1;
