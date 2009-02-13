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

sub _relative_path {

  my ( $self, $path ) = @_;

  # skip the first 3 levels which are "built in", might change so
  # this might have to be adjusted in the future
  ($path)=$path=~/\/.*?\/.*?\/.*?\/(.*)/;

  $path='/' if not $path;

  return $path;

}

sub new_folder : Local {
  my ( $self, $c ) = @_;

  my $node_id = $c->request->params->{node_id};
  my $parent_id = $c->request->params->{parent_id};
  my $path = $c->request->params->{path};
  my $name = $c->request->params->{name};

  my $tree= $c->session->{"tree"};

  my $sub_tree= $self->_get_subtree($c, $tree, $parent_id );

  my $new = Tree::Simple->new( { text => $name, type => "FOLDER", draggable =>"true",
                                 path=> '/', id => $node_id },  );
  $new->setUID($node_id);

  $sub_tree->addChild($new);

  $c->model('User')->insert_folder($self->_relative_path($path));

  $c->stash->{success} = 'true';
  $c->forward('PaperPile::View::JSON');

}

sub delete_folder : Local {
  my ( $self, $c ) = @_;

  my $node_id = $c->request->params->{node_id};
  my $parent_id = $c->request->params->{parent_id};
  my $path = $c->request->params->{path};
  my $name = $c->request->params->{name};

  $c->model('User')->delete_folder($self->_relative_path($path));

  $c->stash->{success} = 'true';
  $c->forward('PaperPile::View::JSON');

}



sub move_in_folder : Local {
  my ( $self, $c ) = @_;

  my $node_id = $c->request->params->{node_id};
  my $source_id = $c->request->params->{source_id};
  my $sha1 = $c->request->params->{sha1};
  my $rowid = $c->request->params->{rowid};
  my $path = $c->request->params->{path};

  my $source = $c->session->{"source_$source_id"};
  my $pub = $source->find_sha1($sha1);
  my $tree= $c->session->{"tree"};

  my $newFolder=$self->_relative_path($path);
  my @folders=();

  @folders=split(/,/,$pub->folders);
  push @folders, $newFolder;

  my %seen = ();
  @folders = grep { ! $seen{$_} ++ } @folders;

  $c->model('User')->update_folders($rowid, join(',',@folders));
  $pub->folders(join(',',@folders));

  $c->stash->{success} = 'true';
  $c->forward('PaperPile::View::JSON');

}



sub _get_default_tree {

  my ( $self, $c ) = @_;

  ##### Root

  my $root = Tree::Simple->new( { text => 'Root', id => 'root' }, Tree::Simple->ROOT );
  $root->setUID('root');

  my $local_lib = Tree::Simple->new( {
      text    => 'Local library',
      type    => 'DB',
      query   => '',
      cls     => 'pp-tree-heading',
      iconCls => 'pp-icon-empty',
    }
  );

  $root->addChild($local_lib);

  ##### Tags

  my $tags = Tree::Simple->new( {
      text    => 'Tags',
      type    => "TAGS",
      id      => 'tags',
      iconCls => 'pp-icon-empty',
    },
    $local_lib
  );
  $tags->setUID('tags');

  # Initialize
  $self->_get_tags( $c, $tags );

  ##### Folders

  my $folders = Tree::Simple->new( {
      text    => 'Folders',
      type    => "FOLDER",
      path    => '/',
      id      => 'folders',
      iconCls => 'pp-icon-empty',
    },
    $local_lib
  );

  $folders->setUID('folder_root');
  $self->_get_folders( $c, $folders );

  ##### Sources

  my $sources = Tree::Simple->new( {
      text    => 'Online Databases',
      cls     => 'pp-tree-heading',
      iconCls => 'pp-icon-empty',
    },
    $root
  );

  $sources->addChild(
    Tree::Simple->new( {
        text    => 'PubMed',
        type    => 'PUBMED',
        query   => '',
        iconCls => 'pp-icon-pubmed',
      }
    )
  );

  $sources->addChild(
    Tree::Simple->new( {
        text    => 'Google Scholar',
        type    => 'GOOGLE',
        query   => '',
        iconCls => 'pp-icon-google',
      }
    )
  );

  ##### Admin

  my $admin = Tree::Simple->new( {
      text    => 'Debug',
      cls     => 'pp-tree-heading',
      iconCls => 'pp-icon-empty',
    },
    $root
  );

  $admin->addChild(
    Tree::Simple->new( {
        text    => 'Import Journals',
        type    => 'IMPORT_JOURNALS',
        iconCls => 'pp-icon-tools',
      }
    )
  );

  $admin->addChild(
    Tree::Simple->new( {
        text    => 'Reset Database',
        type    => 'RESET_DB',
        iconCls => 'pp-icon-tools',
      }
    )
  );

  $admin->addChild(
    Tree::Simple->new( {
        text    => 'Initialize Database',
        type    => 'INIT_DB',
        iconCls => 'pp-icon-tools',
      }
    )
  );

  return $root;
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

  #print STDERR Dumper $subtree;

  if ($subtree->getNodeValue->{id} eq 'tags'){
    $self->_get_tags($c,$subtree);
  }

  if ($subtree->getNodeValue->{id} eq 'folders'){
    $self->_get_folders($c,$subtree);
  }


  return $subtree;

}

sub _get_tags {

  my ( $self, $c, $tree ) = @_;

  my @tags = @{ $c->model('User')->get_tags };

  # Remove all children (old tags) first

  foreach my $child ( $tree->getAllChildren ) {
    $tree->removeChild($child);
  }

  if ( not @tags ) {
    push @tags, 'No tags';
  }

  # Add tags
  foreach my $tag (@tags) {
    $tree->addChild(
      Tree::Simple->new( {
          text    => $tag,
          type    => 'TAG',
          iconCls => 'pp-icon-tag',
        }
      )
    );
  }
}


sub _get_folders {

  my ( $self, $c, $tree ) = @_;

  my @folders = @{ $c->model('User')->get_folders };

  # Reset everything by removing all children
  foreach my $child ( $tree->getAllChildren ) {
    $tree->removeChild($child);
  }

  foreach my $folder (@folders) {
    my @parts = split( /\//, $folder );

    my $t = $tree;
    foreach my $part (@parts) {
      my $curr_node = undef;
      foreach my $child ( $t->getAllChildren ) {
        if ( $child->getNodeValue->{text} eq $part ) {
          $curr_node = $child;
          last;
        }
      }
      if ( not $curr_node ) {
        my $new_node = Tree::Simple->new( {
            text    => $part,
            type    => 'FOLDER',
            iconCls => 'pp-icon-folder',
          }
        );

        #$new_node->getNodeValue->{id}=$new_node->getUID;
        $t->addChild($new_node);
        $t = $new_node;
      } else {
        $t = $curr_node;
      }

    }
  }
}


1;

