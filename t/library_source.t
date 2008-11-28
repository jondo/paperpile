use strict;
use warnings;
use Data::Dumper;

use Test::More 'no_plan';

use lib "../lib";

BEGIN { use_ok 'PaperPile::Library::Source::File' }


# test1.ris contains 67 entries
my $source=PaperPile::Library::Source::File->new(file=>'data/test1.ris');

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
$source->set_page(1);

my $page1=$source->page;
my $page1_manual=[@{$all1}[0..9]];

is (scalar(@{$page1}), 10, "Getting first page. Checking number.");
is_deeply ($page1, $page1_manual, "Getting first page. Checking content.");

$source->set_page(7);

my $last_page=$source->page;
my $last_page_manual=[@{$all1}[60..66]];

is (scalar(@{$last_page}), 7, "Getting last page. Checking number.");
is_deeply ($last_page, $last_page_manual, "Getting last page. Checking content.");

$source->set_page_from_offset(61,10);
$last_page=$source->page;

is (scalar(@{$last_page}), 7, "Getting last page by offset. Checking number.");
is_deeply ($last_page, $last_page_manual, "Getting last page by offset. Checking content.");


$source->set_page_from_offset(0,10);
$page1=$source->page;

is (scalar(@{$page1}), 10, "Getting first page by offset. Checking number.");
is_deeply ($page1, $page1_manual, "Getting first page by offset. Checking content.");
