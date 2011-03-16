package Test::Paperpile::Plugins::Import::PubMed;

use Test::More;
use Data::Dumper;

use base 'Test::Paperpile::Plugins';

# The class being tested
sub class { 'Paperpile::Plugins::Import::PubMed' }

# Run once before all other tests
sub startup : Tests(startup => 1) {
  my ($self) = @_;

  use_ok $self->class;

}

# Add test functions here

sub match : Tests(74) {

  my ($self) = @_;

   $self->test_match(
     "Matching publications against Pubmed",
     "data/Plugins/Import/PubMed/match/testcases.in",
     "data/Plugins/Import/PubMed/match/testcases.out"
   );

}

1;
