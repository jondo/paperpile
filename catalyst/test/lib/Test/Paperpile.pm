package Test::Paperpile;

use Test::More tests => 1;

use base 'Test::Class';

sub class { 'Paperpile' }

sub startup : Tests(startup => 1) {
  my $self = @_;

  ok(1, "Test ok");

  #use_ok $test->class;
}

1;
