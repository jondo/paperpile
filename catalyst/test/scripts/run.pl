# Call via ../run.pl to run with the right perl interpreter

BEGIN { $ENV{CATALYST_DEBUG} = 0 }

use TAP::Harness;
use Getopt::Long;
use File::Basename;

my @all_tests = ('basic','metacrawler','pdfcrawler','import_plugins');

my %test_names = (
  basic       => 'Basic tests',
  metacrawler => 'Metadata crawler',
  pdfcrawler  => 'PDF file crawler',
  import_plugins => 'Import plugins',
);

my $verbose = 1;
my $color = 1;

GetOptions ("color" => \$color,
            "verbose" => \$verbose);

my @tests;

foreach my $file (@ARGV){
  $test = basename($file,'.t');

  if ((!exists $test_names{$test}) || (!-e $file)){
    usage();
    exit(1);
  }

  push @tests, $test;
}

my %args = (
  verbosity => 1,
  lib       => ['lib'],
  color     => 1,
  #formatter_class => 'TAP::Formatter::JUnit',
);

my $harness = TAP::Harness->new( \%args );

@tests = ('basic') if (!@tests);

foreach my $test (@tests){
  $harness->runtests( [ "t/$test.t", $test_names{$test} ] );
}

sub usage {

  print STDERR "\nUSAGE: runtests [OPTIONS] test1.t test2.t ...\n";

  print STDERR "\nAVAILABLE TESTS:\n";

  foreach my $test (@all_tests){
    $padded = sprintf("%-20s", "$test.t");
    print STDERR "  $padded\t", $test_names{$test}, "\n";

  }

  print STDERR "\nOPTIPONS:\n";

}
