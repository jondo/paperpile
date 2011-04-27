package Test::Paperpile::Basic;

use strict;

use Test::More;
use Data::Dumper;
use YAML;
use File::Path;

use base 'Test::Paperpile';

sub class { 'Paperpile' };

sub startup : Tests(startup => 1) {
  my ($self) = @_;
  use_ok $self->class;
}

sub directories : Tests(9) {

  ok(Paperpile->platform ~~[qw/linux32 linux64 osx win32/], "detect platform");

  ok(-d Paperpile->home_dir, "home_dir exists");
  ok(-e Paperpile->home_dir."/lib/Paperpile.pm", "home_dir contains Paperpile.pm");

  ok(-e Paperpile->path_to('lib'), "path_to finds .../lib");
  ok(-e Paperpile->path_to('lib','Paperpile'), "path_to finds .../lib/Paperpile");

  my $tmp_dir = Paperpile->tmp_dir;

  ok(defined $tmp_dir, "tmp_dir defined");

  mkpath($tmp_dir);

  ok(-d $tmp_dir, "tmp_dir exists");

  open(OUT, ">$tmp_dir/tmp");
  print OUT "tmp";
  close(OUT);

  ok(-e "$tmp_dir/tmp", "write file to temp_dir");

  unlink("$tmp_dir/tmp") || die("Could not delete file from tmp_dir $!");

  ok(!(-e "$tmp_dir/tmp"), "delete file from temp_dir");

}


1;
