package PaperPile::Schema::Author;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("author");
__PACKAGE__->add_columns(
  "id",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "last_name",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "initials",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "first_name",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "suffix",
  { data_type => "TEXT", is_nullable => 0, size => undef },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-12-28 16:38:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wWRGzzyHfa5bYn1emQtksg


__PACKAGE__->has_many(author_publication => 'PaperPile::Schema::AuthorPublication', 'publication_id');
__PACKAGE__->many_to_many(publication => 'author_publication', 'publication');


# You can replace this text with custom content, and it will be preserved on regeneration
1;
