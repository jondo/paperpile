package PaperPile::Schema::Fulltext;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("fulltext");
__PACKAGE__->add_columns(
  "title",
  { data_type => "VARCHAR", is_nullable => 0, size => undef },
  "abstract",
  { data_type => "VARCHAR", is_nullable => 0, size => undef },
  "notes",
  { data_type => "VARCHAR", is_nullable => 0, size => undef },
  "authors",
  { data_type => "VARCHAR", is_nullable => 0, size => undef },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-12-28 16:38:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:EPivWfeqjAstur3dLV15Vg


# You can replace this text with custom content, and it will be preserved on regeneration

__PACKAGE__->add_columns(
  "rowid",
  { data_type => "INTEGER", is_nullable => 0});

__PACKAGE__->set_primary_key("rowid");

__PACKAGE__->belongs_to( 'publication', 'PaperPile::Schema::Publication',
                         { 'foreign.rowid' => 'self.rowid' } );



my $source = __PACKAGE__->result_source_instance();
my $new_source = $source->new( $source );
$new_source->source_name( 'fulltext_query' );

$new_source->name( \<<SQL );
(select * from Publication 
join fulltext on publication.rowid=fulltext.rowid 
where fulltext match ?)
SQL

PaperPile::Schema->register_source( 'fulltext_query' => $new_source );



1;
