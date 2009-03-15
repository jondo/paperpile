package Paperpile::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';

__PACKAGE__->config->{namespace} = '';


sub index : Path : Args(0) {
  my ( $self, $c ) = @_;

  # Add dynamically all *js files in the  plugins directory
  my @list=glob($c->path_to('root/js/search/plugins')."/*js");

  my @plugins=();

  foreach my $plugin (@list){
    my ($volume,$directories,$file) = File::Spec->splitpath( $plugin );
    push @plugins, "search/plugins/$file";
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


sub default : Path {
  my ( $self, $c ) = @_;
  $c->response->body('Page not found');
  $c->response->status(404);

}


sub end : ActionClass('RenderView') {
}


1;
