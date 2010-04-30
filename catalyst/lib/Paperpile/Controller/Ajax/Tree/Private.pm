# Copyright 2009, 2010 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.  You should have received a
# copy of the GNU General Public License along with Paperpile.  If
# not, see http://www.gnu.org/licenses.

package Paperpile::Controller::Ajax::Tree::Private;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Paperpile::Utils;
use Data::Dumper;
use 5.010;

sub get_default_tree : Private {

  my ( $self, $c ) = @_;

  #### Root

  my $root = Tree::Simple->new( {
      text    => 'Root',
      hidden  => 0,
      builtin => 1,
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
      builtin => 1,
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
      builtin => 1,
    },
    $local_lib
  );

  $folders->setUID('FOLDER_ROOT');

  #### / Local Library / Labels

  my $tags = Tree::Simple->new( {
      text    => 'Labels',
      type    => "TAGS",
      iconCls => 'pp-icon-tag',
      hidden  => 0,
      builtin => 1,
    },
    $local_lib
  );
  $tags->setUID('TAGS_ROOT');

  # Initialize
  $c->forward( 'get_tags', [$tags] );

  #### / Local Library / Trash

  $folders = Tree::Simple->new( {
      text        => 'Trash',
      type        => "TRASH",
      iconCls     => 'pp-icon-trash',
      plugin_name => 'Trash',
      hidden      => 0,
      builtin     => 1,
    },
    $local_lib
  );

  $folders->setUID('TRASH');

  #### / Live & Feeds

  my $active = Tree::Simple->new( {
      text    => 'Live Folders & Feeds',
      type    => "ACTIVE",
      path    => '/',
      iconCls => 'pp-icon-empty',
      cls     => 'pp-tree-heading',
      hidden  => 0,
      builtin => 1,
    }
  );
  $active->setUID('ACTIVE_ROOT');

  $root->addChild($active);

  $active->addChild(
    Tree::Simple->new( {
        type         => 'ACTIVE',
        text         => 'Nature',
        plugin_title => 'Nature',
        plugin_name  => 'Feed',
        plugin_id    => 'NatureRSS',
        plugin_mode  => 'FULLTEXT',
        plugin_url   => 'http://feeds.nature.com/nature/rss/current?format=xml',
        qtip         => 'http://feeds.nature.com/nature/rss/current?format=xml',
        iconCls      => 'pp-icon-feed',
        hidden       => 0,
        builtin      => 1,
      }
    )
  );

  $active->addChild(
    Tree::Simple->new( {
        type         => 'ACTIVE',
        text         => 'Science',
        plugin_title => 'Science',
        plugin_name  => 'Feed',
        plugin_id    => 'ScienceRSS',
        plugin_mode  => 'FULLTEXT',
        plugin_url   => 'http://www.sciencemag.org/rss/current.xml',
        qtip         => 'http://www.sciencemag.org/rss/current.xml',
        iconCls      => 'pp-icon-feed',
        hidden       => 0,
        builtin      => 1,
      }
    )
  );

  $active->addChild(
    Tree::Simple->new( {
        type         => 'ACTIVE',
        text         => 'PLoS One',
        plugin_title => 'PLoS One',
        plugin_name  => 'Feed',
        plugin_mode  => 'FULLTEXT',
        plugin_id    => 'PLoSOneRSS',
        plugin_url   => 'http://feeds.plos.org/plosone/PLoSONE?format=xml',
        qtip         => 'http://feeds.plos.org/plosone/PLoSONE?format=xml',
        iconCls      => 'pp-icon-feed',
        hidden       => 0,
        builtin      => 1,
      }
    )
  );

  ##### / Tools & Resources

  my $plugins = Tree::Simple->new( {
      text    => 'Resources & Tools',
      type    => 'IMPORT_PLUGIN',
      cls     => 'pp-tree-heading',
      iconCls => 'pp-icon-empty',
      hidden  => 0,
      builtin => 1,
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
        builtin      => 1,
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
        builtin      => 1,
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
        builtin      => 1,
      }
    )
  );

  $plugins->addChild(
    Tree::Simple->new( {
        text    => 'Import PDFs',
        type    => 'PDFEXTRACT',
        iconCls => 'pp-icon-import-pdf',
        qtip    => 'Import one or more PDFs to your library',
        hidden  => 0,
        builtin => 1,
      }
    )
  );

  $plugins->addChild(
    Tree::Simple->new( {
        text    => 'Import File',
        type    => 'FILE_IMPORT',
        iconCls => 'pp-icon-import-file',
        qtip    => 'Import references from EndNote, BibTeX <br> and other bibliography files.',
        hidden  => 0,
        builtin => 1,
      }
    )
  );

  $plugins->addChild(
    Tree::Simple->new( {
        type    => 'CLOUDS',
        text    => 'Cloud View',
        iconCls => 'pp-icon-clouds',
        hidden  => 1,
        builtin => 1,
      }
    )
  );

  $plugins->addChild(
    Tree::Simple->new( {
        type    => 'DUPLICATES',
        text    => 'Find Duplicates',
        iconCls => 'pp-icon-duplicates',
        hidden  => 1,
        builtin => 1,
      }
    )
  );

  $plugins->addChild(
    Tree::Simple->new( {
        type    => 'FEEDBACK',
        text    => 'Feedback',
        iconCls => 'pp-icon-feedback',
        hidden  => 0,
        builtin => 1,
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
    );
  }

  if ( $subtree->getUID eq 'tags' ) {
    $self->_get_tags( $c, $subtree );
  }

  if ( $subtree->getUID eq 'folders' ) {
    $self->_get_folders( $c, $subtree );
  }

  return $subtree;

}

sub store_tags : Private {
  my ( $self, $c, $tree ) = @_;

  my $i = 0;
  foreach my $child ( $tree->getAllChildren ) {
    my $p = $child->getNodeValue();
    $c->model('Library')->set_tag_position( $p->{text}, $i++ );
  }
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

  # Sort the list of tags by their defined sort_order.
  @tags = sort { $a->{sort_order} <=> $b->{sort_order} } @tags;

  # Add tags
  foreach my $tag (@tags) {

    my $encoded = Paperpile::Utils->encode_tags( $tag->{tag} );

    $tree->addChild(
      Tree::Simple->new( {
          text              => $tag->{tag},
          type              => 'TAGS',
          hidden            => 0,
          iconCls           => 'pp-icon-empty',
          cls               => 'pp-tag-tree-node pp-tag-tree-style-' . $tag->{style},
          tagStyle          => $tag->{style},
          plugin_name       => 'DB',
          plugin_mode       => 'FULLTEXT',
          plugin_query      => "labelid:" . $encoded,
          plugin_base_query => "labelid:" . $encoded,
          plugin_title      => $tag->{tag},
          plugin_iconCls    => 'pp-icon-tag',
        }
      )
    );
  }
}

# Restore subtree for labels and folders from database

sub get_collections : Private {

  my ( $self, $c, $tree, $type ) = @_;

  # First remove old children
  foreach my $child ( $tree->getAllChildren ) {
    $tree->removeChild($child);
  }

  # Collect all data from the database table
  my @collections = ();
  my $sth = $c->model('Library')->dbh->prepare("SELECT * from Collections;");
  $sth->execute();
  while ( my $row = $sth->fetchrow_hashref() ) {
    push @collections, $row;
  }

  # Recursively fill subtree
  _add_collection_subtree( $tree, [@collections], 'ROOT', $type );

}

# Recursive function that adds all children in the right order for the
# current parent node

sub _add_collection_subtree {
  my ( $tree, $collections, $parent, $type ) = @_;


  my @nodes = grep { $_->{parent} eq $parent } @$collections;

  @nodes = sort { $a->{sort_order} <=> $b->{sort_order} } @nodes;

  foreach my $node (@nodes) {
    my $new_node = Tree::Simple->new( _get_collection_pars( $node, $type ) );
    $new_node->setUID( $node->{guid} );
    _add_collection_subtree( $new_node, $collections, $node->{guid}, $type );
    $tree->addChild($new_node);
  }
}

# Helper function to create a node object for a label or folder node

sub _get_collection_pars {

  my ( $coll, $type ) = @_;

  my $pars = {
    text         => $coll->{name},
    type         => $type,
    hidden       => 0,
    plugin_name  => 'DB',
    plugin_mode  => 'FULLTEXT',
    plugin_title => $coll->{name},
  };

  if ( $type eq 'FOLDER' ) {
    $pars->{plugin_query}      = "folderid:" . $coll->{guid};
    $pars->{plugin_base_query} = "folderid:" . $coll->{guid};
    $pars->{iconCls}           = 'pp-icon-folder';
    $pars->{plugin_iconCls}    = 'pp-icon-folder';
  } else {

    #$pars->{cls} ='pp-tag-tree-node pp-tag-tree-style-' . $tag->{style},
    #$pars->{tagStyle} => $coll->{style},
    #$pars->{plugin_iconCls} => 'pp-icon-tag';

  }

  return $pars;
}



1;
