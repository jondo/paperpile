#!/usr/bin/perl -w

# Dummy script for Module::Scandeps

BEGIN { 
    $ENV{CATALYST_ENGINE} ||= 'HTTP';
    $ENV{CATALYST_SCRIPT_GEN} = 31;
    require Catalyst::Engine::HTTP;
}

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use FindBin;
use lib "$FindBin::Bin/../catalyst/lib";

use Catalyst::Engine::HTTP;
use Sys::Hostname;
use Storable;
use DBD::SQLite;
use Digest::MD5;


my $debug             = 0;
my $fork              = 0;
my $help              = 0;
my $host              = undef;
my $port              = 3000;
my $keepalive         = 0;
my $restart           = 0;
my $restart_delay     = 1;
my $restart_regex     = '(?:/|^)(?!\.#).+(?:\.yml$|\.yaml$|\.conf|\.pm)$';
my $restart_directory = undef;
my $follow_symlinks   = 0;

my @argv = @ARGV;

if ( $restart && $ENV{CATALYST_ENGINE} eq 'HTTP' ) {
    $ENV{CATALYST_ENGINE} = 'HTTP::Restarter';
}
if ( $debug ) {
    $ENV{CATALYST_DEBUG} = 1;
}

# Use CGI for now, as we can't kill the HTTP server after we have started it.
$ENV{CATALYST_ENGINE} = 'CGI';

require Paperpile;

Paperpile->run( $port, $host, {
    argv              => \@argv,
    'fork'            => $fork,
    keepalive         => $keepalive,
    restart           => $restart,
    restart_delay     => $restart_delay,
    restart_regex     => qr/$restart_regex/,
    restart_directory => $restart_directory,
    follow_symlinks   => $follow_symlinks,
} );



1;
