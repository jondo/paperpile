# Call via ../run.pl to run with the right perl interpreter

use TAP::Harness;

my %args = (
  verbosity => 1,
  lib       => ['lib'],
  color     => 1,
  ##formatter_class => 'TAP::Formatter::JUnit',
);

my $harness = TAP::Harness->new( \%args );

$harness->runtests( [ 't/basic.t', 'Basic tests' ] );

