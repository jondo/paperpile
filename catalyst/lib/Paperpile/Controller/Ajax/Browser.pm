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


  # Note: We are initiating this session via the bookmarklet without going
  # through the normal startup process.
  $c->session->{library_db} = $c->config->{'user_settings'}->{library_db};

  my $url     = $c->request->params->{url};
  my $content = $c->request->params->{content};

  my $plugin = Paperpile::Plugins::Import::PubMed->new();

  my $id = int(rand(1000000));

  my $job = {type=>'WEB_IMPORT',
             status => 'RUNNING'
            };

  my $queue = Paperpile::Utils->retrieve('queue');

  $queue->{$id} = $job;

  Paperpile::Utils->store('queue', $queue);

  my $pubs = $plugin->web_lookup( $url, $content );

  $c->model('Library')->create_pubs($pubs);

  $queue = Paperpile::Utils->retrieve('queue');

  $queue->{$id}->{status} = 'DONE';
  $queue->{$id}->{callback} = {notify => 'Imported new entry',
                               updatedb => 1,
                              };

  Paperpile::Utils->store('queue', $queue);


}


sub status : Local {

  my ( $self, $c ) = @_;

  my $lookup_id     = $c->request->params->{lookup_id};

  $c->stash->{data}=$c->session->{web_lookup}->{$lookup_id};


}




1;
