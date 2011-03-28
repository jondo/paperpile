package Test::Paperpile::Plugins::Import::Duplicates;

use Test::More;
use Data::Dumper;

use base 'Test::Paperpile::Plugins';

# The class being tested
sub class { 'Paperpile::Plugins::Import::Duplicates' }

# Run once before all other tests
sub startup : Tests(startup => 1) {
  my ($self) = @_;

  use_ok $self->class;

}

# Add test functions here

sub connect_page : Tests(9) {

  my ($self) = @_;

  $self->test_connect_page(
     "Testing connect/page for Duplicates",
     "data/Plugins/Import/Duplicates/connect_page/testcases.in",
     "data/Plugins/Import/Duplicates/connect_page/testcases.out"
  );

}

1;
