package PaperPile::Model::DB;

use strict;
use Data::Dumper;

use PaperPile::Library;

use base 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->config(
  schema_class => 'PaperPile::Schema',
  connect_info => [ 'dbi:SQLite:/home/wash/play/PaperPile/db/default.db', ],
);

sub import_lib {

  ( my $self, my $lib ) = @_;

  my @importedIds=();

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

    push @importedIds, $publication_table->find_or_create($data)->id;

    foreach my $author ( @{ $pub->authors } ) {
      $author_table->find_or_create( $author->as_hash );
      $author_publication_table->create(
        { author_id => $author->id, publication_id => $pub->id } );
    }

    $journal_table->find_or_create(
      {
       id   => $pub->journal->id,
       name => $pub->journal->name,
       short => $pub->journal->short,
       is_user_journal => 1,
      }
    );
  }

  return [@importedIds];

}

sub search {

  ( my $self, my $term ) = @_;

  my $publication_table        = $self->resultset('Publication');
  my $author_publication_table = $self->resultset('AuthorPublication');
  my $author_table             = $self->resultset('Author');
  my $journal_table            = $self->resultset('Journal');

  my @results=();

  foreach my $row ($publication_table->search($term)){

    my $data={};

    foreach my $column ( $publication_table->result_source->columns ) {
      if ( $row->$column ) {
        $data->{$column} = $row->$column;
      }
    }

    my $pub=PaperPile::Library::Publication->new($data);

    push @results, $pub;

  }

  return [@results];

}


sub import_journal_file {

  ( my $self, my $file ) = @_;

  open( TMP, "<$file" );

  my %alreadySeen = ();

  while (<TMP>) {
    next if /^\s*\#/;
    ( my $long, my $short ) = split /=/, $_;
    $short =~ s/;.*$//;
    $short =~ s/[.,-]/ /g;
    $short =~ s/(^\s+|\s+$)//g;
    $long  =~ s/(^\s+|\s+$)//g;
    my $id = $short;
    $id =~ s/\s+/_/g;
    $id =~ s/_\)/\)/g;

    if ( not $alreadySeen{$id} ) {
      $alreadySeen{$id} = 1;
      next;
    }
    $self->resultset('Journal')->find_or_create(
      id              => $id,
      name            => $long,
      short           => $short,
      is_user_journal => 0
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
