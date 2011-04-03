package Test::Paperpile::Formats::Zotero;

use Test::More;
use Data::Dumper;

use base 'Test::Paperpile::Formats';

# The class being tested
sub class { 'Paperpile::Formats::Zotero' }

# Run once before all other tests
sub startup : Tests(startup => 1) {
  my ($self) = @_;

  use_ok $self->class;

}

# Add test functions here

sub read : Tests(227) {

  my ($self) = @_;

  $self->test_read(
    "Import from Zotero database version 2.0.3",
    "data/Formats/Zotero/v2.0.3/zotero.sqlite",
    "data/Formats/Zotero/v2.0.3/zotero.out"
  );

  $self->test_read(
    "Import from Zotero database version 2.0.9",
    "data/Formats/Zotero/v2.0.9/zotero.sqlite",
    "data/Formats/Zotero/v2.0.9/zotero.out"
  );

}



1;
