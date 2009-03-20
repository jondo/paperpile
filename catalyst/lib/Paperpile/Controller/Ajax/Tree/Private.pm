package Paperpile::Controller::Ajax::Tree::Private;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Data::Dumper;
use 5.010;

sub get_default_tree : Private {

  my ( $self, $c ) = @_;

  #### Root

  my $root = Tree::Simple->new( {
      text => 'Root',
      id   => 'root'
    },
    Tree::Simple->ROOT
  );

  $root->setUID('root');

  #### / Local Library

  my $local_lib = Tree::Simple->new( {
      text    => 'Local library',
      type    => 'DB',
      query   => '',
      cls     => 'pp-tree-heading',
      iconCls => 'pp-icon-empty',
      hidden  => \0,
    },
    $root
  );

  #### / Local Library / Tags

  my $tags = Tree::Simple->new( {
      text    => 'Tags',
      type    => "TAGS",
      id      => 'tags',
      iconCls => 'pp-icon-empty',
      hidden  => \0,
    },
    $local_lib
  );
  $tags->setUID('tags');

  # Initialize
  $self->_get_tags( $c, $tags );

  #### / Local Library / Folders

  my $folders = Tree::Simple->new( {
      text    => 'Folders',
      type    => "FOLDER",
      path    => '/',
      id      => 'folders',
      iconCls => 'pp-icon-empty',
      hidden  => \0,
    },
    $local_lib
  );

  $folders->setUID('folder_root');
  $self->_get_folders( $c, $folders );

  #### / Active Folders

  my $active = Tree::Simple->new( {
      text    => 'Active Folders',
      type    => "ACTIVE",
      path    => '/',
      id      => 'active',
      iconCls => 'pp-icon-empty',
      cls     => 'pp-tree-heading',
      hidden  => \0,
    }
  );

  $root->addChild($active);

  $active->addChild(
    Tree::Simple->new( {
        type         => 'ACTIVE',
        text         => 'My papers',
        plugin_title => 'My papers',
        plugin_name  => 'DB',
        plugin_mode  => 'FULLTEXT',
        plugin_query => 'washietl',
        iconCls      => 'pp-icon-folder',
        hidden       => \0,
      }
    )
  );

  $folders->setUID('active_root');

  ##### / Plugins

  my $plugins = Tree::Simple->new( {
      text    => 'Online Databases',
      cls     => 'pp-tree-heading',
      iconCls => 'pp-icon-empty',
      hidden  => \0,
    },
    $root
  );

  $plugins->addChild(
    Tree::Simple->new( {
        type         => 'IMPORT_PLUGIN',
        plugin_name  => 'PubMed',
        text         => 'PubMed',
        plugin_query => '',
        iconCls      => 'pp-icon-pubmed',
        hidden       => \0,
      }
    )
  );

  $plugins->addChild(
    Tree::Simple->new( {
        type         => 'IMPORT_PLUGIN',
        plugin_name  => 'Google',
        text         => 'Google Scholar',
        plugin_query => '',
        iconCls      => 'pp-icon-google',
        hidden       => \0,
      }
    )
  );

  ##### / Settings

  my $admin = Tree::Simple->new( {
      text    => 'Debug',
      cls     => 'pp-tree-heading',
      iconCls => 'pp-icon-empty',
      hidden  => \0,
    },
    $root
  );

  $admin->addChild(
    Tree::Simple->new( {
        text    => 'Reset Database',
        type    => 'RESET_DB',
        iconCls => 'pp-icon-tools',
        hidden  => \0,
      }
    )
  );

  $admin->addChild(
    Tree::Simple->new( {
        text    => 'Settings',
        type    => 'SETTINGS',
        iconCls => 'pp-icon-tools',
        hidden  => \0,
      }
    )
  );

  return $root;
}


sub get_js_object : Private {

  my ( $self, $c, $node ) = @_;

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

sub get_subtree : Private {

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
          plugin_name => 'DB',
          plugin_mode=> 'FULLTEXT',
          plugin_query=> "tags: $tag",
          plugin_base_query=> "tags: $tag",
          plugin_title=>$tag,
          plugin_iconCls => 'pp-icon-tag',
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
            text              => $part,
            type              => 'FOLDER',
            iconCls           => 'pp-icon-folder',
            plugin_name       => 'DB',
            plugin_mode       => 'FULLTEXT',
            plugin_query      => "folders: $part",
            plugin_base_query => "folders: $part",
            plugin_title      => $part,
            plugin_iconCls    => 'pp-icon-folder',
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
