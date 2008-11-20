package PaperPile::Controller::Test;

use strict;
use warnings;
use parent 'Catalyst::Controller';

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

  my $data = [
    { FirstName => 'Stefan', LastName => 'Washietl' },
    { FirstName => 'Hugo',   LastName => 'Habicht' },
  ];

  $c->stash->{results} = $data;
  $c->stash->{total}=2;
  $c->forward('PaperPile::View::JSON');

}

=head1 AUTHOR

Stefan Washietl,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
