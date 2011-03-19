# Copyright 2009-2011 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public License for more details.  You should have
# received a copy of the GNU Affero General Public License along with
# Paperpile.  If not, see http://www.gnu.org/licenses.


package Paperpile::Controller::Ajax::Plugins;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Data::Dumper;
use 5.010;
use Module::Load;
use Paperpile::Exceptions;

use Paperpile::Plugins::Import;
use Paperpile::Plugins::Export;

# Import plugins dynamically from directory content alone
BEGIN {
  # normal glob fails on spaces so use bsd_glob
  use File::Glob ':glob';
  foreach my $lib_dir (@INC) {
    foreach
      my $plugin_dir ( "$lib_dir/Paperpile/Plugins/Import", "$lib_dir/Paperpile/Plugins/Export" ) {
      if ( -e $plugin_dir ) {
        foreach my $plugin_file (bsd_glob("$plugin_dir/*pm") ) {
          $plugin_file =~ s/$lib_dir.//;
          my $module = join( "::", split( /\//, $plugin_file ) );
          $module =~ s/\.pm$//;
          eval("use $module");
        }
      }
    }
  }
}

sub resultsgrid : Local {

  my ( $self, $c ) = @_;

  my $grid_id   = $c->request->params->{grid_id};
  my $task      = $c->request->params->{task} || '';
  my $offset    = $c->request->params->{start} || 0;
  my $limit     = $c->request->params->{limit};
  my $selection = $c->request->params->{selection} || '';

  my $plugin_name = $c->request->params->{plugin_name};
  my $plugin;

  my $cancel_handle = $c->request->params->{cancel_handle} || undef;

  if ($cancel_handle){
    Paperpile::Utils->register_cancel_handle($cancel_handle);
  }

  if ( not defined Paperpile::Utils->session($c)->{"grid_$grid_id"} or $task eq 'NEW' ) {

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

    if ( ( ( $plugin_name eq 'DB' ) and ( not $c->request->params->{plugin_file} ) )
      or ( $plugin_name eq 'Duplicates' )
      or ( $plugin_name eq 'Trash' ) ) {
      $params{file} = Paperpile::Utils->session($c)->{library_db};
    }

    # create instance; can we do this more elegantly?
    $plugin = eval( "$plugin_module->" . 'new(%params)' );

    $plugin->limit($limit);

    $plugin->connect;

    if ( $plugin->total_entries == 0 ) {
      _resultsgrid_format( @_, [], 0 );
    }

  } else {
    $plugin = Paperpile::Utils->session($c)->{"grid_$grid_id"};
    if ( $c->request->params->{plugin_update_total} ) {
      $plugin->update_total(1);
    }
  }

  my $entries;

  # Fetch ALL entries and filter on sha1 if the 'selection' param is defined.
  if ( $selection ne '' ) {

    if ( ref($selection) ne 'ARRAY' ) {
      if ( $selection ne 'all' ) {
        $selection = [$selection];
      }
    }

    my %guid_hash;
    map { $guid_hash{$_} = 1 } @$selection;

    my $unfiltered_entries = $plugin->all;
    my @filtered_entries;
    foreach my $pub (@$unfiltered_entries) {
      push @filtered_entries, $pub if ( $guid_hash{ $pub->guid } );
    }
    $entries = \@filtered_entries;
  } else {

    # Else, just get the normal page worth.
    $entries = $plugin->page( $offset, $limit );

  }

  # Skip test for existence for standard user database
  if ( $plugin_name ~~ ['DB','Trash','Duplicates']  and not $c->request->params->{plugin_file} ) {
    foreach my $pub (@$entries) {
      $pub->_imported(1);
    }
  } else {
    $c->model('Library')->exists_pub($entries);

    # If guid has changed because entry is already in database update
    # also the plugin cache
    foreach my $pub (@$entries){
      if ($pub->_old_guid){
        $plugin->update_cache($pub);
      }
    }
  }

  Paperpile::Utils->session($c, {"grid_$grid_id" => $plugin});

  if ($cancel_handle){
    Paperpile::Utils->clear_cancel($$);
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
    root          => 'data'
  );

  $c->component('View::JSON')->encoding('utf8');

  $c->stash->{total} = $total_entries;
  $c->stash->{data}          = [@data];
  $c->stash->{metaData}      = {%metaData};

  $c->detach('Paperpile::View::JSON');

}

sub delete_grids : Local {
  my ( $self, $c ) = @_;
  my $grid_ids = $c->request->params->{grid_ids};

  if (!(ref $grid_ids eq 'ARRAY')){
    $grid_ids = [$grid_ids];
  }

  foreach my $grid_id (@$grid_ids){
    my $plugin = Paperpile::Utils->session($c)->{"grid_$grid_id"};
    if ($plugin) {
      $plugin->cleanup();
      Paperpile::Utils->session($c, {"grid_$grid_id" => undef});
    }
  }

  $c->forward('Paperpile::View::JSON');
}

sub export : Local {

  my ( $self, $c ) = @_;

  my $grid_id     = $c->request->params->{grid_id}     || undef;
  my $source_node = $c->request->params->{source_node} || undef;
  my $collection_id = $c->request->params->{collection_id} || undef;
  my $selection   = $c->request->params->{selection}   || undef;
  my $get_string  = $c->request->params->{get_string}  || 0;

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
  if ( defined $grid_id ) {
    my $grid = Paperpile::Utils->session($c)->{"grid_$grid_id"};

    if ( $selection =~ m/all/i ) {
      $data = $grid->all;
    } else {
      my @tmp;
      if ( ref($selection) eq 'ARRAY' ) {
        @tmp = @$selection;
      } else {
        push @tmp, $selection;
      }
      for my $guid (@tmp) {
        my $pub = $grid->find_guid($guid);
        push @$data, $pub;
      }
    }
  }

  # Data from plugin-query in tree
  if ( defined $source_node ) {

    # Get the node with the id specified by $source_node
    my $tree = $c->model('Library')->get_setting('_tree');
    my $node = undef;
    $tree->traverse(
      sub {
        my ($_subtree) = @_;
        $node = $_subtree if $_subtree->getUID eq $source_node;
      }
    );

    # The rest is the same code as in "resultsgrid" to query an import plugin
    my %node_settings = %{ $node->getNodeValue };
    my %params        = ();

    foreach my $key ( keys %node_settings ) {
      if ( $key =~ /^plugin_/ ) {
        my $newKey = $key;
        $newKey =~ s/^plugin_//;
        $params{$newKey} = $node_settings{$key};
      }
    }

    $params{name} = 'DB' if ( !defined $params{name} );

    if ( ( $params{name} eq 'DB' ) and ( not $params{file} ) ) {
      $params{file} = Paperpile::Utils->session($c)->{library_db};
    }

    my $plugin_module = "Paperpile::Plugins::Import::" . $params{name};
    my $plugin        = eval( "$plugin_module->" . 'new(%params)' );

    $plugin->connect;

    $data = $plugin->all;
  }

  # Data from a collection
  if (defined $collection_id) {
    my %params;

    my $guid = $collection_id;
    my $type = $c->model('Library')->get_collection_type($guid);
    $type = lc($type);

    # Add sub-collections
    my @all = $c->model('Library')->find_subcollections($guid);
    map {$_=$type."id:$_"} @all;
    $params{query} = join(" OR ", @all);
    $params{file} = Paperpile::Utils->session($c)->{library_db};

    my $plugin =  Paperpile::Plugins::Import::DB->new(%params);
    $plugin->connect;
    $data = $plugin->all;
  }

  # If output format is BibTeX or LateX cite-keys we add the user's
  # BibTeX settings to the parameter list
  if (( $export_params{out_format} eq 'BIBTEX') or ( $export_params{out_format} eq 'CITEKEYS')) {
    %export_params = ( %export_params, %{ $c->model('Library')->get_setting('bibtex') } );
  }

  # Dynamically generate export plugin instance and write data

  my $export_module = "Paperpile::Plugins::Export::" . $export_params{name};
  my $export        = eval( "$export_module->" . 'new(data => $data, settings=>{%export_params})' );

  if ($get_string) {
    my $string = $export->write(1);
    $c->stash->{data} = { string => $string };
  } else {
    $export->write;
  }

}

1;
