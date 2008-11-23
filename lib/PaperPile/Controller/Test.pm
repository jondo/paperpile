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

  $c->response->body('Matched PaperPile::Controller::Test in Test.');
}

sub grid : Local {
  my ( $self, $c ) = @_;

  $c->stash->{template} = 'test/grid.mas';
  $c->forward('PaperPile::View::Mason');
}

sub list : Local {
  my ( $self, $c ) = @_;

  my $offset = $c->request->params->{start};
  my $limit = $c->request->params->{limit};

  my $file='/home/wash/play/PaperPile/t/data/test1.ris';

  my $source=PaperPile::Library::Source::File->new(file=>$file);
  $source->connect;
  my $counter=0;

  $source->entries_per_page($limit);
  $source->set_page_from_offset($offset,$limit);

  my $entries=$source->page;
  my @data=();
  foreach my $pub (@$entries){
    push @data, {pubid=>$pub->id, authors => $pub->authors_flat, journal => $pub->journal_short};
    $counter++;
  }

  $c->log->debug("size".scalar(@$entries), "  ", $source->entries_per_page);

  $c->log->debug("$offset $limit");

  $c->stash->{data} = [@data];
  $c->stash->{total_entries}=$source->total_entries;
  $c->forward('PaperPile::View::JSON');

}

=head1 AUTHOR

Stefan Washietl,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
