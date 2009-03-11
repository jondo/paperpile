package PaperPile::PDFextract;

use Moose;
use PaperPile::Library::Publication;
use PaperPile::Plugin::Import::PubMed;
use Data::Dumper;

has 'file'    => ( is => 'rw', isa => 'Str' );

sub match_pubmed {

  my ($self) = @_;

  my $source = PaperPile::Plugin::PubMed->new( query => $self->title );

  $source->connect;

  my $pubs=$source->page(0,10);

  print Dumper($pubs);

}



1;
