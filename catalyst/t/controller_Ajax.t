use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'Paperpile' }
BEGIN { use_ok 'Paperpile::Controller::Ajax' }

ok( request('/ajax')->is_success, 'Request should succeed' );


