package PaperPile::Model::DB;

use strict;
use Data::Dumper;
use DBIx::Class::ResultClass::HashRefInflator;
use MooseX::Timestamp;

use base 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->config(
  schema_class => 'PaperPile::Schema',
  connect_info => [ 'dbi:SQLite:/home/wash/play/PaperPile/db/default.db', ],
);

sub reset_db {

  ( my $self ) = @_;

  my $publication_table        = $self->resultset('Publication');
  my $author_publication_table = $self->resultset('AuthorPublication');
  my $author_table             = $self->resultset('Author');
  my $journal_table            = $self->resultset('Journal');

  $publication_table->delete();
  $author_publication_table->delete();
  $author_table->delete();

}

sub create_pub {

  ( my $self, my $pub ) = @_;

  my $publication_table        = $self->resultset('Publication');
  my $author_publication_table = $self->resultset('AuthorPublication');
  my $author_table             = $self->resultset('Author');
  my $journal_table            = $self->resultset('Journal');

  my $data = {};

  foreach my $column ( $publication_table->result_source->columns ) {
    if ( $pub->$column ) {
      $data->{$column} = $pub->$column;
    }
  }

  $data->{journal_id} = $pub->journal->id;
  $data->{created}    = timestamp;

  my $rowid = $publication_table->find_or_create($data)->get_column('rowid');

  foreach my $author ( @{ $pub->authors } ) {
    $author_table->find_or_create( $author->as_hash );
    $author_publication_table->find_or_create(
      { author_id => $author->id, publication_id => $rowid } );
  }

  $journal_table->find_or_create(
    {
      id              => $pub->journal->id,
      short           => $pub->journal->short,
      is_user_journal => 1,                     # if it does not exist yet it is
                                                # flagged as user journal
    }
  );

  $self->index_pub($rowid);

  return $rowid;
}

sub update_pub {

  ( my $self, my $pub ) = @_;

  $self->delete_pubs( [ $pub->rowid ] );
  my $rowid = $self->create_pub($pub);
  return $rowid;

}

sub delete_pubs {

  ( my $self, my $ids ) = @_;

  my $publication_table        = $self->resultset('Publication');
  my $author_publication_table = $self->resultset('AuthorPublication');
  my $author_table             = $self->resultset('Author');
  my $journal_table            = $self->resultset('Journal');

  foreach my $pub_id (@$ids) {

    # Delete publication entry
    my $pub_row = $publication_table->find( { rowid => $pub_id } );

    my $journal_id = $pub_row->journal_id;

    $pub_row->delete();

    my @query = ( { publication_id => $pub_id }, { join => [qw/author/] } );

    # Search for all authors of this publication
    foreach my $author_pub_row ( $author_publication_table->search(@query) ) {

      my $author_id = $author_pub_row->author_id;

      #Delete author_publication connection
      $author_pub_row->delete();

      # Delete author if (s)he has no other publications
      if (
        not $author_publication_table->search( { author_id => $author_id } )
        ->first )
      {
        $author_table->find( { id => $author_id } )->delete;
      }
    }

    if (
      not $publication_table->search( { journal_id => $journal_id } )->first )
    {
      $journal_table->find( { id => $journal_id, is_user_journal => 1 } )
        ->delete();
    }
  }
}

sub get_fulltext_rs {

  ( my $self, my $term, my $maxpage ) = @_;

  my $rs;

  # if nothing is searched for return whole library
  if ( not $term ) {
    $rs =
      $self->resultset('Publication')->search( undef, { rows => $maxpage } );
  }
  else {

    $rs = $self->resultset('fulltext_query')->search(
      {},
      {
        bind => [$term],
        rows => $maxpage,
        include_columns =>
          [ $self->resultset('Publication')->result_source->columns ]
      }
    );
  }

  return $rs;

}

sub fulltext_search {

  ( my $self, my $rs, my $page ) = @_;

  my @output = ();

  foreach my $row ( $rs->page($page)->all ) {

    my $data = {};
    foreach
      my $column ( $self->resultset('Publication')->result_source->columns )
    {
      if ( $row->get_column($column) ) {
        my $x = $row->get_column($column);

    # Some unicode magic going one here. In principle perl uses utf-8 and
    # sqlite used utf8. Howver, strings returned by this DBIx::Class function
    # are not perl utf-8 strings. We use here utf8::decode which seems to work,
    # which does not seem that everything is right unicode-wise, so take care...
        utf8::decode($x);
        $data->{$column} = $x;
      }
    }
    push @output, PaperPile::Library::Publication->new($data);
  }

  print STDERR Dumper(@output);

  return [@output];
}

sub complete_related {

  ( my $self, my $pub ) = @_;

  my $publication_table        = $self->resultset('Publication');
  my $author_publication_table = $self->resultset('AuthorPublication');
  my $author_table             = $self->resultset('Author');
  my $journal_table            = $self->resultset('Journal');

  if ( not defined $pub->authors ) {

    my @authors = ();
    my @query   = (
      { publication_id => $pub->rowid },
      {
        join      => [qw/author/],
        '+select' => [
          'author.last_name', 'author.initials',
          'author.suffix',    'author.first_name'
        ],
        '+as' => [ 'last_name', 'initials', 'suffix', 'first_name' ]
      }
    );

    foreach my $author ( $author_publication_table->search(@query) ) {
      my $tmp = PaperPile::Library::Author->new();
      foreach my $field (qw/last_name initials suffix first_name/) {
        next if not $author->get_column($field);
        $tmp->$field( $author->get_column($field) );
      }
      push @authors, $tmp;
    }

    $pub->authors( [@authors] );

  }

  if ( not defined $pub->journal ) {

    if ( $pub->journal_flat ) {
      my $journal_row = $journal_table->find( $pub->journal_flat );
      my $journal     = PaperPile::Library::Journal->new();
      $journal->id( $journal_row->id );
      $journal->short( $journal_row->short );
      $journal->name( $journal_row->name );
      $pub->journal($journal);
    }
    else {
      $pub->journal(
        PaperPile::Library::Journal->new( journal_id => 'undefined' ) );
    }
  }
}

sub search {

  ( my $self, my $term ) = @_;

  my $publication_table        = $self->resultset('Publication');
  my $author_publication_table = $self->resultset('AuthorPublication');
  my $author_table             = $self->resultset('Author');
  my $journal_table            = $self->resultset('Journal');

  my @results = ();

  # Find all database entries
  foreach my $row ( $publication_table->search($term) ) {

    # Reconstruct all fields from main table
    my $data = {};
    foreach my $column ( $publication_table->result_source->columns ) {
      if ( $row->$column ) {
        $data->{$column} = $row->$column;
      }
    }
    my $pub = PaperPile::Library::Publication->new($data);

    # Get authors from joined tables
    my @authors = ();
    my @query   = (
      { publication_id => $row->id },
      {
        join      => [qw/author/],
        '+select' => [
          'author.last_name', 'author.initials',
          'author.suffix',    'author.first_name'
        ],
        '+as' => [ 'last_name', 'initials', 'suffix', 'first_name' ]
      }
    );

    foreach my $author ( $author_publication_table->search(@query) ) {
      my $tmp = PaperPile::Library::Author->new();
      foreach my $field (qw/last_name initials suffix first_name/) {
        next if not $author->get_column($field);
        $tmp->$field( $author->get_column($field) );
      }
      push @authors, $tmp;
    }

    $pub->authors( [@authors] );

    # Get journal from joined table

    if ( $row->journal_id ) {
      my $journal_row = $journal_table->find( $row->journal_id );
      my $journal     = PaperPile::Library::Journal->new();
      $journal->id( $journal_row->id );
      $journal->short( $journal_row->short );
      $journal->name( $journal_row->name );
      $pub->journal($journal);
    }
    else {
      $pub->journal(
        PaperPile::Library::Journal->new( journal_id => 'undefined' ) );
    }

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

sub empty_all {
  ( my $self, my $file ) = @_;

  $self->resultset('Journal')->delete();
  $self->resultset('Author')->delete();
  $self->resultset('AuthorPublication')->delete();
  $self->resultset('Publication')->delete();

}

sub is_in_DB {
  ( my $self, my $sha1 ) = @_;
  my $result =
    $self->resultset('Publication')->find( $sha1, { key => 'sha1_unique' } );

  if ( defined($result) ) {
    return 1;
  }
  else {
    return 0;
  }

}

sub index_pub {

  ( my $self, my $rowid ) = @_;

  my $result = $self->resultset('Publication')->find($rowid);
  $self->resultset('Fulltext')->update_or_create(
    {
      rowid    => $rowid,
      title    => $result->title,
      abstract => $result->abstract,
      notes    => $result->notes,
      authors  => $result->authors_flat
    }
  );
}

sub index_all {

  ( my $self ) = @_;

  my $publication_table = $self->resultset('Publication');

  foreach my $row ( $publication_table->search(undef) ) {
    $self->index_pub( $row->rowid );
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
