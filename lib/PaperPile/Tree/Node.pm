package PaperPile::Tree::Node;
use Moose;
use Moose::Util::TypeConstraints;
use Tree::Simple;

has 'text' => ( is => 'rw', isa => 'Str' );


1;

