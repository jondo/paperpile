BEGIN {
    $ENV{PAPERPILE_SCRIPT_GEN} = 40;
}

use Catalyst::ScriptRunner;
Catalyst::ScriptRunner->run('Paperpile', 'Server');

1;



