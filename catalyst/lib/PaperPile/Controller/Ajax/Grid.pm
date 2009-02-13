package PaperPile::Controller::Ajax::Grid;

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

sub resultsgrid : Local {

  my ( $self, $c ) = @_;
  my $source;

  my $source_id    = $c->request->params->{source_id};
  my $source_file  = $c->request->params->{source_file};
  my $source_query = $c->request->params->{source_query};
  my $source_type  = $c->request->params->{source_type};
  my $source_mode  = $c->request->params->{source_mode};
  my $task         = $c->request->params->{source_task} || '';
  my $offset       = $c->request->params->{start};
  my $limit        = $c->request->params->{limit};

  if ( not defined $c->session->{"source_$source_id"} or $task eq 'NEW' ) {

    if ( $source_type eq 'FILE' ) {
      $source = PaperPile::Library::Source::File->new( file => $source_file );
    } elsif ( $source_type eq 'DB' ) {
      $source = PaperPile::Library::Source::DB->new( query => $source_query, mode => $source_mode );
    } elsif ( $source_type eq 'PUBMED' ) {
      $source = PaperPile::Library::Source::PubMed->new( query => $source_query );
    }

    $source->limit($limit);
    $source->connect;

    if ( $source->total_entries == 0 ) {
      _resultsgrid_format( @_, [], 0 );
    }

    $c->session->{"source_$source_id"} = $source;
  } else {
    $source = $c->session->{"source_$source_id"};
  }

  my $entries;
  $entries = $source->page( $offset, $limit );

  if ( $source_type eq 'DB' ) {
    foreach my $pub (@$entries) {
      $pub->_imported(1);
    }
  } else {
    $c->model('User')->exists_pub($entries);
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


sub index : Path : Args(0) {
  my ( $self, $c ) = @_;
  $c->response->body('Matched PaperPile::Controller::Ajax in Ajax.');
}


1;
