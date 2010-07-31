package Paperpile::Formats::Email;

use Moose;
use Data::Dumper;
use IO::File;
use Text::Wrap;

extends 'Paperpile::Formats';

sub BUILD {
  my $self = shift;
  $self->format('EMAIL');
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
  my $cr = "%0A";
  print OUT join( "$cr$cr", @strings );
  close(OUT);
}

# Formats a publication into a string suitable for pasting into an e-mail message.
sub format_pub {

  my ( $self, $pub ) = @_;

  my $citation = $pub->format_citation;

  $citation =~ s!</?\w>!!g;

  my $cr = "%0A";

  my $title   = $pub->title;
  my $authors = $self->format_authors($pub);
  my $citation = $pub->_citation_display;
  $citation =~ s!</?\w>!!g;
  my $link    = $pub->best_link;

  my $string = ( $title ? "$title" : '' );
  $string .= ( $authors ? "$cr$authors" : '' );
  $string .= ( $citation ? "$cr$citation" : '' );
  $string .= ( $link    ? "$cr$link"       : '' );

  return "$string";
}

sub format_authors {
  my ( $self, $pub ) = @_;

  my @display = ();
  my $tmp     = Paperpile::Library::Author->new();

  if ( $pub->authors ) {
    foreach my $a ( split( /\band\b/, $pub->authors ) ) {
      $tmp->full($a);
      push @display, $tmp->nice;
      $tmp->clear;
    }

    my $max_num_authors = 6;
    if ( scalar(@display) > $max_num_authors + 1 ) {
      my $n         = $max_num_authors / 2;
      my $n_skipped = scalar(@display) - $max_num_authors;
      my $max_index = scalar(@display) - 1;
      my @before    = @display[ 0 .. ( $n - 1 ) ];
      my @after     = @display[ $max_index - $n + 1 .. $max_index ];
      @display = @before;
      push @display, " ... ($n_skipped others) ... ";
      push @display, @after;
    }
    return join( ', ', @display );
  }
  return '';
}

1;
