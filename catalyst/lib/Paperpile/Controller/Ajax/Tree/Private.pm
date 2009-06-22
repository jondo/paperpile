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
      text   => 'Root',
      hidden => 0,
    },
    Tree::Simple->ROOT
  );

  $root->setUID('ROOT');

  #### / Local Library

  my $local_lib = Tree::Simple->new( {
      text    => 'My Paperpile',
      type    => 'DB',
      query   => '',
      cls     => 'pp-tree-heading',
      iconCls => 'pp-icon-empty',
      hidden  => 0,
    },
    $root
  );

  $local_lib->setUID('LOCAL_ROOT');

  #### / Local Library / Folders

  my $folders = Tree::Simple->new( {
      text    => 'All Papers',
      type    => "FOLDER",
      path    => '/',
      iconCls => 'pp-icon-page',
      hidden  => 0,
    },
    $local_lib
  );

  $folders->setUID('FOLDER_ROOT');

  #### / Local Library / Tags

  my $tags = Tree::Simple->new( {
      text    => 'Labels',
      type    => "TAGS",
      iconCls => 'pp-icon-tag',
      hidden  => 0,
    },
    $local_lib
  );
  $tags->setUID('TAGS_ROOT');

  # Initialize
  $c->forward( 'get_tags', [$tags] );

  #### / Active Folders

  my $active = Tree::Simple->new( {
      text    => 'Active Folders',
      type    => "ACTIVE",
      path    => '/',
      iconCls => 'pp-icon-empty',
      cls     => 'pp-tree-heading',
      hidden  => 0,
    }
  );
  $active->setUID('ACTIVE_ROOT');

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
        hidden       => 0,
      }
    )
  );

  ##### / Plugins

  my $plugins = Tree::Simple->new( {
      text    => 'Online Search',
      type    => 'IMPORT_PLUGIN',
      cls     => 'pp-tree-heading',
      iconCls => 'pp-icon-empty',
      hidden  => 0,
    },
    $root
  );

  $plugins->setUID('IMPORT_PLUGIN_ROOT');

  $plugins->addChild(
    Tree::Simple->new( {
        type         => 'IMPORT_PLUGIN',
        plugin_name  => 'PubMed',
        text         => 'PubMed',
        plugin_query => '',
        iconCls      => 'pp-icon-pubmed',
        hidden       => 0,
      }
    )
  );

  $plugins->addChild(
    Tree::Simple->new( {
        type         => 'IMPORT_PLUGIN',
        plugin_name  => 'GoogleScholar',
        text         => 'Google Scholar',
        plugin_query => '',
        iconCls      => 'pp-icon-google',
        hidden       => 0,
      }
    )
  );

  $plugins->addChild(
    Tree::Simple->new( {
        type         => 'IMPORT_PLUGIN',
        plugin_name  => 'ArXiv',
        text         => 'ArXiv',
        plugin_query => '',
        iconCls      => 'pp-icon-arxiv',
        hidden       => 0,
      }
    )
  );

  ##### / Settings

  my $import = Tree::Simple->new( {
      text    => 'Import Data',
      cls     => 'pp-tree-heading',
      iconCls => 'pp-icon-empty',
      hidden  => 0,
    },
    $root
  );


  $import->addChild(
    Tree::Simple->new( {
        text    => 'Import PDFs',
        type    => 'PDFEXTRACT',
        iconCls => 'pp-icon-import-pdf',
        qtip => 'Import one or more PDFs to your library',
        hidden  => 0,
      }
    )
  );

  $import->addChild(
    Tree::Simple->new( {
        text    => 'Import File',
        type    => 'FILE_IMPORT',
        iconCls => 'pp-icon-import-file',
        qtip => 'Import references from EndNote, BibTeX <br> and other bibliography files.',
        hidden  => 0,
      }
    )
  );

  return $root;
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
        $subtree = $_tree if $_tree->getUID eq $UID;
      }
    )
  }

  if ($subtree->getUID eq 'tags'){
    $self->_get_tags($c,$subtree);
  }

  if ($subtree->getUID eq 'folders'){
    $self->_get_folders($c,$subtree);
  }

  return $subtree;

}

sub get_tags : Private {

  my ( $self, $c, $tree ) = @_;

  my @tags = @{ $c->model('Library')->get_tags };

  # Remove all children (old tags) first

  foreach my $child ( $tree->getAllChildren ) {
    $tree->removeChild($child);
  }

  if ( not @tags ) {
    #push @tags, {tag=>'No labels',style=>'0'};
  }

  # Add tags
  foreach my $tag (@tags) {
    $tree->addChild(
      Tree::Simple->new( {
          text              => $tag->{tag},
          type              => 'TAGS',
          hidden            => 0,
          iconCls           => 'pp-icon-empty',
          cls               => 'pp-tag-tree-node pp-tag-tree-style-'.$tag->{style},
          tagStyle         => $tag->{style},
          plugin_name       => 'DB',
          plugin_mode       => 'FULLTEXT',
          plugin_query      => "label:".$tag->{tag},
          plugin_base_query => "label:".$tag->{tag},
          plugin_title      => $tag->{tag},
          plugin_iconCls    => 'pp-icon-tag',
        }
      )
    );
  }
}




1;
