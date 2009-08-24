package Paperpile::Formats::Endnote;
use Moose;

extends 'Paperpile::Formats';

sub BUILD {
  my $self = shift;
  $self->format('ENDNOTE');
  $self->readable(1);
  $self->writable(1);
}



1;



