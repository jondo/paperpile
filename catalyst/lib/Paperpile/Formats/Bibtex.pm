package Paperpile::Formats::Bibtex;
use Moose;

extends 'Paperpile::Formats';

sub BUILD {
  my $self = shift;
  $self->format('BIBTEX');
  $self->readable(1);
  $self->writable(1);
}



1;



