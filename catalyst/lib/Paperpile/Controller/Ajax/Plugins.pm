package Paperpile::Controller::Ajax::Plugins;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Data::Dumper;
use 5.010;
use Module::Load;

use Paperpile::Plugins::Import;
use Paperpile::Plugins::Export;

# Import plugins dynamically from directory content alone
BEGIN{
  foreach my $lib_dir (@INC){
    foreach my $plugin_dir ("$lib_dir/Paperpile/Plugins/Import",
                            "$lib_dir/Paperpile/Plugins/Export"){
      if (-e $plugin_dir){
        foreach my $plugin_file (glob("$plugin_dir/*pm")){
          $plugin_file=~s/$lib_dir.//;
          my $module=join("::",split(/\//,$plugin_file));
          $module=~s/\.pm$//;
          eval ("use $module");
        }
      }
    }
  }
}

sub resultsgrid : Local {

  my ( $self, $c ) = @_;

  my $grid_id     = $c->request->params->{grid_id};
  my $task        = $c->request->params->{task} || '';
  my $offset      = $c->request->params->{start};
  my $limit       = $c->request->params->{limit};

  my $plugin_name = $c->request->params->{plugin_name};
  my $plugin;

  if ( not defined $c->session->{"grid_$grid_id"} or $task eq 'NEW' ) {

    # Load required module dynamically
    my $plugin_module = "Paperpile::Plugins::Import::$plugin_name";

    # Directly pass plugin parameters starting with "plugin_" to plugin Module
    my %params = ();
    foreach my $key ( keys %{ $c->request->params } ) {
      if ( $key =~ /^plugin_/ ) {
        my $newKey = $key;
        $newKey =~ s/^plugin_//;
        $params{$newKey} = $c->request->params->{$key};
      }
    }

    if ( ( $plugin_name eq 'DB' ) and ( not $c->request->params->{plugin_file} ) ) {
      $params{file} = $c->session->{user_db};
    }

    # create instance; can we do this more elegantly?
    $plugin = eval( "$plugin_module->" . 'new(%params)' );

    $plugin->limit($limit);
    $plugin->connect;

    if ( $plugin->total_entries == 0 ) {
      _resultsgrid_format( @_, [], 0 );
    }

    $c->session->{"grid_$grid_id"} = $plugin;
  } else {
    $plugin = $c->session->{"grid_$grid_id"};
  }

  my $entries = $plugin->page( $offset, $limit );

  # Skip test for existence for standard user database
  if ( $plugin_name eq 'DB' and not $c->request->params->{plugin_file} ) {
    foreach my $pub (@$entries) {
      $pub->_imported(1);
    }
  } else {
    $c->model('User')->exists_pub($entries);
  }

  _resultsgrid_format( @_, $entries, $plugin->total_entries );

}

sub _resultsgrid_format {

  my ( $self, $c, $entries, $total_entries ) = @_;

  my @data = ();

  foreach my $pub (@$entries) {
    push @data, $pub->as_hash;
  }

  my @fields = ();

  foreach my $key ( keys %{ Paperpile::Library::Publication->new()->as_hash } ) {
    push @fields, { name => $key };
  }

  my %metaData = (
    totalProperty => 'total_entries',
    root          => 'data',
    id            => 'sha1',
    fields        => [@fields]
  );

  $c->component('View::JSON')->encoding('utf8');

  $c->stash->{total_entries} = $total_entries;
  $c->stash->{data}          = [@data];
  $c->stash->{metaData}      = {%metaData};
  $c->detach('Paperpile::View::JSON');

}

sub delete_grid : Local {
  my ( $self, $c ) = @_;
  my $grid_id = $c->request->params->{grid_id};

  my $plugin = $c->session->{"grid_$grid_id"};

  if ($plugin){
    $plugin->cleanup();
    delete( $c->session->{"grid_$grid_id"} );
  }

  $c->forward('Paperpile::View::JSON');
}

sub export : Local {

  my ( $self, $c ) = @_;

  my $source_grid = $c->request->params->{source_grid};
  my $source_node = $c->request->params->{source_node};
  my $selection   = $c->request->params->{selection};

  # Collect all export_ parameters for the export plugin
  my %export_params = ();
  foreach my $key ( keys %{ $c->request->params } ) {
    if ( $key =~ /^export_/ ) {
      my $newKey = $key;
      $newKey =~ s/^export_//;
      my $newValue = $c->request->params->{$key};
      $newValue = 1 if ( $newValue eq 'on' or $newValue eq 'true' );
      $newValue = 0 if ( $newValue eq 'false' );
      $export_params{$newKey} = $newValue;
    }
  }

  # Get the data to export. Either from an open resultsgrid or from a
  # plugin-query specified by a node in the navigation tree

  my $data = [];

  # Get data from results grid
  if ( defined $source_grid ) {

    my $plugin = $c->session->{"grid_$source_grid"};

    # If selection is given, export only those
    if ( defined $selection ) {
      my @list;

      if ( ref($selection) eq 'ARRAY' ) {
        @list = @$selection;
      } else {
        push @list, $selection;
      }

      for my $sha1 (@list) {
        my $pub = $plugin->find_sha1($sha1);
        push @$data, $pub;
      }

      # If not selection is given export all
    } else {
      $data = $plugin->all;
    }
  }

  # Data from plugin-query in tree
  if ( defined $source_node ) {

    # Get the node with the id specified by $source_node
    my $tree = $c->session->{"tree"};
    my $node = undef;
    $tree->traverse(
      sub {
        my ($_subtree) = @_;
        $node = $_subtree if $_subtree->getUID eq $source_node;
      }
    );

    # The rest is the same code as in "resultsgrid" to query an import plugin
    my %node_settings = %{ $node->getNodeValue };
    my %params = ();

    foreach my $key ( keys %node_settings ) {
      if ( $key =~ /^plugin_/ ) {
        my $newKey = $key;
        $newKey =~ s/^plugin_//;
        $params{$newKey} = $node_settings{$key};
      }
    }
    if ( ( $params{name} eq 'DB' ) and ( not $params{file} ) ) {
      $params{file} = $c->session->{user_db};
    }

    my $plugin_module = "Paperpile::Plugins::Import::" . $params{name};
    my $plugin        = eval( "$plugin_module->" . 'new(%params)' );

    $plugin->connect;

    $data = $plugin->all;
  }


  # Dynamically generate export plugin instance and write data

  my $export_module = "Paperpile::Plugins::Export::" . $export_params{name};
  my $export = eval( "$export_module->" . 'new(data => $data, settings=>{%export_params})' );

  $export->write;

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');
}


1;
