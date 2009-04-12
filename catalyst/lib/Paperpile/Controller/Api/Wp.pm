package Paperpile::Controller::Api::Wp;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Paperpile::Plugins::Import::DB;
use Data::Dumper;
use XML::Simple;
use 5.010;

# Function: ping
# Pings the status of the server and returns the version

sub ping : Local {
  my ( $self, $c ) = @_;

  my $body = XMLout( { version => $c->VERSION }, RootName => 'data', NoAttr => 1 );

  $c->response->status(200);
  $c->response->content_type('text/xml');
  $c->response->content_encoding('utf-8');
  $c->response->body($body);

}

# Function: list_styles
# List available CSL styles

sub list_styles :Local{
  my ( $self, $c ) = @_;

  my $data= {style => [ 'APA', 'Nature', 'Cell', 'Harvard' ]};

  my $body=XMLout($data, RootName =>'data');

  $c->response->status(200);
  $c->response->content_type('text/xml');
  $c->response->content_encoding('utf-8');
  $c->response->body($body);

}

# Function: search
# Searches the local database and the document mods file for citations

sub search : Local {
  my ( $self, $c ) = @_;

  my $query = $c->request->params->{query};
  my $limit = $c->request->params->{limit};
  my $docID = $c->request->params->{docID};

  ( my $db_file ) =
    $c->model('App')->dbh->selectrow_array("SELECT value FROM Settings WHERE key='user_db'");

  my $pars = {
    file  => $db_file,
    query => $query,
    name  => 'DB',
    mode  => 'FULLTEXT'
  };

  my $plugin = Paperpile::Plugins::Import::DB->new($pars);

  $plugin->connect;

  my $results = $plugin->page( 0, $limit );

  my @output = ();

  foreach my $pub (@$results) {

    my $citation = $pub->_citation_display;

    # strip html tags; probably format specifically for plugin in future
    $citation =~ s!</?\w>!!g;

    push @output, {
      id       => 'rowid_' . $pub->_rowid,
      title    => $pub->title,
      authors  => $pub->_authors_display,
      citation => $citation,
      };
  }

  my $data = { result => [@output] };

  my $body = XMLout( $data, RootName => 'data', NoAttr => 1 );

  $c->response->status(200);
  $c->response->content_type('text/xml');
  $c->response->content_encoding('utf-8');
  $c->response->body($body);

}

1;


