use strict;
use warnings;
use Data::Dumper;
use Test::More 'no_plan';
use lib "../lib";
use PaperPile::Library::Source::File;
use PaperPile::Model::DB;


BEGIN { use_ok 'PaperPile::Library::Source::DB' }

my $fileSource=PaperPile::Library::Source::File->new(file=>'data/test1.ris');
$fileSource->connect;

my $model = PaperPile::Model::DB->new;

$model->empty_all();

foreach my $pub (@{$fileSource->all}){
  $model->create_pub($pub);
}

my $dbSource=PaperPile::Library::Source::DB->new();
$dbSource->connect;




my $all=$dbSource->all;
is (scalar(@$all),67,'Loading entries via all');

#my $all2=();

#while (my $pub = $source->next){
#  push @$all2, $pub;
#}

#is (scalar(@$all2),67,'Loading entries via next');
#is_deeply($all1, $all2, 'Checking for same content.');
#is ($source->total_entries,67,'Setting variable total_entries');

$dbSource->entries_per_page(10);
$dbSource->set_page(1);

my $page1=$dbSource->page;
my $page1_manual=[@{$all}[0..9]];

is (scalar(@{$page1}), 10, "Getting first page. Checking number.");
is_deeply ($page1, $page1_manual, "Getting first page. Checking content.");

# $source->set_page(7);

# my $last_page=$source->page;
# my $last_page_manual=[@{$all1}[60..66]];

# is (scalar(@{$last_page}), 7, "Getting last page. Checking number.");
# is_deeply ($last_page, $last_page_manual, "Getting last page. Checking content.");

# $source->set_page_from_offset(61,10);
# $last_page=$source->page;

# is (scalar(@{$last_page}), 7, "Getting last page by offset. Checking number.");
# is_deeply ($last_page, $last_page_manual, "Getting last page by offset. Checking content.");


# $source->set_page_from_offset(0,10);
# $page1=$source->page;

# is (scalar(@{$page1}), 10, "Getting first page by offset. Checking number.");
# is_deeply ($page1, $page1_manual, "Getting first page by offset. Checking content.");

# my $entry=$page1->[3];

# is ($source->find_id($entry->id)->{title}, $entry->{title}, 'Retrieving entry by sha1 id');



