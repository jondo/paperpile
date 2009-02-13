package PaperPile::PDFviewer;
use PaperPile::PDFviewer::Page;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;
use File::Temp qw/ tempfile tempdir /;
use Carp;
use File::Path;
use File::Basename;
use File::Spec;
use PDF::API2;

# Must be a way to get these from Catalyst, use hardcoded dirs for now...
my $tmpdir  = '/home/wash/play/PaperPile/root/tmp/PDF';
my $rootdir = '/home/wash/play/PaperPile/root';

has 'file'    => ( is => 'rw', isa => 'Str' );
has 'root_dir' => ( is => 'rw', isa => 'Str' );
has '_tmpdir' => ( is => 'rw', isa => 'Str' );
has 'pages'   => ( is => 'rw', isa => 'ArrayRef[PaperPile::PDFviewer::Page]' );
has 'curr_page'     => ( is => 'rw', isa => 'Int', default => 1 );
has 'num_pages'     => ( is => 'rw', isa => 'Int' );
has 'key'           => ( is => 'rw', isa => 'Str' );
has 'canvas_width'  => ( is => 'rw', isa => 'Int' );
has 'canvas_height' => ( is => 'rw', isa => 'Int' );

sub init {
  my ($self) = @_;

  if ( not -e $self->file ) {
    croak( "Could not open ", $self->file, "." );
  }

  my ( $key, $dir, $ext ) = fileparse( $self->file, '\..*' );
  $self->key($key);
  $self->_tmpdir( File::Spec->catdir( $tmpdir, $self->key ) );
  mkpath( $self->_tmpdir );

  my $pdf = PDF::API2->new;
  $pdf = PDF::API2->open( $self->file );

  $self->num_pages( $pdf->pages );

  my @pages = ();
  foreach my $pg ( 1 .. $self->num_pages ) {
    my ( $llx, $lly, $urx, $ury ) = $pdf->openpage($pg)->get_mediabox;
    my $width  = int( $urx - $llx );
    my $height = int( $ury - $lly );
    my $page   = PaperPile::PDFviewer::Page->new(
      width  => $width,
      height => $height
    );

    $page->fit_res( $self->canvas_width, $self->canvas_height );

    push @pages, $page;

  }

  $self->pages( [@pages] );

}

sub destroy {
  my ($self) = @_;
  rmtree $self->_tmpdir;
}

sub render_page {

  my ( $self, $pg, $zoom ) = @_;

  $zoom = 1.0 if not defined $zoom;

  my $res=$self->pages->[$pg]->res;

  my $zoomString = sprintf( "%.1f", $zoom );

  my $out =
    File::Spec->catfile( $self->_tmpdir, "page" . $pg . "x$zoomString\_$res\.png" );

  if ( not -e $out ) {
    $self->_gs( $self->file, $out, $pg, $res * $zoom );
  }

  return (File::Spec->abs2rel( $out, $rootdir ));

}

sub _gs {

  my ( $self, $in, $out, $pg, $res ) = @_;

  my $call =
      "gs -q -sDEVICE=png16m -dSAVE -dBATCH -dNOPAUSE "
    . "-dTextAlphaBits=4 -dGraphicsAlphaBits=4 "
    . "-dFirstPage=$pg -dLastPage=$pg -r$res "
    . "-sOutputFile=$out $in";

  system($call);
  sleep(1);

}

1;

