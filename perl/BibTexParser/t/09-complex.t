#!perl -T

use Test::More tests => 1;

use IO::File;
use BibTeX::Parser;


my $fh = IO::File->new('t/bibs/09-complex.bib');

my $parser = new BibTeX::Parser $fh;

#my @result = BibTeX::Parser->_parse($fh);

my $entry = $parser->next;

is_deeply($entry, {_type => 'ARTICLE', _key => 'Ahrenberg88',
    author =>       "L. Ahrenberg and A. Jonsson",
    title =>        "An interactive system for tagging dialogues",
    journal =>      'Literary & Linguistic Computing',
    volume =>       3,
    number =>       "2",
    pages =>        "66--70",
    year =>         "1988",
    keywords =>     "conver",
   _parse_ok => 1,
   _raw => '@Article{Ahrenberg88,
    author =       "L. Ahrenberg and A. Jonsson",
    title =        "An interactive system for tagging dialogues",
    journal =      "Literary \& Linguistic Computing",
    volume =       "3",
    number =       "2",
    pages =        "66--70",
    year =         "1988",
    keywords =     "conver",
}'
   }, "parse \@ARTICLE");
