#!/home/wash/play/paperpile/catalyst/perl5/linux64/bin/perl -w
##!/home/wash/play/paperpile/catalyst/perl5/linux64/bin/perl -d:NYTProf -w

use strict;
use Data::Dumper;
use lib '../../lib';
use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Bibutils;

use Paperpile::Model::Library;
use JSON;


my $x='asdfs';

print $x+0;

exit;

my $model = Paperpile::Model::Library->new();
$model->set_dsn("dbi:SQLite:test.db");

$model->light_objects(0);


my %journal = (
  pubtype     => 'JOUR',
  title       => 'Strategies for measuring evolutionary conservation of RNA secondary structures',
  journal     => 'BMC Bioinformatics',
  authors     => 'Gruber, AR and Stadler, PF and Washietl, S and Hofacker, IL',
  volume      => '9',
  pages       => '122',
  year        => '2008',
  month       => 'Feb',
  day         => '26',
  attachments => 0,
  issn        => '1471-2105',
  pmid        => '18302738',
  doi         => '10.1186/1471-2105-9-122',
  url         => 'http://www.biomedcentral.com/1471-2105/9/122',
  abstract    => 'BACKGROUND: Evolutionary conservation of RNA secondary structure..',
  notes       => 'These are my notes',
  tags        => 'RNA important cool awesome',
  pdf         => 'some/folder/to/pdfs/gruber2008.pdf',
  _light      => 1
);

my $pub = Paperpile::Library::Publication->new({_light=>1});
my $key = 'attachments';
$pub->$key(0);

my $d = {x=>$pub->attachments(), y=>0, z=>'0'};

#print $d->{x} eq $d->{y};

print Dumper($d), "\n";

my $j  = to_json($d);
print $j;
exit;






exit;


#my $pub;

#foreach my $i (1..5000){

#}

#$model->light_objects(1);
#my $pubs = $model->all();

#`cp ../../db/library.db  ./test2.db`;
#my $model2 = Paperpile::Model::Library->new();
#$model2->set_dsn("dbi:SQLite:test2.db");

#$model2->create_pubs($pubs);

#exit;

#$model->dbh->begin_work();
#my $dbh=$model->dbh;
#foreach my $x (0..4000){

#  $dbh->quote('adsfsdf');
#  $dbh->quote('adsfsdf');
#  $dbh->quote('adsfsdf');
#  $dbh->quote('adsfsdf');
#  $dbh->quote('adsfsdf');
#  $dbh->quote('adsfsdf');
#  $dbh->do("INSERT INTO publications ('title') VALUES ('asdfasdf')");
#print STDERR ".";
#}
#$model->dbh->commit;
#exit;

my $bu = Bibutils->new(
  in_file    => 'long.bib',
  out_file   => 'new.bib',
  in_format  => Bibutils::BIBTEXIN,
  out_format => Bibutils::BIBTEXOUT,
);

print STDERR "Reading bibutils\n";

$bu->read;

my $data = $bu->get_data;

print STDERR "Building objects\n";

my @pubs = ();

my %seen = ();

foreach my $entry (@$data) {
  my $pub = Paperpile::Library::Publication->new( { _light => 1 } );
  $pub->_build_from_bibutils($entry);

  next if not $pub->sha1;

  if ( not $seen{ $pub->sha1 } ) {
    push @pubs, $pub;
    $seen{ $pub->sha1 } = 1;
  }
}

#print Dumper(\@pubs);

print STDERR "Inserting...\n";
$model->create_pubs( [@pubs] );

my $pubs2 = $model->all();

foreach my $i ( 0 .. $#pubs ) {
  print $pubs[$i]->sha1, " vs ", $pubs2->[$i]->sha1, "\n";

  if ( $pubs[$i]->sha1 ne $pubs2->[$i]->sha1 ) {
    print Dumper( $pubs[$i] );
    print Dumper( $pubs2->[$i] );

  }

}

