package Paperpile::Formats::Mods;
use Moose;

extends 'Paperpile::Formats';

sub BUILD {
  my $self = shift;
  $self->format('MODS');
  $self->readable(1);
  $self->writable(1);
}



1;



