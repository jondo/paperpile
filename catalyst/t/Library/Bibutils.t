#!/usr/bin/perl -w

use lib "../../lib/";
use strict;
use Paperpile::Library::Publication;
use Paperpile::Library::Publication::Bibutils;
use Bibutils;
use Data::Dumper;
use Digest::SHA1;
use Encode qw(encode_utf8);
use Test::More 'no_plan';
use Test::Deep;
use 5.010;

my $bu = Bibutils->new(
  in_file => '../data/test.bib',
  out_file  => '../data/new.bib',
  in_format => Bibutils::BIBTEXIN,
  out_format => Bibutils::BIBTEXOUT,
);

$bu->read;

my @data = @{ $bu->get_data };

my $pub = Paperpile::Library::Publication->new;

my @expected_types = qw/ARTICLE ARTICLE INBOOK INBOOK BOOK BOOK BOOK INCOLLECTION
  INCOLLECTION BOOK MANUAL MANUAL MASTERSTHESIS MASTERSTHESIS MISC MISC INPROCEEDINGS
  INPROCEEDINGS INPROCEEDINGS PROCEEDINGS PROCEEDINGS PROCEEDINGS PHDTHESIS PHDTHESIS
  TECHREPORT TECHREPORT UNPUBLISHED UNPUBLISHED/;

foreach my $i ( 0 .. $#data ) {
  next if $expected_types[$i] eq 'BOOKLET';    # not currently handled
  my $type = $pub->_get_type_from_bibutils( $data[$i] );
  is( $type, $expected_types[$i],
    "Get publication type from bibutils data (" . $expected_types[$i] . ")" );

}

foreach my $i ( 0 .. 27 ) {

  next if $i ~~ [8,9]; # Bibutils has a trailing '|' for the editor
                       # (eg. Lawrie|D|) which is inconsistent because it
                       # usually does not have it elsewhere

  next if $i ~~ [25]; # Bibutils can't handle 'type' field in TECHREPORTS

  $pub = Paperpile::Library::Publication->new;
  $pub->_build_from_bibutils( $data[$i] );

  my $new_data = $pub->_format_bibutils;

  cmp_bag( $new_data, $data[$i], "check self-consistent input/output ($i, ".$pub->citekey.")");

  foreach my $line (sort {$a->{tag} cmp $b->{tag}} @$new_data) {
#    print STDERR join( " ", $line->{tag}, "'" . $line->{data} . "'", $line->{level} ), "\n";
  }
#  print STDERR ">>>>>>>>>>>>>>>>>\n";
  foreach my $line ( sort {$a->{tag} cmp $b->{tag}} @{ $data[$i] } ) {
#    print STDERR join( " ", $line->{tag}, "'" . $line->{data} . "'", $line->{level} ), "\n";
  }
}

# This is the second entry of test.bib as string:
my $string=<<'END';
@ARTICLE{article-full,
   author = "Leslie A. Aamport and Joe-Bob Missilany",
   title = {The Gnats and Gnus Document Preparation System},
   journal = {G-Animal's Journal},
   year = 1986,
   volume = 41,
   number = 7,
   pages = "73+",
   month = jul,
   note = "This is a full ARTICLE entry",
}
END

$pub->import_string($string,'BIBTEX');

my $pub1 = Paperpile::Library::Publication->new;
$pub1->_build_from_bibutils( $data[1] );

is_deeply($pub,$pub1,"Import from string.");
