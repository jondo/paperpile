#!perl -T

use Test::More tests => 11;

use BibTeX::Parser;
use IO::File;

use constant ENTRIES => 1;

my $fh = new IO::File "t/bibs/01.bib", "r" ;

if (defined $fh) {
	my $parser = new BibTeX::Parser $fh;

	isa_ok($parser, "BibTeX::Parser");

	my $count = 0;

	while (my $entry = $parser->next) {
		$count++;
		isa_ok($entry, "BibTeX::Parser::Entry");
		is($entry->key, "key01", "key");
		is($entry->type, "ARTICLE", "type");
		ok($entry->parse_ok, "parse_ok");
		is($entry->field("year"), 1950, "field");
		is($entry->field("month"), "January~1", "field");

		my @authors = $entry->author;
		is(scalar @authors, 2, "#authors");
		isa_ok($authors[0], "BibTeX::Parser::Author");
		is("$authors[0]", "Duck, Donald", "correct author");
	}	

	is($count, ENTRIES, "number of entries");
}

