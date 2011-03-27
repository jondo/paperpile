use strict;
use warnings;
use Data::Dumper;
use Test::More 'no_plan';
use lib "../../../lib";
use Exception::Class;

BEGIN { use_ok 'Paperpile::Plugins::Import::Feed' }

binmode STDOUT, ":utf8";    # avoid unicode errors when printing to STDOUT

my $import;


#$import=Paperpile::Plugins::Import::Rss->new(id => "xyz123",
#                                             query => "http://feeds.nature.com/nature/rss/current?format=xml" );

#$import->connect();


my $title = "This is a very long title I'd like to break";


if (length($title) > 15){

  ($title) = $title =~ /(.{1,15}\W)/gms;
}

print STDERR "$title\n";
