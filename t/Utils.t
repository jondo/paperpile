#!/usr/bin/perl -w

use lib "../lib";
use PaperPile::Utils;
use Test::More 'no_plan';


my $browser=PaperPile::Utils->get_browser;
my $response=$browser->get('http://google.com');
my $content=$response->content;

ok( $browser->isa('LWP::UserAgent'), 'Requesting user agent object.' );
like($content, qr/google/, "Fetching google homepage using user agent");
