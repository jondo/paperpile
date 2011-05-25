package Test::Paperpile::Plugins::Import::CrossRef;

use Test::More;
use Data::Dumper;

use base 'Test::Paperpile::Plugins';

# The class being tested
sub class { 'Paperpile::Plugins::Import::CrossRef' }

# Run once before all other tests
sub startup : Tests(startup => 1) {
  my ($self) = @_;

  use_ok $self->class;

}

# Add test functions here

sub match : Tests(77) {

  my ($self) = @_;

  $self->test_match(
     "Matching publications against CrossRef",
     "data/Plugins/Import/CrossRef/match/testcases.in",
     "data/Plugins/Import/CrossRef/match/testcases.out"
  );

}

1;
