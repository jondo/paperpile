package PaperPile::Controller::Ajax::Misc;

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


sub reset_db : Local {

  my ( $self, $c ) = @_;

  $c->model('DB')->reset_db;
  $c->stash->{success} = 'true';
  $c->forward('PaperPile::View::JSON');

}

sub import_journals : Local {
  my ( $self, $c ) = @_;

  $c->model('DB')
    ->import_journal_file("/home/wash/play/PaperPile/data/jabref.txt");
  $c->stash->{success} = 'true';
  $c->forward('PaperPile::View::JSON');

}

sub reset_session : Local {

  my ( $self, $c ) = @_;

  foreach my $key ( keys %{ $c->session } ) {
    delete( $c->session->{$key} ) if $key =~ /^(source|viewer|tree)/;
  }

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

=head1 AUTHOR

Stefan Washietl,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
