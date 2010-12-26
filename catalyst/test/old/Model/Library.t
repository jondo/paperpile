use strict;
use warnings;
use Test::More 'no_plan';
use Test::Deep;
use Data::Dumper;
use File::Copy;
use MooseX::Timestamp;

use lib "../../lib";
use Paperpile::Library::Publication;

BEGIN { use_ok 'Paperpile::Model::Library' }

my $model = Paperpile::Model::Library->new();

$model->set_dsn( "dbi:SQLite:" . "/home/wash/.paperpile/paperpile.ppl" );

my $all = $model->all_as_hash();

my @out=();

foreach my $h (@$all){
  push @out, Paperpile::Library::Publication->new(%$h);
}

foreach my $h (@out){
  print STDERR $h->title, "\n";
}

#print STDERR Dumper(\@all);

# copy( "../../db/local-user.db", "../data/tmp.db" )
#   || die(
#   "No file local-user.db. Run Paperpile once to init the application and generate this file.");

# my $model = Paperpile::Model::User->new();

# $model->set_dsn( "dbi:SQLite:" . "../data/tmp.db" );

# my $data = _read_data("../data/db_test.bib");

# my $expectedCount = 29;

# my @expected_keys = qw /
#   Birney2007
#   Fontana1993
#   Fontana1993a
#   Gardner2005
#   Gesell2008
#   Gruber2008
#   Hofacker1994
#   Hofacker1998
#   Hofacker1998a
#   Hofacker2002
#   Hofacker2004
#   Huynen1996
#   Kapranov2007
#   Reidys1997
#   Reidys2002
#   Rose2007
#   Schuster1994
#   Schuster1994a
#   Stadler1992
#   Stadler1993
#   Stadler1996
#   Stadler2001
#   Tacker1996
#   Tanzer2004
#   Washietl2005
#   Washietl2005a
#   Washietl2007
#   Washietl2007a
#   Washietl2007b
#   /;

# $model->create_pubs($data);

# ( my $count ) = $model->dbh->selectrow_array("SELECT count(*) FROM Publications");
# is( $count, $expectedCount, "Insert entries into database. " );

# my @inserted_keys = ();
# foreach my $pub (@$data) {
#   push @inserted_keys, $pub->citekey;
# }

# cmp_bag( [@inserted_keys], [@expected_keys],
#   "Generating non-redundant citation keys upon insertion (1)" );

# my $extra_pub = Paperpile::Library::Publication->new( {
#     citekey => "Washietl2007",
#     authors => 'Washietl, S.',
#     title   => 'Extra',
#     pubtype => 'MISC',
#     year    => '2007'
#   }
# );

# $model->create_pubs( [$extra_pub] );

# ( my $key ) = $model->dbh->selectrow_array("SELECT citekey FROM Publications WHERE title='Extra'");

# is( $key, 'Washietl2007c', 'Generating non-redundant citation keys upon insertion (2)' );

# push @expected_keys, "Washietl2007c";
# s/(20|19)// foreach (@expected_keys);

# $model->update_citekeys('[firstauthor][YY]');

# my @keys=();
# my $sth=$model->dbh->prepare("SELECT citekey FROM Publications");
# $sth->bind_columns( \$key );
# $sth->execute;

# while ( $sth->fetch ) {
#   push @keys, $key;
# }

# cmp_bag( [@keys], [@expected_keys],
#          "Updating citation keys" );

# print STDERR "Last message\n";

# sub _read_data {

#   my $in_file = shift;

#   my $bu = Bibutils->new(
#     in_file   => $in_file,
#     in_format => Bibutils::BIBTEXIN,
#   );

#   $bu->read;

#   my @data = ();

#   foreach my $entry ( @{ $bu->get_data } ) {
#     my $pub = Paperpile::Library::Publication->new;
#     $pub->_build_from_bibutils($entry);

#     $pub->created(timestamp);
#     $pub->times_read(0);
#     $pub->last_read(timestamp);

#     push @data, $pub;
#   }
#   return [@data];
# }
# unlink("../data/tmp.db");
