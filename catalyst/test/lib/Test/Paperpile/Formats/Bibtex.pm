package Test::Paperpile::Formats::Bibtex;

use Test::More;
use Data::Dumper;

use base 'Test::Paperpile::Formats';

# The class being tested
sub class { 'Paperpile::Formats::Bibtex' }

# Run once before all other tests
sub startup : Tests(startup => 1) {
  my ($self) = @_;
  use_ok $self->class;
}

# Add test functions functions here

sub misc : Tests(25){

  my ($self) = @_;

  # Test xxx.in vs xxx.out. "xxx.in" is the BibTeX file while
  # "xxx.out" is a YAML formatted files with the expected fields

  diag("Misc. BibTeX tests");
  $self->test_read("data/Formats/Bibtex/read/misc");

  diag("BibTeX Publication types");
  $self->test_read("data/Formats/Bibtex/read/pubtypes");

}




1;
