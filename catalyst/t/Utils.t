#!/usr/bin/perl -w

use lib "../lib";
use strict;
use FindBin;
use Data::Dumper;
use Paperpile::Utils;
use File::Spec::Functions;
use Test::More 'no_plan';


my $browser=Paperpile::Utils->get_browser;
my $response=$browser->get('http://google.com');
my $content=$response->content;

ok( $browser->isa('LWP::UserAgent'), 'Requesting user agent object.' );
like($content, qr/google/, "Fetching google homepage using user agent");

my $current_script=$FindBin::Bin;
my $home=Paperpile::Utils->home;

is(catfile($home,'t'),$current_script,"home()");
is (Paperpile::Utils->path_to('t'),$current_script, "path_to");

my %config=Paperpile::Utils->get_config;

is ($config{name},'Paperpile', "get_config");


