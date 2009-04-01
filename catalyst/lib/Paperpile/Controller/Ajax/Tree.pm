package Paperpile::Controller::Ajax::Tree;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Data::Dumper;
use 5.010;


sub node : Local {
  my ( $self, $c ) = @_;

  my $node = $c->request->params->{node};

  my $tree;

  if ( not defined $c->session->{"tree"} ) {

    $tree=$c->model('User')->restore_tree();

    if (not defined $tree){
      $tree = $c->forward('private/get_default_tree');
    }

    $c->session->{"tree"}=$tree;
  }
  else {
    $tree = $c->session->{"tree"};
  }

  my $subtree = $c->forward('private/get_subtree',[$tree, $node]);

  my $data=$c->forward('private/get_js_object',[$subtree,$c->request->params->{checked}]);

  $c->stash->{tree} = $data;

  $c->forward('Paperpile::View::JSON::Tree');

}

sub set_visibility : Local {

  my ( $self, $c ) = @_;

  my $node = $c->request->params->{node_id};
  my $hidden =$c->request->params->{hidden};

  my $tree = $c->session->{"tree"};
  my $subtree = $c->forward('private/get_subtree',[$tree, $node]);

  $subtree->getNodeValue->{hidden}=$hidden;

  $c->model('User')->save_tree($tree);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}


sub new_folder : Local {
  my ( $self, $c ) = @_;

  my $node_id   = $c->request->params->{node_id};
  my $parent_id = $c->request->params->{parent_id};

  my $path      = $c->request->params->{path};

  my $tree = $c->session->{"tree"};

  my $sub_tree = $c->forward( 'private/get_subtree', [ $tree, $parent_id ] );

  my %params = (draggable=>\1);

  foreach my $key ( keys %{ $c->request->params } ) {
    next if $key =~ /^_/;
    $params{$key} = $c->request->params->{$key};
  }

  $params{id} = $node_id;
  delete( $params{node_id} );

  my $new = Tree::Simple->new( {%params} );
  $new->setUID($node_id);
  $sub_tree->addChild($new);

  $c->model('User')->insert_folder( $path );

  $c->model('User')->save_tree($tree);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub delete_folder : Local {
  my ( $self, $c ) = @_;

  my $node_id = $c->request->params->{node_id};
  my $parent_id = $c->request->params->{parent_id};
  my $path = $c->request->params->{path};
  my $name = $c->request->params->{name};

  $c->model('User')->delete_folder($path);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}



sub move_in_folder : Local {
  my ( $self, $c ) = @_;

  my $node_id = $c->request->params->{node_id};
  my $grid_id = $c->request->params->{grid_id};
  my $sha1    = $c->request->params->{sha1};
  my $rowid   = $c->request->params->{rowid};
  my $path    = $c->request->params->{path};

  my $plugin = $c->session->{"grid_$grid_id"};
  my $pub    = $plugin->find_sha1($sha1);
  my $tree   = $c->session->{"tree"};

  my $newFolder = $path;
  my @folders   = ();

  @folders = split( /,/, $pub->folders );
  push @folders, $newFolder;

  my %seen = ();
  @folders = grep { !$seen{$_}++ } @folders;

  $c->model('User')->update_folders( $rowid, join( ',', @folders ) );
  $pub->folders( join( ',', @folders ) );

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub new_active : Local {
  my ( $self, $c ) = @_;

  my $node_id   = $c->request->params->{node_id};
  my $parent_id = $c->request->params->{parent_id};

  my $tree = $c->session->{"tree"};

  my $sub_tree = $c->forward( 'private/get_subtree', [ $tree, $parent_id ] );

  my %params = ();

  foreach my $key ( keys %{ $c->request->params } ) {
    next if $key =~ /^_/;
    $params{$key} = $c->request->params->{$key};
  }

  $params{id} = $node_id;
  delete( $params{node_id} );

  my $new = Tree::Simple->new( {%params} );
  $new->setUID($node_id);
  $sub_tree->addChild($new);

  $c->model('User')->save_tree($tree);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub delete_active : Local {
  my ( $self, $c ) = @_;

  my $node_id = $c->request->params->{node_id};

  my $tree= $c->session->{"tree"};

  my $subtree = $c->forward('private/get_subtree',[$tree, $node_id]);

  $subtree->getParent->removeChild($subtree);

  $c->model('User')->save_tree($tree);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub rename_active : Local {
  my ( $self, $c ) = @_;

  my $node_id = $c->request->params->{node_id};
  my $new_text = $c->request->params->{new_text};

  my $tree= $c->session->{"tree"};

  my $subtree = $c->forward('private/get_subtree',[$tree, $node_id]);

  my $pars=$subtree->getNodeValue();

  $pars->{text}=$new_text;
  $pars->{plugin_title}=$new_text;

  $c->model('User')->save_tree($tree);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}






1;

