package PaperPile::Controller::Ajax::CRUD;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use PaperPile::Library::Publication;
use PaperPile::Library::Source::File;
use PaperPile::Library::Source::DB;
use PaperPile::Library::Source::PubMed;
use PaperPile::PDFviewer;
use Encode::JavaScript::UCS;
use Data::Dumper;
use 5.010;

sub insert_entry : Local {
  my ( $self, $c ) = @_;

  my $source_id = $c->request->params->{source_id};
  my $sha1      = $c->request->params->{sha1};
  my $source = $c->session->{"source_$source_id"};

  my $pub = $source->find_sha1($sha1);

  $c->model('DBI')->create_pub($pub);

  $pub->_imported(1);

  $c->stash->{success} = 'true';
  $c->forward('PaperPile::View::JSON');

}

sub delete_entry : Local {
  my ( $self, $c ) = @_;

  my $source_id = $c->request->params->{source_id};
  my $rowid     = $c->request->params->{rowid};

  my $source = $c->session->{"source_$source_id"};

  $c->model('DB')->delete_pubs( [$rowid] );

  $c->stash->{success} = 'true';
  $c->forward('PaperPile::View::JSON');

}

sub update_entry : Local {
  my ( $self, $c ) = @_;

  my $source_id = $c->request->params->{source_id};
  my $rowid     = $c->request->params->{rowid};
  my $sha1      = $c->request->params->{sha1};

  # get old data
  my $source = $c->session->{"source_$source_id"};
  my $pub = $source->find_sha1($sha1);
  my $data=$pub->as_hash;

  # apply new values to old entry
  foreach my $field (keys %{$c->request->params}){
    next if $field=~/source_id/;
    $data->{$field}=$c->request->params->{$field};
  }

  my $newPub=PaperPile::Library::Publication->new($data);

  $c->model('DB')->delete_pubs( [$rowid] );

  $c->model('DB')->create_pub($newPub);


  $c->stash->{success} = 'true';
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
