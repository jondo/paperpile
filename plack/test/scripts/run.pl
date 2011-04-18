# Call via ../run.pl to run with the right perl interpreter

use strict;
use TAP::Harness;
use Getopt::Long;
use File::Basename;
use File::Path;

## Define available testsuites here

$ENV{PLACK_DEBUG} = 0;
$ENV{PP_TESTING} = 1;

my %suites = (
  basic => {
    name  => 'Basic backend unit and regression tests',
    files => [
      "t/basic.t",                 "t/job.t",
      "t/queue.t",                 "t/formats/bibtex.t",
      "t/formats/ris.t",           "t/formats/zotero.t",
      "t/formats/mendeley.t",      "t/plugins/pubmed.t",
      "t/plugins/googlescholar.t", "t/plugins/duplicates.t",
      "t/plugins/arxiv.t",         "t/binaries.t",
      "t/ajax/app.t",

    ]
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
my $cover     = 0;

GetOptions(
  "nocolor"     => \$nocolor,
  "verbosity:i" => \$verbosity,
  "junit"       => \$junit,
  "help"        => \$help,
  "cover"       => \$cover,
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

my @to_run;

foreach my $file (@files) {

  # If --cover is given we run temporary copies of the test script
  # with additional code
  if ($cover) {
    rmtree('coverage');
    open( IN, "<$file" );
    my @code = <IN>;
    open( TMP, ">$file.tmp" );
    print TMP
      'use Devel::Cover ( -db => "coverage", -silent => 1, -ignore => "t/.*", -ignore => ".*Test/Paperpile.*", -ignore => ".*/perl5/.*");',
      "\n";
    print TMP @code;
    close(TMP);
    push @to_run, [ "$file.tmp", "$file" ];
  } else {
    push @to_run, [ $file, $file ];
  }
}

$harness->runtests(@to_run);

if ($cover) {

  # Remove temporary copies again
  foreach my $file (@files) {
    unlink "$file.tmp";
  }

  # Build HTML output
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
  print STDERR "  --cover       Run coverage analysis\n\n";

  exit(1);

}
