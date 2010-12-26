# Call via ../run.pl to run with the right perl interpreter

BEGIN { $ENV{CATALYST_DEBUG} = 0 }

use strict;
use TAP::Harness;
use Getopt::Long;
use File::Basename;

## Define available tests here

my @all_tests = ( 'basic', 'metacrawler', 'pdfcrawler', 'import_plugins', 'cover' );

my %test_names = (
  basic          => 'Basic tests',
  metacrawler    => 'Metadata crawler',
  pdfcrawler     => 'PDF file crawler',
  import_plugins => 'Import plugins',
  cover          => 'Code coverage',
);

## Handle command line options

my $verbosity = 1;
my $nocolor   = 0;
my $junit     = 0;

GetOptions(
  "nocolor"     => \$nocolor,
  "verbosity:i" => \$verbosity,
  "junit"       => \$junit
);


## Collect tests from the rest of the command line

my @tests;

foreach my $file (@ARGV) {
  my $test = basename( $file, '.t' );

  if ( ( !exists $test_names{$test} ) || ( !-e $file ) ) {
    usage();
    exit(1);
  }

  push @tests, $test;
}

@tests = ('basic') if ( !@tests );

## Setup test harness

my %args = (
  verbosity       => $verbosity,
  lib             => ['lib'],
  color           => !$nocolor,
  formatter_class => $junit ? 'TAP::Formatter::JUnit' : undef,
);

my $harness = TAP::Harness->new( \%args );

## Run tests

my $cover=0;

foreach my $test (@tests) {

  $harness->runtests( [ "t/$test.t", $test_names{$test} ] );

  $cover = 1 if $test eq 'cover';

}

## Generate HTML coverage reports
if ($cover){
  my $platform = $ENV{PLATFORM};
  system("../perl5/$platform/bin/paperperl  ../perl5/$platform/bin/cover coverage");
}


sub usage {

  print STDERR "\nUSAGE: runtests [OPTIONS] suite1.t suite2.t ...\n";

  print STDERR "\nAVAILABLE TESTS:\n";

  foreach my $test (@all_tests) {
    my $padded = sprintf( "%-20s", "$test.t" );
    print STDERR "  $padded\t", $test_names{$test}, "\n";

  }

  print STDERR "\nOPTIONS:\n";

}
