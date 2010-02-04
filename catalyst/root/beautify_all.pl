#!/usr/bin/env perl

my @files = <js/**/*.js>;
foreach my $file (@files) {
    print "js_beautify.pl --output='$file' $file\n";
    `js_beautify.pl --output='$file' $file`;
}
