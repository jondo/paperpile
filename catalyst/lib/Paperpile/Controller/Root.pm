package Paperpile::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';

__PACKAGE__->config->{namespace} = '';


sub index : Path : Args(0) {
  my ( $self, $c ) = @_;

  # Add dynamically all *js files in the  plugins directory
  my @list=glob($c->path_to('root/js/search/plugins')."/*js");
  push @list, glob($c->path_to('root/js/export/plugins')."/*js");

  my @plugins=();

  foreach my $plugin (@list){
    my ($volume,$directories,$file) = File::Spec->splitpath( $plugin );
    if ($directories =~/search/){
      push @plugins, "search/plugins/$file";
    } else {
      push @plugins, "export/plugins/$file";
    }

  }
  $c->stash->{plugins}=[@plugins];

  $c->stash->{template} = 'main.mas';
  $c->forward('Paperpile::View::Mason');
}

sub scratch : Local {
  my ( $self, $c ) = @_;
  $c->stash->{template} = 'scratch.mas';
  $c->forward('Paperpile::View::Mason');
}

sub scratch2 : Local {
  my ( $self, $c ) = @_;
  $c->stash->{template} = 'scratch2.mas';
  $c->forward('Paperpile::View::Mason');
}

sub default : Path {
  my ( $self, $c ) = @_;
  $c->response->body('Page not found');
  $c->response->status(404);

}


sub end : Private {
  my ( $self, $c ) = @_;

  if ( scalar @{ $c->error } ) {
    $c->response->status(500);
    $c->stash->{errors}   = $c->error;
    $c->forward('Paperpile::View::JSON');

    foreach my $error (@{$c->error}){
      $c->log->error($error);
    }

    $c->error(0);
  }

  return 1 if $c->response->status =~ /^3\d\d$/;
  return 1 if $c->response->body;

  $c->forward('Paperpile::View::JSON');

}



#sub end : ActionClass('RenderView') {
#}


1;
