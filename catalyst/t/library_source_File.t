use strict;
use warnings;
use Data::Dumper;

use Test::More 'no_plan';

use lib "../lib";

BEGIN { use_ok 'Paperpile::Library::Source::File' }

# test1.ris contains 67 entries
my $source=Paperpile::Library::Source::File->new(file=>'data/test1.ris');

$source->connect;

# test1.ris contains 67 entries

my $all1=$source->all;

is (scalar(@$all1),67,'Loading entries via all');

my $all2=();

while (my $pub = $source->next){
  push @$all2, $pub;
}

is (scalar(@$all2),67,'Loading entries via next');
is_deeply($all1, $all2, 'Checking for same content.');
is ($source->total_entries,67,'Setting variable total_entries');

$source->entries_per_page(10);

my $page1=$source->page(1);
my $page1_manual=[@{$all1}[0..9]];

is (scalar(@{$page1}), 10, "Getting first page. Checking number.");
is_deeply ($page1, $page1_manual, "Getting first page. Checking content.");

my $last_page=$source->page(7);
my $last_page_manual=[@{$all1}[60..66]];

is (scalar(@{$last_page}), 7, "Getting last page. Checking number.");
is_deeply ($last_page, $last_page_manual, "Getting last page. Checking content.");

$last_page=$source->page_from_offset(61,10);

is (scalar(@{$last_page}), 7, "Getting last page by offset. Checking number.");
is_deeply ($last_page, $last_page_manual, "Getting last page by offset. Checking content.");

$page1=$source->page_from_offset(0,10);

is (scalar(@{$page1}), 10, "Getting first page by offset. Checking number.");
is_deeply ($page1, $page1_manual, "Getting first page by offset. Checking content.");

my $entry=$page1->[3];

is ($source->find_sha1($entry->sha1)->{title}, $entry->{title}, 'Retrieving entry by sha1 id');



