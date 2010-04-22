#!perl -wT

use Test::More tests => 19;

use strict;
use IO::File;
use BibTeX::Parser;

my $fh = IO::File->new("t/bibs/06.bib");

my $parser = new BibTeX::Parser $fh;


my $entry = $parser->next;

isa_ok($entry, 'BibTeX::Parser::Entry', "Correct type");
ok($entry->parse_ok, "Entry parsed correctly");
is($entry->type, "ARTICLE", "BibTeX type is correct");
is($entry->field("title"), "Paper title", "Title attribute");
is($entry->field("year"), 2008);
is($entry->field("month"), "August", "Month expansion");
is($entry->key, 'key1', "key");

my @authors = $entry->author;
is(scalar @authors, 2, "number of authors correct");
my $author = shift @authors;
is_deeply(
	[$author->first, $author->von, $author->last, $author->jr], 
	['Gerhard', undef, 'Gossen', undef], "author correct");

$author = shift @authors;
is_deeply(
	[$author->first, $author->von, $author->last, $author->jr], 
	['Ludwig', 'van', 'Beethoven', undef], "author correct");

$entry = $parser->next;
isa_ok($entry, 'BibTeX::Parser::Entry', "Correct type");
ok($entry->parse_ok, "Entry parsed correctly");
is($entry->type, "BOOK", "BibTeX type is correct");
is($entry->field("title"), "Book title", "Title attribute");
is($entry->field("year"), 2008);
is($entry->field("month"), "August", "Month expansion");
is($entry->key, 'key2', "key");
@authors = $entry->author;
is(scalar @authors, 1, "number of authors");
is(scalar $entry->editor, 0, "number of editors");
