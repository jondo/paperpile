#!/usr/bin/perl -w

use lib "../lib";
use strict;
use FindBin;
use Data::Dumper;
use PaperPile::Utils;
use File::Spec::Functions;
use Test::More 'no_plan';


my $browser=PaperPile::Utils->get_browser;
my $response=$browser->get('http://google.com');
my $content=$response->content;

ok( $browser->isa('LWP::UserAgent'), 'Requesting user agent object.' );
like($content, qr/google/, "Fetching google homepage using user agent");

my $current_script=$FindBin::Bin;
my $home=PaperPile::Utils->home;

is(catfile($home,'t'),$current_script,"home()");
is (PaperPile::Utils->path_to('t'),$current_script, "path_to");

my %config=PaperPile::Utils->get_config;

is ($config{name},'PaperPile', "get_config");


