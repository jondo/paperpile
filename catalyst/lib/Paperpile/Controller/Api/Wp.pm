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

  my $body = XMLout( { version => $c->VERSION }, RootName => 'xml', NoAttr => 1 );

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

  my $body=XMLout($data, RootName =>'xml');

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

  my $body = XMLout( $data, RootName => 'xml', NoAttr => 1 );

  $c->response->status(200);
  $c->response->content_type('text/xml');
  $c->response->content_encoding('utf-8');
  $c->response->body($body);

}

# Function: search
# Searches the local database and the document mods file for citations

sub format_citations : Local {
  my ( $self, $c ) = @_;

  # get xml data from post body
  my $input = XMLin( $c->request->body, ForceArray => [ 'citation', 'item' ] );

  # get list of list with ids
  my @id_list = ();
  my @query   = ();
  foreach my $citation ( @{ $input->{citations}->{citation} } ) {
    push @id_list, $citation->{item};
    foreach my $item ( @{ $citation->{item} } ) {
      $item =~ s/rowid_//;
      push @query, "rowid=$item";
    }
  }

  # We explicitely connect to the user database
  ( my $db_file ) =
    $c->model('App')->dbh->selectrow_array("SELECT value FROM Settings WHERE key='user_db'");
  my $model = Paperpile::Model::User->new();
  $model->set_dsn( "dbi:SQLite:" . $db_file );

  # We get all entries for the required ids
  my $results = $model->standard_search( join( ' or ', @query ) );

  # Quick and dirty way to get citations and references, will be replaced by the CSL functions
  my %citations  = ();
  my %references = ();

  foreach my $pub (@$results) {
    my $id   = $pub->_rowid;
    my $name = $pub->authors;
    $name =~ s/(\w+).*/$1/;
    my $citation = $pub->_citation_display;
    $citation =~ s!</?\w>!!g;
    $citations{$id}  = "$name et al., " . $pub->year;
    $references{$id} = $pub->_authors_display . ". " . $pub->title ." ". $citation;
  }

  # Put together output format to dump to XML
  my %output;
  $output{citations}=[];
  $output{bibliography}='';
  foreach my $citation (@id_list){
    my @items=();
    foreach my $item (@$citation){
      push @items, $citations{$item};
      $output{bibliography}.=$references{$item}."\n\n";
    }
    push @{$output{citations}}, "(".join(', ',@items).")";
  }

  # Dummy
  $output{mods}='AAAAB3NzaC1yc2EAAAABIwAAAQEApxtOgSh9pJpRGsx2uq8X7MwDS7M5oSYRZzz';

  my $body = XMLout( { %output }, RootName => 'xml', NoAttr => 1 );

  $c->response->status(200);
  $c->response->content_type('text/xml');
  $c->response->content_encoding('utf-8');
  $c->response->body($body);

}


1;


