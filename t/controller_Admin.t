use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'PaperPile' }
BEGIN { use_ok 'PaperPile::Controller::Admin' }

ok( request('/admin')->is_success, 'Request should succeed' );


