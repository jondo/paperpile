package Test::Paperpile;

use strict;

use Test::More;
use Data::Dumper;
use YAML;
use File::Path;

use base 'Test::Class';

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

  ok(-e "$tmp_dir/tmp", "write file to temp_dir");

  unlink("$tmp_dir/tmp");

  ok(!(-e "$tmp_dir/tmp"), "delete file from temp_dir");

}


# Compare $pub against fields in $data. The following suffixes can be
# used (default is "IS")

# field_IS        ... exact match
# field_LIKE      ... pattern match
# field_DEFINED   ... check if defined
# field_UNDEFINED ... check if undefined

# $msg is a prefix that is shown in the test message.

sub test_fields {

  my ($self, $pub, $data, $msg) = @_;

  foreach my $key (keys %$data){
    if ($key eq 'test_comment'){
      $msg.=" (".$data->{test_comment}.")";
      delete($data->{test_comment});
    }
  }

  foreach my $key (keys %$data){

    my $action = 'IS';

    my $expected = $data->{$key};

    $key =~s/_(IS|LIKE|DEFINED|UNDEFINED)$//;

    my $observed = $pub->$key;

    $action = $1 if $1;


    if ($key eq 'abstract'){
      $observed =~s/\s+/ /smg;
      $expected =~s/\s+/ /smg;
      $observed = chomp($observed);
      $expected = chomp($expected);
    }

    if ($action eq 'IS'){
      is($observed,$expected,"$msg: $key matches exactly");
    }

    if ($action eq 'LIKE'){
      like($observed, qr{$expected}, "$msg: $key matches pattern");
    }

    if ($action eq 'DEFINED'){
      ok($observed, "$msg: $key is defined");
    }

    if ($action eq 'UNDEFINED'){
      ok(!$observed, "$msg: $key is undefined");
    }
  }
}

1;
