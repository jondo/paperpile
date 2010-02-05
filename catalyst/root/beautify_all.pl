#!/usr/bin/env perl

my @files = <js/**/*.js>;
foreach my $file (@files) {
    my $cmd = "js_beautify.pl -s=2 -r --output='$file' $file";
    print $cmd . "\n";
    `$cmd`;
}
