# Call via ../run.pl to run with the right perl interpreter

BEGIN { $ENV{CATALYST_DEBUG} = 0 }

use strict;
use TAP::Harness;
use Getopt::Long;
use File::Basename;

## Define available testsuites here

my %suites = (
  basic => {
    name  => 'Basic backend unit and regression tests',
    files => [ "t/basic.t", "t/formats/bibtex.t", "t/formats/ris.t", "t/formats/zotero.t" ]
  },
  cover => {
    name  => 'Coverage analysis (see coverage/coverage.html)',
    files => ["t/cover.t"]
  },
  pdfcrawler => {
    name  => 'PDF crawler',
    files => ["t/pdfcrawler.t"]
  },

);

## Handle command line options

my $verbosity = 1;
my $nocolor   = 0;
my $junit     = 0;
my $help      = 0;

GetOptions(
  "nocolor"     => \$nocolor,
  "verbosity:i" => \$verbosity,
  "junit"       => \$junit,
  "help"        => \$help
);

usage() if ( @ARGV == 0 || $help );

## Collect tests from the rest of the command line

my ( @tests, @files );

foreach my $file (@ARGV) {

  if ( $file =~ /\.t$/ ) {
    usage() if ( !-e $file );
    push @files, $file;
  } else {
    if ( $suites{$file} ) {
      push @files, @{ $suites{$file}->{files} };
    } else {
      usage();
    }
  }
}

@tests = ('t/basic.t') if ( !@tests );

## Setup test harness

my %args = (
  verbosity       => $verbosity,
  lib             => ['lib'],
  color           => !$nocolor,
  formatter_class => $junit ? 'TAP::Formatter::JUnit' : undef,
);

my $harness = TAP::Harness->new( \%args );

## Run tests

my $cover = 0;

my @to_run;

foreach my $file (@files) {
  push @to_run, [ $file, $file ];
  $cover = 1 if $file =~ /cover\.t/;
}

$harness->runtests(@to_run);

## Generate HTML coverage reports
if ($cover) {
  my $platform = $ENV{PLATFORM};
  system("../perl5/$platform/bin/paperperl  ../perl5/$platform/bin/cover coverage");
}

sub usage {

  print STDERR "\nUSAGE: runtests [OPTIONS] suite1 suite2 ...\n";
  print STDERR "       runtests [OPTIONS] t/file1.t t/file2.t ...\n";

  print STDERR "\nAVAILABLE TEST SUITES:\n";

  foreach my $test ( keys %suites ) {

    my $padded = sprintf( "%-20s", $test );
    print STDERR "  $padded\t", $suites{$test}->{name}, "\n";
  }

  print STDERR "\nOPTIONS:\n";

  print STDERR "  --nocolor     Don't colorize outpout\n";
  print STDERR "  --verbosity   Verbosity level (-3..1, see TAP::Harness)\n";
  print STDERR "  --junit       JUnit formatted output\n\n";

  exit(1);

}
