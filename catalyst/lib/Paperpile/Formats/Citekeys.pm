package Paperpile::Formats::Citekeys;

use Moose;
use Data::Dumper;
use IO::File;

extends 'Paperpile::Formats';

sub BUILD {
  my $self = shift;
  $self->format('CITEKEYS');
  $self->readable(0);
  $self->writable(1);
}

sub write {
  my ($self) = @_;

  open( OUT, ">" . $self->file )
    || FileReadError->throw( error => "Could not write to file " . $self->file );

  my @keys = ();
  foreach my $pub ( @{ $self->data } ) {
    push @keys, $pub->citekey;
  }


  my $output = join(",",@keys);

  if ($self->settings->{cite_wrap}){
    $output="\\cite{$output}";
  }

  print OUT $output;
  close(OUT);
}

1;
