package Test::Paperpile::Plugins::Import::ArXiv;

use Test::More;
use Data::Dumper;

use base 'Test::Paperpile::Plugins';

# The class being tested
sub class { 'Paperpile::Plugins::Import::ArXiv' }

# Run once before all other tests
sub startup : Tests(startup => 1) {
  my ($self) = @_;

  use_ok $self->class;

}

# Add test functions here

sub match : Tests(12) {

  my ($self) = @_;

  $self->test_match(
     "Matching publications against ArXiv",
     "data/Plugins/Import/ArXiv/match/testcases.in",
     "data/Plugins/Import/ArXiv/match/testcases.out"
  );

}

sub connect_page : Tests(12) {

  my ($self) = @_;

  $self->test_connect_page(
     "Testing connect/page for ArXiv",
     "data/Plugins/Import/ArXiv/connect_page/testcases.in",
     "data/Plugins/Import/ArXiv/connect_page/testcases.out"
  );

}

1;
