package PaperPile::Controller::Ajax::Grid;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use PaperPile::Library::Publication;
use Data::Dumper;
use 5.010;
use Module::Load;

use PaperPile::Plugins::Import;

# Import plugins dynamically from directory content alone
BEGIN{
  foreach my $lib_dir (@INC){
    my $plugin_dir="$lib_dir/PaperPile/Plugins/Import";
    if (-e $plugin_dir){
      foreach my $plugin_file (glob("$plugin_dir/*pm")){
        (my $plugin) = ($plugin_file=~/.*[\/](.*?)\.pm/);
        eval ("use PaperPile::Plugins::Import::$plugin;");
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

  my $plugin_type = $c->request->params->{plugin_type};
  my $plugin;

  if ( not defined $c->session->{"grid_$grid_id"} or $task eq 'NEW' ) {

    # Load required module dynamically
    my $plugin_module = "PaperPile::Plugins::Import::$plugin_type";

    # Directly pass plugin parameters starting with "plugin_" to plugin Module
    my %params = ();
    foreach my $key ( keys %{ $c->request->params } ) {
      if ( $key =~ /^plugin_/ ) {
        my $newKey = $key;
        $newKey =~ s/^plugin_//;
        $params{$newKey} = $c->request->params->{$key};
      }
    }

    if ( ( $plugin_type eq 'DB' ) and ( not $c->request->params->{plugin_file} ) ) {
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

  if ( $plugin_type eq 'DB' ) {
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
    push @data,  $pub->as_hash;

  }

  my @fields = ();

  foreach my $key ( keys %{ PaperPile::Library::Publication->new()->as_hash } )
  {
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
  $c->detach('PaperPile::View::JSON');

}

sub delete_grid : Local {
  my ( $self, $c ) = @_;
  my $grid_id = $c->request->params->{grid_id};

  delete( $c->session->{"grid_$grid_id"} );

  $c->forward('PaperPile::View::JSON');
}


sub index : Path : Args(0) {
  my ( $self, $c ) = @_;
  $c->response->body('Matched PaperPile::Controller::Ajax in Ajax.');
}


1;
