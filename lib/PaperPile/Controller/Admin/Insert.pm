package PaperPile::Controller::Insert;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use PaperPile::Library;
use Data::Dumper;

=head1 NAME

PaperPile::Controller::Insert - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index 

=cut

sub index :Path :Args(0) {
  my ( $self, $c) = @_;

  my $fileName = $c->request->params->{fileName} || 'N/A';

  if ($c->{request}->{body_parameters}->{Submit}){
    $c->stash->{message}="You have input: <b>$fileName</b> ";

    my $lib=PaperPile::Library->new();
    $lib->import_ris("/home/wash/test.ris");

    $c->model('DB')->import($lib);

  } else {
    $c->stash->{message}="Input your data";
  }

  $c->stash->{template} = 'insert.mas';


}


=head1 AUTHOR

Stefan Washietl,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
