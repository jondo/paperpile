package PaperPile::Schema::Journal;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("journal");
__PACKAGE__->add_columns(
  "id",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "name",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "short",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "issn",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "url",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "icon",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "is_user_journal",
  { data_type => "INTEGER", is_nullable => 0, size => undef },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-12-14 10:50:55
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZB54RnS/q57z1E+CsxvqIg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
