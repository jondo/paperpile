package Paperpile::Formats::Ris;
use Moose;

extends 'Paperpile::Formats';

sub BUILD {
  my $self = shift;
  $self->format('RIS');
  $self->readable(1);
  $self->writable(1);
}



1;



