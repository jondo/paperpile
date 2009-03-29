package Paperpile::Plugins::Export;

use Paperpile::Library::Publication;

use Moose;
use Moose::Util::TypeConstraints;
use Data::Dumper;
use Carp;

has 'data' => (
  is      => 'rw',
  isa     => 'ArrayRef[Paperpile::Library::Publication]',
);

has 'settings' => (
  is      => 'rw',
  isa     => 'HashRef',
  default => sub { return {} }
);




1;
