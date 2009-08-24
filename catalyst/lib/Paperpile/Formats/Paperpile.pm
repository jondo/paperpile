package Paperpile::Formats::Paperpile;
use Moose;

extends 'Paperpile::Formats';

sub BUILD {
  my $self = shift;
  $self->format('PAPERPILE');
  $self->readable(1);
  $self->writable(1);
}


sub read {



}

sub write{



}



1;



