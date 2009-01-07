package PaperPile::PDFviewer::Page;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;
use Carp;
use PDF::API2;

has 'width'  => ( is => 'rw', isa => 'Int' );
has 'height' => ( is => 'rw', isa => 'Int' );
has 'res' => ( is => 'rw', isa => 'Int' );  # resolution to optimally fit canvas

sub fit_res {
  my ( $self, $canvas_width, $canvas_height ) = @_;

  # Calculate the resolution we have to set to get the desired width and heigth
  # Ghostscript driver calculates with 72 dpi
  $self->res( int( 72 * $canvas_width / $self->width ) );

}

1;
