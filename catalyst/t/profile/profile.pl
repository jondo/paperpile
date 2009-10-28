#!/home/wash/play/paperpile/catalyst/perl5/linux64/bin/perl -w
##!/home/wash/play/paperpile/catalyst/perl5/linux64/bin/perl -d:NYTProf -w

use strict;
use Data::Dumper;
use lib '../../lib';
use Paperpile::Library::Publication;
use Bibutils;

my %journal = (
  pubtype  => 'JOUR',
  title    => 'Strategies for measuring evolutionary conservation of RNA secondary structures',
  journal  => 'BMC Bioinformatics',
  authors  => 'Gruber, AR and Bernhart, SH and  Hofacker, I.L. and Washietl, S.',
  volume   => '9',
  pages    => '122',
  year     => '2008',
  month    => 'Feb',
  day      => '26',
  issn     => '1471-2105',
  pmid     => '18302738',
  doi      => '10.1186/1471-2105-9-122',
  url      => 'http://www.biomedcentral.com/1471-2105/9/122',
  abstract => 'BACKGROUND: Evolutionary conservation of RNA secondary structure..',
  notes    => 'These are my notes',
  tags     => 'RNA important cool awesome',
  pdf      => 'some/folder/to/pdfs/gruber2008.pdf',
);

#foreach my $i (0..5000){
#  my $pub = Paperpile::Library::Publication->new( {%journal} );
#}

#exit;

my $bu = Bibutils->new(
  in_file    => 'test.bib',
  out_file   => 'new.bib',
  in_format  => Bibutils::BIBTEXIN,
  out_format => Bibutils::BIBTEXOUT,
);

## Reading file
$bu->read;

## Getting data
my $data = $bu->get_data;

my @pubs = ();

foreach my $entry (@$data) {
  my $pub = Paperpile::Library::Publication->new();
  $pub->_build_from_bibutils($entry);

  push @pubs, $pub;

}

#print Dumper(\@pubs);
