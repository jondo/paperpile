#!perl -T

use Test::More tests => 1;

use IO::String;
use BibTeX::Parser;

my $string = q|@article{lin1973,
   author = "Shen Lin and Brian W. Kernighan",
   title = "An Effective Heuristic Algorithm for the Travelling-Salesman Problem",
   journal = "Operations Research",
   volume = 21,
   year = 1973,
   pages = "498--516"
}|;
my $fh = IO::String->new($string);

my $parser = new BibTeX::Parser $fh;

#my @result = BibTeX::Parser->_parse($fh);

my $entry = $parser->next;

is_deeply($entry, {_type => 'ARTICLE', _key => 'lin1973', author => "Shen Lin and Brian W. Kernighan",
   title => "An Effective Heuristic Algorithm for the Travelling-Salesman Problem",
   journal => "Operations Research",
   volume => 21,
   year => 1973,
   pages => "498--516", _parse_ok => 1,
   _raw => $string}, "parse \@ARTICLE");

