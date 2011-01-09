package Test::Paperpile::Formats::Ris;

use Test::More;
use Data::Dumper;

use base 'Test::Paperpile::Formats';

# The class being tested
sub class { 'Paperpile::Formats::Ris' }

# Run once before all other tests
sub startup : Tests(startup => 1) {
  my ($self) = @_;

  use_ok $self->class;

}

# Add test functions here

sub read : Tests(8) {

  my ($self) = @_;

  $self->test_read(
    "Misc. test",
    "data/Formats/Ris/read/misc.ris",
    "data/Formats/Ris/read/misc.out",
  );

}


sub write : Tests(1) {

  my ($self) = @_;

  $self->test_write( "Misc", "data/Formats/Ris/write/misc.yaml");

}

1;
