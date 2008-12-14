package PaperPile::Library;
use PaperPile::Library::Publication;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;

has 'entries' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] }
);



1;

