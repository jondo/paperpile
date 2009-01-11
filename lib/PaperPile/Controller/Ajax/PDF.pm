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
use 5.010;


sub pdf_viewer : Local {
  my ( $self, $c ) = @_;

  my $viewer_id     = $c->request->params->{viewer_id};
  my $file          = $c->request->params->{file};
  my $page          = $c->request->params->{start} + 1;
  my $zoom          = $c->request->params->{zoom};
  my $canvas_width  = $c->request->params->{canvas_width};
  my $canvas_height = $c->request->params->{canvas_height};

  my $pv;

  if ( not defined $c->session->{"viewer_$viewer_id"} ) {

    $pv = PaperPile::PDFviewer->new(
      file          => $file,
      canvas_width  => $canvas_width,
      canvas_height => $canvas_height,
    );
    $pv->init;

    $c->session->{"viewer_$viewer_id"} = $pv;
  }
  else {
    $pv = $c->session->{"viewer_$viewer_id"};
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
