package PaperPile::Controller::Ajax::PDF;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use PaperPile::Library::Publication;
use PaperPile::Library::Source::File;
use PaperPile::Library::Source::DB;
use PaperPile::Library::Source::PubMed;
use PaperPile::PDFviewer;
use Data::Dumper;
use XML::Simple;
use File::Temp;

use 5.010;

sub extpdf : Local {

  my ( $self, $c ) = @_;

  my $bin=$c->path_to('bin/linux64/extpdf');

  if ($c->request->params->{outFile}){
    my $new=$c->path_to('root/TMP',$c->request->params->{outFile});
    $c->request->params->{outFile}=$new;
  }


  my $xml = XMLout($c->request->params, RootName => 'extpdf', XMLDecl => 1, NoAttr => 1);

  my ($fh, $filename) = File::Temp::tempfile();
  print $fh $xml;
  close($fh);

  print STDERR $xml;

  my @output=`$bin $filename`;

  print STDERR @output;

  my $output='';
  $output.=$_ foreach @output;

  $c->response->body( $output );
  $c->response->content_type('text/xml');

}

sub pdf_viewer : Local {
  my ( $self, $c ) = @_;

  my $viewer_id     = $c->request->params->{viewer_id};
  my $file          = $c->request->params->{file};
  my $page          = $c->request->params->{start} + 1;
  my $zoom          = $c->request->params->{zoom};
  my $canvas_width  = $c->request->params->{canvas_width};
  my $canvas_height = $c->request->params->{canvas_height};

  my $pv = undef;

  # If there already exists a viewer object of the same file, use it
  if ( defined $c->session->{"viewer_$viewer_id"} ) {
    if ( $c->session->{"viewer_$viewer_id"}->file eq $file ) {
      $pv = $c->session->{"viewer_$viewer_id"};
    }
  }

  # else create a new one
  if ( not $pv ) {
    $pv = PaperPile::PDFviewer->new(
      file          => $file,
      canvas_width  => $canvas_width,
      canvas_height => $canvas_height,
      root_dir=>$c->path_to('')->stringify,
    );
    $pv->init;

    $c->session->{"viewer_$viewer_id"} = $pv;
  }

  my $image = $pv->render_page( $page, $zoom );

  my %metaData = (
    totalProperty => 'total_pages',
    root          => 'data',
    fields        => [ { name => 'image' } ]
  );

  $c->stash->{total_pages} = $pv->num_pages;
  $c->stash->{data}        = [ { image => $image } ];
  $c->stash->{metaData}    = {%metaData};

  $c->forward('PaperPile::View::JSON');

}

sub generate_edit_form : Local {
  my ( $self, $c ) = @_;

  my $pub = PaperPile::Library::Publication->new();

  my $pubtype = $c->request->params->{pubtype};

  my $form = $pub->get_form($pubtype);

  $c->stash->{form} = $form;

  $c->forward('PaperPile::View::JSON');

}

=head1 NAME

PaperPile::Controller::Ajax - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index 

=cut

sub index : Path : Args(0) {
  my ( $self, $c ) = @_;

  $c->response->body('Matched PaperPile::Controller::Ajax in Ajax.');
}

=head1 AUTHOR

Stefan Washietl,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
