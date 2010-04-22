#!perl -T

use Test::More tests => 3;

BEGIN {
	use_ok( 'BibTeX::Parser' );
	use_ok( 'BibTeX::Parser::Author' );
	use_ok( 'BibTeX::Parser::Entry' );
}

diag( "Testing BibTeX::Parser $BibTeX::Parser::VERSION, Perl $], $^X" );
