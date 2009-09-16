package Paperpile::Controller::Ajax::Browser;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Paperpile::Utils;
use Paperpile::Plugins::Import::PubMed;
use Data::Dumper;
use File::Spec;
use File::Path;
use File::Copy;
use Paperpile::Exceptions;
use MooseX::Timestamp;
use 5.010;

sub lookup : Local {

  my ( $self, $c ) = @_;

  my $url     = $c->request->params->{url};
  my $content = $c->request->params->{content};

  my $plugin = Paperpile::Plugins::Import::PubMed->new();

  my $pubs = $plugin->web_lookup( $url, $content );

  my $lookup_id = int( rand(1000000) );

  $c->stash->{lookup_id} = $lookup_id;

  $c->session->{web_lookup} = {
    $lookup_id => {
      pub    => $pubs->[0]->as_hash,
      status => 'REFERENCE_LOOKUP'
    }
  };

  $c->stash->{template} = 'screens/browser_lookup.mas';
  $c->forward('Paperpile::View::Mason');
}


sub status : Local {

  my ( $self, $c ) = @_;

  my $lookup_id     = $c->request->params->{lookup_id};

  $c->stash->{data}=$c->session->{web_lookup}->{$lookup_id};


}




1;
