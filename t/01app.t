use strict;
use warnings;
use Test::More tests => 4;
use lib "../lib";

BEGIN { use_ok 'Catalyst::Test', 'PaperPile' }

ok( request('/')->is_success, 'Request should succeed' );


