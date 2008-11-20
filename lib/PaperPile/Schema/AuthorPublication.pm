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


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-11-18 21:04:40
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4nQX6qV4li8RM/s32k2jMA

__PACKAGE__->belongs_to(author => 'PaperPile::Schema::Author', 'author_id');
__PACKAGE__->belongs_to(publication => 'PaperPile::Schema::Publication', 'publication_id');


1;
