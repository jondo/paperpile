#!../perl5/win32/bin/perl.exe

BEGIN {
    $ENV{CATALYST_SCRIPT_GEN} = 40;
}

use Catalyst::ScriptRunner;
Catalyst::ScriptRunner->run('Paperpile', 'Server');

1;
