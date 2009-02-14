package PaperPile::Controller::Ajax::Files;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Data::Dumper;
use 5.010;

sub get : Local {
  my ( $self, $c ) = @_;

  my @data=({text=>"b",
             iconcls=>"folder",
             disabled=>"false",
             leaf=>"false"},
           );

  $c->stash->{tree} = [@data];

  $c->forward('PaperPile::View::JSON::Tree');

}


1;
