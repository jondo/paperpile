use strict;
use warnings;
use Test::More tests => 1;
use Dummy;
use Data::Dumper;
use lib "../lib";

use PaperPile::Library::Publication;


BEGIN { use_ok 'PaperPile::Model::DBI' }

# use a dummy $c object, otherwise we can't test
# here DBI::Model
my $c=Dummy->new();

my %journal = (
  pubtype => 'JOUR',
  title => 'Strategies for measuring evolutionary conservation of RNA secondary structures',
  journal => 'BMC Bioinformatics',
  authors => 'Gruber, AR and Bernhart, SH and  Hofacker, I.L. and Washietl, S.',
  volume  => '9',
  pages   => '122',
  year    => '2008',
  month   => 'Feb',
  day     => '26',
  issn    => '1471-2105',
  pmid    => '18302738',
  doi     => '10.1186/1471-2105-9-122',
  url     => 'http://www.biomedcentral.com/1471-2105/9/122',
  abstract =>'BACKGROUND: Evolutionary conservation of RNA secondary structure..',
  notes     => 'These are my notes',
  tags      => 'RNA important cool awesome',
  pdf       => 'some/folder/to/pdfs/gruber2008.pdf',
);


my $model=PaperPile::Model::DBI->new($c);
my $pub=PaperPile::Library::Publication->new( {%journal} );

$model->create_pub($pub);





