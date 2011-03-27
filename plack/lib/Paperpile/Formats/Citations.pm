package Paperpile::Formats::Citations;

use Mouse;
use Data::Dumper;
use IO::File;
use Text::Wrap;

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
  print OUT join( "\n", @strings );
  close(OUT);
}

sub format_pub {

  my ($self, $pub)  = @_;

  my $citation = $pub->format_citation;

  $citation =~ s!</?\w>!!g;

  my $string = $pub->title . "\n". $pub->_authors_display . "\n". $citation;

  $Text::Wrap::columns = 70;

  $string = wrap("","",$string);

  return "$string\n";
}

1;
