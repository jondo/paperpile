#!perl -T

use Test::More skip_all => "Performance test", tests => 1;

use IO::File;
use BibTeX::Parser;

my $starttime = time;

my $fh = IO::File->new('t/bibs/java.bib'); #cl-nlp8x.bib');

my $parser = new BibTeX::Parser $fh;
my $entries = 0;

#my @result = BibTeX::Parser->_parse($fh);

while(my $entry = $parser->next) {
	$entries++;
}

my $parsetime = time - $starttime;

warn "Parsed $entries entries in $parsetime seconds";
ok(1, "Parsed $entries entries in $parsetime seconds");
