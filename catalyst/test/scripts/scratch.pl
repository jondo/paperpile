#!../../perl5/linux64/bin/paperperl -w

## Add code to generate test data or ad-hoc tests here.

use strict;
use lib "../../lib";

use Paperpile;
use Paperpile::Utils;
use Data::Dumper;
use YAML;

use LockFile::Simple;

print STDERR "PID $$ trying to get lock\n";

my $lockmgr = LockFile::Simple->make(
  -format => '%f.lck',
  -max       => 30,
  -delay     => 1,
  -autoclean => 1,
);

my $lockmgr2 = LockFile::Simple->make(
  -format => '%f.lck',
  -max       => 30,
  -delay     => 1,
  -autoclean => 1,
);

$lockmgr->lock("test") || die "can't lock /some/file\n";

print STDERR "PID $$ obtained lock; doing work;\n";

sleep(5);

print STDERR $lockmgr2->unlock("test"), "\n";

print STDERR "PID $$ released lock\n";

### Format data in YAML

#my $r = Paperpile::Formats::Bibtex->new(file=>"/home/wash/examples/diss.bib");

#my $data = $r->read;

#foreach my $pub (@$data){

## Don't show helper fields starting with underscore and empty
## fields
#  foreach my $key (keys %$pub){
#    if ($key=~/^_/ || $pub->{$key} eq ''){
#      delete($pub->{$key});
#    }
#  }
#  print Dump($pub);
#}
