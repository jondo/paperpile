# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl XML-CSL.t'

use strict;
#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More qw(no_plan);
BEGIN { 
	use_ok('Biblio::CSL');
	use_ok('Moose');
	use_ok('XML::Smart');
	use_ok('Switch');
};

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# testing the csl transformation
my @styles = glob("t/*/*.csl");

foreach my $style (@styles){
	my $subdir = $style;
	$subdir =~ /^(t\/.+)\/.+csl$/;
	$subdir = $1;
	
	my $o = Biblio::CSL->new(
		mods => "$subdir/mods.xml",
		csl => $style,
		format => "txt"
	);
	$o->transform();

	my $observed = $o->biblioToString();	
	my $expected = readFile("$subdir/output.txt");
	
	# just standardize them
	$observed =~ s/\s+\n/\n/g;
	$expected =~ s/\s+\n/\n/g;
	
	is($observed, $expected, "testing style: $style");
}

# returns the content of the file
sub readFile {
	my $file = shift;
	
	my $str = "";
	open IN, "< $file" or die "ERROR: Can not open file '$file'!";
	while(<IN>) {
		$str .= $_;
	}
	close IN;
	
	return $str;
}

