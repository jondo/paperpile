package Paperpile::Controller::Ajax::Forms;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Data::Dumper;
use 5.010;


sub settings : Local {
  my ( $self, $c ) = @_;

  my $params=$c->request->params;

  my $user_settings=$c->model('User')->settings;
  my $app_settings=$c->model('App')->settings;

  if ($params->{action} eq 'LOAD'){

    my @list1=%$user_settings;
    my @list2=%$app_settings;

    my %merged=(@list1,@list2);

    $c->stash->{success}='true';

    $c->stash->{data}={%merged};

    $c->forward('Paperpile::View::JSON');

  }

  if ($params->{action} eq 'SUBMIT'){

    foreach my $key (keys %$params){

      # Check if user or app setting, and only update if changed
      if (exists $user_settings->{$key}){
        if ($user_settings->{$key} ne $params->{$key}){
          $c->model('User')->set_setting($key,$params->{$key});
        }
      }
      if (exists $app_settings->{$key}){
        if ($app_settings->{$key} ne $params->{$key}){
          $c->model('App')->set_setting($key,$params->{$key});
        }
      }
    }

    $c->stash->{success}='true';
    $c->stash->{msg}='Settings saved';
    $c->forward('Paperpile::View::JSON');

  }
}

sub  pub_edit : Local {
  my ( $self, $c ) = @_;






}


1;
