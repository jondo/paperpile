package Paperpile::PDFextract;

use Moose;
use Paperpile::Library::Publication;
use Paperpile::Plugin::Import::PubMed;
use Data::Dumper;

has 'file'    => ( is => 'rw', isa => 'Str' );

sub match_pubmed {

  my ($self) = @_;

  my $source = Paperpile::Plugin::PubMed->new( query => $self->title );

  $source->connect;

  my $pubs=$source->page(0,10);

  print Dumper($pubs);

}



1;
