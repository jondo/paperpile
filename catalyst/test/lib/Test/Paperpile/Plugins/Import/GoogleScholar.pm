package Test::Paperpile::Plugins::Import::GoogleScholar;

use Test::More;
use Data::Dumper;

use base 'Test::Paperpile::Plugins';

# The class being tested
sub class { 'Paperpile::Plugins::Import::GoogleScholar' }

# Run once before all other tests
sub startup : Tests(startup => 1) {
  my ($self) = @_;

  use_ok $self->class;

}

# Add test functions here

sub match : Tests(59) {

  my ($self) = @_;

   $self->test_match(
     "Matching publications against GoogleScholar",
     "data/Plugins/Import/GoogleScholar/match/testcases.in",
     "data/Plugins/Import/GoogleScholar/match/testcases.out"
   );

}

1;
