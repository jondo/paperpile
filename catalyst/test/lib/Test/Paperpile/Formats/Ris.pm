package Test::Paperpile::Formats::Ris;

use Test::More;
use Data::Dumper;
use utf8; # make perl utf-8 aware of this source file

use base 'Test::Paperpile::Formats';

# The class being tested
sub class { 'Paperpile::Formats::Ris' }

# Run once before all other tests
sub startup : Tests(startup => 1) {
  my ($self) = @_;

  use_ok $self->class;

}

# Add test functions here

sub read : Tests(34) {

  my ($self) = @_;

  $self->test_read(
    "Misc. test",
    "data/Formats/Ris/read/misc.ris",
    "data/Formats/Ris/read/misc.out",
  );

  # Test UTF-8 and latin-1 decoding. IMPORTANT: Make sure you don't
  # change the encoding of the test files when you open them with a
  # text editor.

  my $pub = $self->class->new( file => "data/Formats/Ris/read/utf-8.ris")->read->[0];
  is($pub->title, "These are UTF-8 characters: いろはにほへど", "Read UTF-8 encoded file.") ;

  $pub = $self->class->new( file => "data/Formats/Ris/read/latin1.ris")->read->[0];
  is($pub->title, "These are latin-1 characters: Ö Ê ø", "Read Latin-1 encoded file.") ;


}


sub write : Tests(3) {

  my ($self) = @_;

  $self->test_write( "Misc", "data/Formats/Ris/write/misc.yaml");

}

1;
