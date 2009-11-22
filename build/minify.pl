#!/usr/bin/perl -w

use strict;

use YAML qw(LoadFile);

my $yui = "~/bin/yuicompressor-2.4.2.jar";
my $cat_dir  = '../catalyst';

my $data = LoadFile("$cat_dir/data/resources.yaml");

my $all_css = "$cat_dir/root/css/all.css";

unlink($all_css);

foreach my $file (@{$data->{css}}){
  `cat $cat_dir/root/$file >> $all_css`;
}

my $all_js = "$cat_dir/root/js/all.js";

unlink($all_js);

foreach my $file (@{$data->{js}}){
  `cat $cat_dir/root/$file >> tmp.js`;
}

`java -jar $yui tmp.js -o $all_js`;

unlink('tmp.js');
