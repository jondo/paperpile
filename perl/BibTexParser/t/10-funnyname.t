#!perl -T

use Test::More tests => 11;

use IO::File;
use BibTeX::Parser;

my $fh = IO::File->new('t/bibs/10-funnyname.bib');

my $parser = BibTeX::Parser->new($fh);

#my @result = BibTeX::Parser->_parse($fh);

my $entry = $parser->next;

is_deeply(
  $entry,
  {
    _type     =>       'ARTICLE',
    _key      =>       'testkey',
    author    =>       "A. Bar and L.M. M\"uller",
    title     =>       'foo',
    journal   =>       'journal',
    volume    =>       1,
    number    =>       1,
    pages     =>       1,
    year      =>       2008,
    _parse_ok =>       1,
    _raw      =>       '@article{testkey,
  year  = {2008},
  title = "foo",
  author = {A. Bar and L.M. M\"uller},
  journal = {journal},
  volume = {1},
  number = {1},
  pages = {1},
}',
  },
  "parse \@ARTICLE"
);

my @authors = $entry->author;

pass("->author didn't loop forever");
ok(@authors == 2, "Two authors");

is($authors[0]->first, 'A.', "A1 first name");
is($authors[0]->last, 'Bar', "A1 last name");
ok(!$authors[0]->von, "A1 no 'von'");
ok(!$authors[0]->jr, "A1 no 'jr'");

is($authors[1]->first, 'L.M.', "A2 first name");
is($authors[1]->last, 'M"uller', "A2 last name");
ok(!$authors[1]->von, "A2 no 'von'");
ok(!$authors[1]->jr, "A2 no 'jr'");

