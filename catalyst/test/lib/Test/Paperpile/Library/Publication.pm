package Test::Paperpile::Library::Publication;

use Test::More;
use Data::Dumper;
use YAML;

use base 'Test::Class';

use Paperpile;

sub class { 'Paperpile::Library::Publication' };

sub startup : Tests(startup => 1) {
  my ($self) = @_;
  use_ok $self->class;
}

1;
