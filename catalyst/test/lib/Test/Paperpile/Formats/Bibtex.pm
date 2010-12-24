package Test::Paperpile::Formats::Bibtex;

use Test::More;
use Data::Dumper;

use base 'Test::Paperpile::Formats';

sub class { 'Paperpile::Formats::Bibtex' }

sub startup : Tests(startup => 1) {
  my ($self) = @_;
  use_ok $self->class;

}

sub misc : Tests(25){

  my ($self) = @_;

  $self->test_read("data/Formats/Bibtex/read/misc");
  $self->test_read("data/Formats/Bibtex/read/pubtypes");

}




1;
