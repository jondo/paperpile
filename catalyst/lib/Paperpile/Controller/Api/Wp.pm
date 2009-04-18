package Paperpile::Controller::Api::Wp;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Paperpile::Plugins::Import::DB;
use Paperpile::Utils;
use Data::Dumper;
use File::Path;
use File::Copy;
use XML::Simple;
use 5.010;

# Function: ping
#
# Pings the status of the server and returns the version

sub ping : Local {
  my ( $self, $c ) = @_;

  my $body = XMLout( { version => $c->VERSION }, RootName => 'xml', NoAttr => 1 );

  $c->response->status(200);
  $c->response->content_type('text/xml');
  $c->response->content_encoding('utf-8');
  $c->response->body($body);

}

# Function: open
#
# Initializes session: creates local database from the data stored in
# word document or empty database

sub open : Local {
  my ( $self, $c ) = @_;

  # get xml data from post body
  my $input = XMLin( $c->request->body, SuppressEmpty => undef);

  # Path to temporary database file
  mkpath($c->path_to("tmp/wp")->stringify);
  my $dbfile=$c->path_to("tmp","wp",$input->{documentID}.'.db')->stringify;

  # We decode the database and store it temporarily
  if ($input->{documentLibrary}){
    my $content=Paperpile::Utils->decode_db($input->{documentLibrary});
    open(FILE, ">$dbfile") or die "Could not write temporary database file ($!)";
    binmode(FILE);
    print FILE $content;
    # If no data is in word document we create an empty database
  } else {
    my $empty_db=$c->path_to('db/local-user.db')->stringify;
    copy( $empty_db, $dbfile ) or die "Could not initialize empty db ($!)";
  }

  my $body = XMLout( { version => $c->VERSION }, RootName => 'xml', NoAttr => 1 );

  $c->response->status(200);
  $c->response->content_type('text/xml');
  $c->response->content_encoding('utf-8');
  $c->response->body($body);

}


# Function: list_styles
#
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
#
# Searches the local database and the document mods file for citations

sub search : Local {
  my ( $self, $c ) = @_;

  my $query      = $c->request->params->{query};
  my $limit      = $c->request->params->{limit};
  my $documentID = $c->request->params->{documentID};

  my $db_file;
  my @output = ();

  my %seen = ();

  # We search both the references in the word document as well as the local paperpile library
  foreach my $source ( 'document','library' ) {

    if ( $source eq 'library' ) {
      $db_file =
        $c->model('App')->dbh->selectrow_array("SELECT value FROM Settings WHERE key='user_db'");
    } else {
      $db_file = $c->path_to( "tmp", "wp", $documentID . '.db' )->stringify;
    }

    my $pars = {
      file  => $db_file,
      query => $query,
      name  => 'DB',
      mode  => 'FULLTEXT'
    };

    my $plugin = Paperpile::Plugins::Import::DB->new($pars);

    $plugin->connect;

    my $results = $plugin->page( 0, $limit );

    foreach my $pub (@$results) {

      if ( not $seen{ $pub->sha1 } ) {

        my $citation = $pub->_citation_display;

        # strip html tags; probably format specifically for plugin in future
        $citation =~ s!</?\w>!!g;

        push @output, {
          id       => $source.'_rowid_' . $pub->_rowid,
          title    => $pub->title,
          authors  => $pub->_authors_display,
          citation => $citation,
          source   => $source,
          };

        $seen{ $pub->sha1 } = 1;
      }
    }
  }

  my $data = { result => [@output] };

  my $body = XMLout( $data, RootName => 'xml', NoAttr => 1 );

  $c->response->status(200);
  $c->response->content_type('text/xml');
  $c->response->content_encoding('utf-8');
  $c->response->body($body);

}

# Function: format_citations
#
# Formats citations and imports entries to document library

sub format_citations : Local {
  my ( $self, $c ) = @_;

  # Get xml data from post body
  my $input = XMLin( $c->request->body, ForceArray => [ 'citation', 'item' ] );

  # Connect to library
  my $library_db_file = $c->model('App')->get_setting('user_db');
  my $library_model   = Paperpile::Model::User->new();
  $library_model->set_dsn( "dbi:SQLite:" . $library_db_file );

  # Connect to document database
  my $document_db_file = $c->path_to( "tmp", "wp", $input->{documentID} . '.db' )->stringify;
  my $document_model = Paperpile::Model::User->new();
  $document_model->set_dsn( "dbi:SQLite:" . $document_db_file );

  # Collect 'library' ids which need to be imported
  my @libraryIDs =();
  foreach my $citation ( @{ $input->{citations}->{citation} } ) {
    foreach my $item ( @{ $citation->{item} } ) {
      print STDERR "$item\n";
      if ($item =~ /^library_rowid_(\d+)/){
        push @libraryIDs, "rowid=$1";
      }
    }
  }

  # Get entries from library database
  my $pubs=$library_model->standard_search( join(' OR ', @libraryIDs ));

  # Save old rowids
  my @oldIDs=();
  push @oldIDs, $_->_rowid foreach (@$pubs);

  # Insert into document library, which updates the rowids
  $document_model->insert_pubs( $pubs );

  # Get new rowids
  my @newIDs=();
  push @newIDs, $_->_rowid foreach (@$pubs);

  # Make map between old and new rowids
  my %idMap=();
  foreach my $i (0..$#oldIDs){
    $idMap{$oldIDs[$i]}=$newIDs[$i];
  }

  # Now we create a new list of list of citations that all have the new 'document ids'
  my @citations=();
  my @query=();

  foreach my $citation ( @{ $input->{citations}->{citation} } ) {
    my @tmp=();
    foreach my $item ( @{ $citation->{item} } ) {

      if ($item =~ /^document_rowid_(\d+)/){
        push @tmp, $1;
        push @query, "rowid=$1";
      }

      if ($item =~ /^library_rowid_(\d+)/){
        push @tmp, $idMap{$1};
        push @query, "rowid=".$idMap{$1};
      }
    }
    push @citations, [@tmp];
  }

  # We get all entries for the required ids
  my $results = $document_model->standard_search( join( ' OR ', @query ) );

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
  $output{citations}    = {citation=>[]};
  $output{ids}          = {citation=>[]};
  $output{bibliography} = '';

  foreach my $citation (@citations){
    my @items=();
    my @ids=();
    foreach my $item (@$citation){
      push @items, $citations{$item};
      push @ids, "document_rowid_$item";
      $output{bibliography}.=$references{$item}."\n\n";
    }
    push @{$output{citations}->{citation}}, "(".join(', ',@items).")";
    push @{$output{ids}->{citation}}, {item=>[@ids]};
  }

  $output{documentLibraryString} = Paperpile::Utils->encode_db($document_db_file);;

  my $body = XMLout( {%output}, RootName => 'xml', NoAttr => 1 );

  $c->response->status(200);
  $c->response->content_type('text/xml');
  $c->response->content_encoding('utf-8');
  $c->response->body($body);

}




1;


