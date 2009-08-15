package Paperpile::Formats::Endnotexml;
use Moose;

extends 'Paperpile::Formats';

sub BUILD {
  my $self = shift;
  $self->format('ENDNOTEXML');
  $self->readable(1);
  $self->writable(0);
}

1;



