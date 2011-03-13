package Test::Paperpile::Formats::Mendeley;

use Test::More;
use Data::Dumper;

use base 'Test::Paperpile::Formats';

# The class being tested
sub class { 'Paperpile::Formats::Mendeley' }

# Run once before all other tests
sub startup : Tests(startup => 1) {
  my ($self) = @_;

  use_ok $self->class;

}

# Add test functions here

sub read : Tests(55) {

  my ($self) = @_;

  $self->test_read(
    "Import from Mendeley database version 0.9.7",
    "data/Formats/Mendeley/v0.9.7/online.sqlite",
    "data/Formats/Mendeley/v0.9.7/online.out"
  );


}



1;
