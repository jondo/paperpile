package Test::Paperpile::Formats;

use Test::More;
use Data::Dumper;
use YAML;

use base 'Test::Paperpile';

sub class { 'Paperpile::Formats' }

sub startup : Tests(startup => 1) {
  my ($self) = @_;
  use_ok $self->class;
}


# Test a $file.in agains a $file.out file. Adds one test for each
# specified field and an additional one for the correct number of
# entries read.

sub test_read {

  my ( $self, $file ) = @_;

  my @observed = @{$self->class->new( file => "$file.in" )->read};
  my @expected = YAML::LoadFile("$file.out");

  is($#observed, $#expected, "$file: number of read items");

  foreach my $i (0 .. $#expected){
    $self->test_fields($observed[$i],$expected[$i], $file);
  }


}

1;
