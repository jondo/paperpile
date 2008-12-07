package PaperPile::Controller::List;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

PaperPile::Controller::List - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index 

=cut

sub index :Path :Args(0) {
  my ( $self, $c ) = @_;

  my $list = [$c->model('DB::Publication')->all()];

  $c->stash->{list}=[];

  foreach my $entry (@$list){
    push @{$c->stash->{list}},$c->model('DB')->get_entry($entry->id);
  }


  $c->stash->{template} = 'list.mas';
}


=head1 AUTHOR

Stefan Washietl,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;