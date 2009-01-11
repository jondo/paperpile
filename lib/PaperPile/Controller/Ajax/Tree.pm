package PaperPile::Controller::Ajax::Tree;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use PaperPile::Library::Publication;
use PaperPile::Library::Source::File;
use PaperPile::Library::Source::DB;
use PaperPile::Library::Source::PubMed;
use PaperPile::Tree::Node;
use Data::Dumper;
use 5.010;

sub node : Local {
  my ( $self, $c ) = @_;

  my $node     = $c->request->params->{node};

  my $tree;

  if ( not defined $c->session->{"tree"} ) {
    $tree = $self->_get_default_tree;
    $c->session->{"tree"}=$tree;
  }
  else {
    $tree = $c->session->{"tree"};
  }

  my $subtree = $self->_get_subtree( $tree, $node );

  my $data=$self->_get_js_object($subtree);

  $c->stash->{tree} = $data;

  $c->forward('PaperPile::View::JSON::Tree');

}

sub _get_default_tree {

  my ( $self, $c ) = @_;

  my $tree =
    Tree::Simple->new( { text => 'Root', id => 'root' }, Tree::Simple->ROOT );

  $tree->setUID('root');

  $tree->addChild( Tree::Simple->new( { text => 'Item1' } ) );
  $tree->addChild( Tree::Simple->new( { text => 'Item2' } ) );
  $tree->addChild( Tree::Simple->new( { text => 'Item3' } ) );
  my $sub_tree = Tree::Simple->new( { text => 'item4' }, $tree );
  $sub_tree->addChild( Tree::Simple->new( { text => 'Subitem' } ) );

  return $tree;
}

sub _get_js_object {

  my ( $self, $node ) = @_;

  my @output=();

  foreach my $child ($node->getAllChildren){

    my $h=$child->getNodeValue();

    $h->{id}=$child->getUID;
    $h->{type}='This is my type';


    push @output, $h;
  }

  return [@output];

}

sub _get_subtree {

  my ( $self, $tree, $UID ) = @_;

  my $subtree = undef;

  # return the whole tree if it has the given UID
  # (only in case of 'root')
  if ( $tree->getUID eq $UID ) {
    return $tree;
  }
  # Search the tree recursively otherwise
  else {
    $tree->traverse(
      sub {
        my ($_tree) = @_;
        print STDERR $_tree->getUID, "\n";
        $subtree = $_tree if $_tree->getUID eq $UID;
      }
    );

  }

  return $subtree;

}

1;

