package PaperPile::Controller::Ajax::Forms;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Data::Dumper;
use 5.010;


sub settings : Local {
  my ( $self, $c ) = @_;

  my $user_settings=$c->model('User')->settings;
  my $app_settings=$c->model('App')->settings;

  my @list1=%$user_settings;
  my @list2=%$app_settings;

  my %merged=(@list1,@list2);

  $c->stash->{success}='true';

  $c->stash->{data}={%merged};

  $c->forward('PaperPile::View::JSON');

}


1;
