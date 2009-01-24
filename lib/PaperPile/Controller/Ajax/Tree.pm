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

# Currently supported



sub node : Local {
  my ( $self, $c ) = @_;

  my $node     = $c->request->params->{node};

  my $tree;

  if ( not defined $c->session->{"tree"} ) {
    $tree = $self->_get_default_tree($c);
    $c->session->{"tree"}=$tree;
  }
  else {
    $tree = $c->session->{"tree"};
  }

  my $subtree = $self->_get_subtree( $c, $tree, $node );

  my $data=$self->_get_js_object($subtree);

  $c->stash->{tree} = $data;

  $c->forward('PaperPile::View::JSON::Tree');

}

sub _get_default_tree {

  my ( $self, $c ) = @_;


  my $tree =
    Tree::Simple->new( { text => 'Root', id => 'root' }, Tree::Simple->ROOT );

  $tree->setUID('root');

  $tree->addChild( Tree::Simple->new( { text => 'Local library',
                                        type=>'DB',
                                        query=>'' } ) );

  my $sub_tree = Tree::Simple->new( { text => 'Source' }, $tree );


  $sub_tree->addChild( Tree::Simple->new( { text => 'PubMed',
                                            type => 'PUBMED',
                                            query=>''
                                          } ) );

  $sub_tree->addChild( Tree::Simple->new( { text => 'File',
                                            type => 'FILE',
                                            file => '/home/wash/play/PaperPile/t/data/test2.ris',
                                          }
                                        ) );

  $sub_tree = Tree::Simple->new( { text => 'Tags', type=>"TAGS", id=>'tags' }, $tree );
  $sub_tree->setUID('tags');

  # Initialize with tags
  $self->_get_tags($c,$sub_tree);

  $sub_tree = Tree::Simple->new( { text => 'Admin' }, $tree );

  $sub_tree->addChild( Tree::Simple->new( { text => 'Import Journals',
                                            type => 'IMPORT_JOURNALS',
                                          } ) );

  $sub_tree->addChild( Tree::Simple->new( { text => 'Reset Database',
                                            type => 'RESET_DB',
                                          } ) );

  $sub_tree->addChild( Tree::Simple->new( { text => 'Initialize Database',
                                            type => 'INIT_DB',
                                          } ) );

  return $tree;
}

sub _get_js_object {

  my ( $self, $node ) = @_;

  my @output=();

  foreach my $child ($node->getAllChildren){

    my $h=$child->getNodeValue();

    $h->{id}=$child->getUID;

    if ($child->isLeaf()){
      $h->{leaf}=1;
    } else {
      $h->{leaf}=0;
    }

    push @output, $h;
  }

  return [@output];

}

sub _get_subtree {

  my ( $self, $c, $tree, $UID ) = @_;

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
        #print STDERR $_tree->getUID, "\n";
        $subtree = $_tree if $_tree->getUID eq $UID;
      }
    )
  }

  if ($subtree->getNodeValue->{id} eq 'tags'){
    $self->_get_tags($c,$subtree);
  }


  return $subtree;

}

sub _get_tags {

  my ( $self, $c,$tree ) = @_;

  my @tags=@{$c->model('DBI')->get_tags};

  # Remove all children (old tags) first

  foreach my $child ($tree->getAllChildren){
    $tree->removeChild($child);
  }

  # Add tags
  foreach my $tag (@tags) {
    $tree->addChild( Tree::Simple->new( { text => $tag, type => 'TAG' } ) );
  }

}



1;

