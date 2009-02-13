use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'PaperPile' }
BEGIN { use_ok 'PaperPile::Controller::Ajax' }

ok( request('/ajax')->is_success, 'Request should succeed' );


