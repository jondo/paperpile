package PaperPile::Controller::Ajax::Grid;

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

sub resultsgrid : Local {

  my ( $self, $c ) = @_;
  my $source;

  my $source_id    = $c->request->params->{source_id};
  my $source_file  = $c->request->params->{source_file};
  my $source_query = $c->request->params->{source_query};
  my $source_type  = $c->request->params->{source_type};
  my $task         = $c->request->params->{source_task} || '';
  my $offset       = $c->request->params->{start};
  my $limit        = $c->request->params->{limit};

  if ( not defined $c->session->{"source_$source_id"} or $task eq 'NEW' ) {

    if ( $source_type eq 'FILE' ) {
      $source = PaperPile::Library::Source::File->new( file => $source_file );
    }
    elsif ( $source_type eq 'DB' ) {
      $source = PaperPile::Library::Source::DB->new( query => $source_query );
    }
    elsif ( $source_type eq 'PUBMED' ) {
      $source =
        PaperPile::Library::Source::PubMed->new( query => $source_query );
    }

    $source->limit($limit);
    $source->connect;

    if ( $source->total_entries == 0 ) {
      _resultsgrid_format( @_, [], 0 );
    }

    $c->session->{"source_$source_id"} = $source;
  }
  else {
    $source = $c->session->{"source_$source_id"};
  }

  my $entries;

  $entries = $source->page( $offset, $limit );

  foreach my $pub (@$entries) {
    if ( not $source_type eq 'DB' ) {
      $pub->_imported( $c->model('DBI')->exists_pub( $pub->sha1 ) );
    }
    else {
      $pub->_imported(1);
    }
  }

  _resultsgrid_format( @_, $entries, $source->total_entries );

}

sub _resultsgrid_format {

  my ( $self, $c, $entries, $total_entries ) = @_;

  my @data = ();

  foreach my $pub (@$entries) {
    push @data,  $pub->as_hash;
  }

  my @fields = ();

  foreach my $key ( keys %{ PaperPile::Library::Publication->new()->as_hash } )
  {
    push @fields, { name => $key };
  }

  my %metaData = (
    totalProperty => 'total_entries',
    root          => 'data',
    id            => 'sha1',
    fields        => [@fields]
  );

  $c->component('View::JSON')->encoding('utf8');

  $c->stash->{total_entries} = $total_entries;
  $c->stash->{data}          = [@data];
  $c->stash->{metaData}      = {%metaData};
  $c->detach('PaperPile::View::JSON');

}

sub delete_grid : Local {
  my ( $self, $c ) = @_;
  my $source_id = $c->request->params->{source_id};

  delete( $c->session->{"source_$source_id"} );

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
