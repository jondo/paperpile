package PaperPile::Model::DB;

use strict;
use base 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->config(
  schema_class => 'PaperPile::Schema',
  connect_info => [ 'dbi:SQLite:/home/wash/play/PaperPile/db/default.db', ],
);

sub import_lib {

  ( my $self, my $lib ) = @_;

  my $data = {};

  my $publication_table        = $self->resultset('Publication');
  my $author_publication_table = $self->resultset('AuthorPublication');
  my $author_table             = $self->resultset('Author');
  my $journal_table            = $self->resultset('Journal');

  foreach my $pub ( @{ $lib->entries } ) {
    foreach my $column ( $publication_table->result_source->columns ) {
      if ( $pub->$column ) {
        $data->{$column} = $pub->$column;
      }
    }

    $publication_table->find_or_create($data);

    foreach my $author ( @{ $pub->authors } ) {
      $author_table->find_or_create( $author->as_hash );
      $author_publication_table->create(
        { author_id => $author->id, publication_id => $pub->id } );
    }

    $journal_table->find_or_create(
      {
        id   => $pub->journal->id,
        name => $pub->journal->name
      }
    );
  }
}

=head1 NAME

PaperPile::Model::DB - Catalyst DBIC Schema Model
=head1 SYNOPSIS

See L<PaperPile>

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<PaperPile::Schema>

=head1 AUTHOR

Stefan Washietl,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
