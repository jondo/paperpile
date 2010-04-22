#!perl -T

use Test::More tests => 7;

use BibTeX::Parser;

my %strings = ();

$_ = 1234;
parse_ok("parse digit string");

$_ = '"simple double quoted string"';
parse_is("simple double quoted string", "- double quoted string");

$_ = '"double quotes { with embeded } brackets"';
parse_is("double quotes { with embeded } brackets", "- with embeded brackets");

$_ = '"string 1 " # "string 2"';
parse_is("string 1 string 2", "- concatenation");

$strings{test}  = "string";
$strings{other} = "text";

$_ = "test";
parse_is("string", "- string variable");

$_ = "test # other";
parse_is("stringtext", "- concatenation of string variables");

$_ = '"M{\"{u}}nchen"';
parse_is('M{\"{u}}nchen', "- escaped quote");

sub parse_ok {
	is(BibTeX::Parser::_parse_string(\%strings), $_, shift);
}

sub parse_is {
	is(BibTeX::Parser::_parse_string(\%strings), shift, shift);
}
