package Test::Paperpile::Library::Author;

use Test::More;
use Data::Dumper;
use YAML;
use base 'Test::Class';

use Paperpile;

sub class { 'Paperpile::Library::Author' };

sub startup : Tests(startup => 1) {
  my ($self) = @_;
  use_ok $self->class;
}


1;
