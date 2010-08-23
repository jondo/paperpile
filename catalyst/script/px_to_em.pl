#!/usr/bin/env perl
use strict;
use warnings;

while (<>) {
    my $line = $_;
    while ($line =~ m/([: ])([-]?\d+)px/g) {
	my $input = $2;
	my $value = sprintf("%.2f",(int($2)/12));
#	$value = '0' if ($value == 0);
	$value = $value.'em';

	# Special case: 1px stays the same.
	my $test = $line;
	next unless ($test =~ m/font|text|size|line/);
	next if (int($input) == 1);

	substr($line,pos($line)-length($input)-2,length($input)+2) = $value;
    }
    print $line;
}
