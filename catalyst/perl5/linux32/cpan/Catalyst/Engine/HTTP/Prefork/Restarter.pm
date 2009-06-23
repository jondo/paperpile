package Catalyst::Engine::HTTP::Prefork::Restarter;

use strict;

use Catalyst::Engine::HTTP::Restarter::Watcher;
use File::Spec;

use constant DEBUG => $ENV{CATALYST_PREFORK_DEBUG} || 0;

sub init {
    my ( $class, $options ) = @_;
    
    if ( my $pid = fork ) {
        DEBUG && warn "Restarting: Running ($pid)\n";
        return;
    }
    
    $0 .= ' [Prefork::Restarter]';
    
    # Prepare
    close STDIN;
    close STDOUT;

    my $watcher = Catalyst::Engine::HTTP::Restarter::Watcher->new(
        directory       => ( 
            $options->{restart_directory} || 
            File::Spec->catdir( $FindBin::Bin, '..' )
        ),
        follow_symlinks => $options->{follow_symlinks},
        regex           => $options->{restart_regex},
        delay           => $options->{restart_delay},
    );
    
    while (1) {
        # poll for changed files    
        my @changed_files = $watcher->watch();

        # check if our parent process has died
        exit if $^O ne 'MSWin32' and getppid == 1;
        
        # Restart if any files have changed
        if (@changed_files) {
            my $files = join ', ', @changed_files;
            print STDERR qq/File(s) "$files" modified, restarting\n\n/;
            
            kill HUP => getppid;
            
            exit;
        }
    }
}

1;