use strict;
use warnings;
use Data::Dumper;
use Test::More 'no_plan';
use lib "../../../lib";

use Paperpile::Library::Publication;

BEGIN { use_ok 'Paperpile::Plugins::Import::PubMed' }

#my $source=Paperpile::Library::Source::PubMed->new(query=>'Stadler');
#$source->connect;
#my $pubs=$source->page_from_offset(0,10);
#print Dumper($pubs);

#my $pub=Paperpile::Library::Publication->new(doi=>'10.1111/j.1365-2958.2008.06495.x');
my $plugin=Paperpile::Plugins::Import::PubMed->new();
#$pub=$plugin->match($pub);
#is ($pub->authors, "Hemm, MR and Paul, BJ and Schneider, TD and Storz, G and Rudd, KE", "match doi");
#my $title="Significance of Nucleotide Sequence Alignments: A Method for Random Sequence Permutation That Preserves Dinucleotide and Codon Usage";
#$pub=Paperpile::Library::Publication->new(title=>$title);
#$pub=$plugin->match($pub);
#is ($pub->authors, "Altschul, SF and Erickson, BW", "match title");


my $title="Limitations and Pitfalls in Protein Identification by Mass Spectrometry";
my $authors="Lubec, G and Afjehi-Sadat, L";

my $pub=Paperpile::Library::Publication->new(title=>$title, authors=>$authors);
$pub=$plugin->match($pub);

print STDERR Dumper($pub);



