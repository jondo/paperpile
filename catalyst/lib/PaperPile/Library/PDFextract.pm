package PaperPile::Library::PDFextract;

use Moose;
use PaperPile::Library::Publication;
use PaperPile::Library::Source::PubMed;
use Data::Dumper;

has 'file'    => ( is => 'rw', isa => 'Str' );

sub match_pubmed {

  my ($self) = @_;

  my $source = PaperPile::Library::Source::PubMed->new( query => $self->title );

  $source->connect;

  my $pubs=$source->page(0,10);

  print STDERR Dumper($pubs);

}



1;
