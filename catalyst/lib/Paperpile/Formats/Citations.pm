package Paperpile::Formats::Citations;

use Moose;
use Data::Dumper;
use IO::File;

extends 'Paperpile::Formats';

sub BUILD {
  my $self = shift;
  $self->format('CITATIONS');
  $self->readable(0);
  $self->writable(1);
}

sub write {
  my ($self) = @_;

  open( OUT, ">" . $self->file )
    || FileReadError->throw( error => "Could not write to file " . $self->file );
  
  my @strings = ();
  foreach my $pub ( @{ $self->data } ) {
      push @strings, $self->format_pub($pub);
  }
  print OUT join("\n",@strings);
  close(OUT);
}

sub format_pub {
    my $self = shift;
    my $pub = shift;
    
    my $string = $pub->format_citation;

    return $string;
}

1;
