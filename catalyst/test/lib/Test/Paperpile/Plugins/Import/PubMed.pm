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

sub match : Tests(44) {

  my ($self) = @_;

   $self->test_match(
     "Matching publications against Pubmed",
     "data/Plugins/Pubmed/match/testcases.in",
     "data/Plugins/Pubmed/match/testcases.out"
   );

}

1;
