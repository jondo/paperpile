package PaperPile::Model::DB;

use strict;
use Data::Dumper;
use DBIx::Class::ResultClass::HashRefInflator;

sub _dumper_hook {
  $_[0] = bless { %{ $_[0] }, result_source => undef, }, ref( $_[0] );
}
$Data::Dumper::Freezer = '_dumper_hook';

use PaperPile::Library;

use base 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->config(
  schema_class => 'PaperPile::Schema',
  connect_info => [ 'dbi:SQLite:/home/wash/play/PaperPile/db/default.db', ],
);

sub import_lib {

  ( my $self, my $lib ) = @_;

  my @importedIds = ();

  foreach my $pub ( @{ $lib->entries } ) {
    push @importedIds, $self->create_pub($pub);
  }

  return [@importedIds];

}

sub create_pub {

  ( my $self, my $pub ) = @_;

  my $data = {};

  my $publication_table        = $self->resultset('Publication');
  my $author_publication_table = $self->resultset('AuthorPublication');
  my $author_table             = $self->resultset('Author');
  my $journal_table            = $self->resultset('Journal');

  foreach my $column ( $publication_table->result_source->columns ) {
    if ( $pub->$column ) {
      $data->{$column} = $pub->$column;
    }
  }

  $data->{journal_id} = $pub->journal->id;

  my $rowid = $publication_table->find_or_create($data)->get_column('rowid');

  foreach my $author ( @{ $pub->authors } ) {
    $author_table->find_or_create( $author->as_hash );
    $author_publication_table->find_or_create(
    { author_id => $author->id, publication_id => $rowid } );
  }


  $journal_table->find_or_create(
    {
     id              => $pub->journal->id,
     name            => $pub->journal->name,
     short           => $pub->journal->short,
     is_user_journal => 1,
    }
  );

  return $rowid;
}

sub update_pub {

  ( my $self, my $pub ) = @_;

  $self->delete_pubs([$pub->rowid]);
  my $rowid=$self->create_pub($pub);

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
    my $pub_row=$publication_table->find( { rowid => $pub_id } );

    my $journal_id=$pub_row->journal_id;

    $pub_row->delete();

    my @query=( { publication_id => $pub_id},
                {join => [qw/author/]});

    # Search for all authors of this publication
    foreach my $author_pub_row ($author_publication_table->search(@query)){

      my $author_id = $author_pub_row->author_id;

      #Delete author_publication connection
      $author_pub_row->delete();

      # Delete author if (s)he has no other publications
      if (not $author_publication_table->search({author_id => $author_id})->first){
        $author_table->find({id=>$author_id})->delete;
      }
    }

    if (not $publication_table->search({journal_id => $journal_id})->first){
      $journal_table->find({id => $journal_id, is_user_journal=>1})->delete();
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
    my @query = (
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
      my $tmp=PaperPile::Library::Author->new();
      foreach my $field (qw/last_name initials suffix first_name/){
        next if not $author->get_column($field);
        $tmp->$field($author->get_column($field));
      }
      push @authors,$tmp;
    }

    $pub->authors([@authors]);

    # Get journal from joined table

    if ($row->journal_id){
      my $journal_row=$journal_table->find($row->journal_id);
      my $journal=PaperPile::Library::Journal->new();
      $journal->id($journal_row->id);
      $journal->short($journal_row->short);
      $journal->name($journal_row->name);
      $pub->journal($journal);
    } else {
      $pub->journal(PaperPile::Library::Journal->new(journal_id=>'undefined'));
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
  my $result=$self->resultset('Publication')->find($sha1, {key=>'publication_sha1'});

  if (defined($result)){
    return 1;
  } else {
    return 0;
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
