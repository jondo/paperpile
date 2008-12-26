package PaperPile::Schema::AuthorPublication;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("author_publication");
__PACKAGE__->add_columns(
  "author_id",
  { data_type => "INTEGER", is_nullable => 0, size => undef },
  "publication_id",
  { data_type => "INTEGER", is_nullable => 0, size => undef },
);
__PACKAGE__->set_primary_key("author_id", "publication_id");


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-12-25 20:10:48
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+ZanhfH0n3p2FNDp0alGQA

__PACKAGE__->belongs_to(author => 'PaperPile::Schema::Author', 'author_id');
__PACKAGE__->belongs_to(publication => 'PaperPile::Schema::Publication', 'publication_id');


1;
