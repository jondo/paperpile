package PaperPile::Controller::Test;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use PaperPile::Library::Source::File;
use Data::Dumper;

=head1 NAME

PaperPile::Controller::Test - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index 

=cut

sub index : Path : Args(0) {
  my ( $self, $c ) = @_;
  $c->stash->{template} = 'test/main.mas';
  $c->forward('PaperPile::View::Mason');

}

sub grid : Local {
  my ( $self, $c ) = @_;

  $c->stash->{template} = 'test/grid.mas';
  $c->forward('PaperPile::View::Mason');
}

sub list : Local {
  my ( $self, $c ) = @_;

  my $offset = $c->request->params->{start};
  my $limit  = $c->request->params->{limit};

  my $file = '/home/wash/play/PaperPile/t/data/test1.ris';

  my $source;

  if ( not defined $c->session->{source} ) {
    $source = PaperPile::Library::Source::File->new( file => $file );
    $source->connect;
    $c->session->{source} = $source;
  }
  else {
    $source = $c->session->{source};
  }

  $source->entries_per_page($limit);
  $source->set_page_from_offset( $offset, $limit );

  my $entries = $source->page;
  my @data    = ();

  foreach my $pub (@$entries) {
    push @data, $pub->as_hash;
  }

  $c->stash->{data}          = [@data];
  $c->stash->{total_entries} = $source->total_entries;

  my @fields=();

  foreach my $key (keys %{$entries->[0]}){
    push @fields, {name=>$key};
  }

  my %metaData=(totalProperty => 'total_entries',
                root => 'data',
                id => 'id',
                fields => [@fields]
               );

  $c->stash->{metaData} = {%metaData};


  $c->forward('PaperPile::View::JSON');

}

=head1 AUTHOR

Stefan Washietl,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
