package PaperPile::Controller::Ajax;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use PaperPile::Library::Source::File;
use PaperPile::Library::Source::DB;
use PaperPile::Library::Source::PubMed;
use Data::Dumper;

sub insert_entry : Local {
  my ( $self, $c ) = @_;

  my $source_id = $c->request->params->{source_id};
  my $sha1    = $c->request->params->{sha1};

  my $source = $c->session->{"source_$source_id"};

  my $pub = $source->find_sha1($sha1);

  $c->model('DB')->create_pub($pub);

  $pub->imported(1);

  $c->stash->{return_value} = 1;
  $c->forward('PaperPile::View::JSON');

}

sub delete_entry : Local {
  my ( $self, $c ) = @_;

  my $source_id = $c->request->params->{source_id};
  my $sha1    = $c->request->params->{sha1};

  my $source = $c->session->{"source_$source_id"};

  my $pub = $source->find_sha1($sha1);

  $c->model('DB')->delete_pubs([$pub->rowid]);

  $c->stash->{return_value} = 1;
  $c->forward('PaperPile::View::JSON');

}

sub import_journals :Local {
  my ( $self, $c ) = @_;

  $c->model('DB')->import_journal_file("/home/wash/play/PaperPile/data/jabref.txt");
  $c->stash->{return_value} = 1;
  $c->forward('PaperPile::View::JSON');

}



sub delete_grid : Local {
  my ( $self, $c ) = @_;
  my $source_id = $c->request->params->{source_id};

  delete($c->session->{"source_$source_id"});

  $c->forward('PaperPile::View::JSON');
}

sub reset_session : Local {

  my ( $self, $c ) = @_;

  foreach my $key ( keys %{ $c->session } ) {
    delete( $c->session->{$key} ) if $key =~ /^source/;
  }

  $c->forward('PaperPile::View::JSON');

}

sub resultsgrid : Local {

  my ( $self, $c) = @_;
  my $source;

  my $source_id    = $c->request->params->{source_id};
  my $source_file  = $c->request->params->{source_file};
  my $source_query = $c->request->params->{source_query};
  my $source_type  = $c->request->params->{source_type};
  my $task         = $c->request->params->{source_task};
  my $offset       = $c->request->params->{start};
  my $limit        = $c->request->params->{limit};

  if ( not defined $c->session->{"source_$source_id"} or $task eq 'NEW' ) {

    if ( $source_type eq 'FILE' ) {
      $source = PaperPile::Library::Source::File->new( file => $source_file );
    }
    elsif ( $source_type eq 'DB' ) {
      $source = PaperPile::Library::Source::DB->new();
    }
    elsif ( $source_type eq 'PUBMED' ) {
      $source =
        PaperPile::Library::Source::PubMed->new( query => $source_query );
    }

    $source->connect;

    if ($source->total_entries == 0){
      _resultsgrid_format(@_, [], 0);
    }

    $c->session->{"source_$source_id"} = $source;
  }
  else {
    $source = $c->session->{"source_$source_id"};
  }

  $source->entries_per_page($limit);

  my $entries;

  if ( $source_type eq 'PUBMED' ) {
    $entries = $source->page_from_offset( $offset, $limit );
  }
  else {
    $source->set_page_from_offset( $offset, $limit );
    $entries = $source->page;
  }

  foreach my $pub (@$entries){
    $pub->imported($c->model('DB')->is_in_DB($pub->sha1));
  }

  _resultsgrid_format(@_, $entries, $source->total_entries);

}

sub _resultsgrid_format{

  my ( $self, $c, $entries, $total_entries ) = @_;

  my @data = ();

  foreach my $pub (@$entries) {
    push @data, $pub->as_hash;
  }


  my @fields = ();

  foreach my $key ( keys %{ $entries->[0] } ) {
    push @fields, { name => $key };
  }

  my %metaData = (
                  totalProperty => 'total_entries',
                  root          => 'data',
                  id            => 'sha1',
                  fields        => [@fields]
                 );
  $c->stash->{total_entries} = $total_entries;
  $c->stash->{data}          = [@data];
  $c->stash->{metaData}      = {%metaData};

  $c->detach('PaperPile::View::JSON');

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
