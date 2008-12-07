package PaperPile::Schema::Publication;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("publication");
__PACKAGE__->add_columns(
  "id",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "pubtype",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "title",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "title2",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "title3",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "authors_flat",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "editors_flat",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "authors_series",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "journal_short",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "volume",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "issue",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "pages",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "publisher",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "city",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "address",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "date",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "year",
  { data_type => "INTEGER", is_nullable => 0, size => undef },
  "month",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "day",
  { data_type => "INTEGER", is_nullable => 0, size => undef },
  "issn",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "pmid",
  { data_type => "INTEGER", is_nullable => 0, size => undef },
  "doi",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "url",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "abstract",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "notes",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "tags_flat",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "pdf",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "fulltext",
  { data_type => "TEXT", is_nullable => 0, size => undef },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-11-21 21:55:55
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lO1t1Wc/hCucd0YEeZdDVQ

__PACKAGE__->has_many(author_publication => 'PaperPile::Schema::AuthorPublication', 'publication_id');
__PACKAGE__->many_to_many(author => 'author_publication', 'author');


1;