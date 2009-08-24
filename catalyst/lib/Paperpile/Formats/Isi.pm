package Paperpile::Formats::Isi;
use Moose;

extends 'Paperpile::Formats';

sub BUILD {
  my $self = shift;
  $self->format('ISI');
  $self->readable(1);
  $self->writable(1);
}



1;



