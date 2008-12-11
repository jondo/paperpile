package PaperPile::Controller::Ajax;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use PaperPile::Library::Source::File;
use Data::Dumper;

sub resultsgrid : Local {
  my ( $self, $c ) = @_;

  my $source;

  my $source_id=$c->request->params->{source_id};
  my $source_file=$c->request->params->{source_file};
  my $source_type=$c->request->params->{source_type};

  my $task=$c->request->params->{task};

  my $offset = $c->request->params->{start};
  my $limit  = $c->request->params->{limit};

  if ( not defined $c->session->{"source_$source_id"} ) {

    if ($source_type eq 'FILE'){
      $source = PaperPile::Library::Source::File->new( file => $source_file );
    }

    $source->connect;
    $c->session->{"source_$source_id"} = $source;
  }
  else {
    $source = $c->session->{"source_$source_id"};
  }

  $source->entries_per_page($limit);
  $source->set_page_from_offset( $offset, $limit );

  my $entries = $source->page;
  my @data    = ();

  foreach my $pub (@$entries) {
    push @data, $pub->as_hash;
  }

  my @fields=();

  foreach my $key (keys %{$entries->[0]}){
    push @fields, {name=>$key};
  }

  my %metaData=(totalProperty => 'total_entries',
                root => 'data',
                id => 'id',
                fields => [@fields]
               );

  $c->stash->{total_entries} = $source->total_entries;
  $c->stash->{data}          = [@data];
  $c->stash->{metaData} = {%metaData};


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

sub index :Path :Args(0) {
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
