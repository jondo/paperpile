use strict;
use warnings;
use Data::Dumper;
use Data::TreeDumper;
use Tree::Simple;

use Test::More 'no_plan';

use lib "../lib";

BEGIN { use_ok 'Paperpile::Tree::Node' }

# make a tree root
my $tree = Tree::Simple->new( { text => 'Root' }, Tree::Simple->ROOT );

# explicity add a child to it
$tree->addChild( Tree::Simple->new( { text => 'Item1' } ) );
$tree->addChild( Tree::Simple->new( { text => 'Item2' } ) );
$tree->addChild( Tree::Simple->new( { text => 'Item3' } ) );
my $sub_tree = Tree::Simple->new( { text => 'item4' }, $tree );
$sub_tree->addChild( Tree::Simple->new( { text => 'Subitem' } ) );


$tree->getAllChildren;






$tree->DESTROY();

