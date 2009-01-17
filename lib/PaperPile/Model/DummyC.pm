## Dummy package to simulate a class with methods log and debug. 
## Needed to test DBI when no $c object is available. 

package PaperPile::Model::DummyC;
use Moose;

sub log{
  return '';
}

sub debug{
  return '';
}

1
