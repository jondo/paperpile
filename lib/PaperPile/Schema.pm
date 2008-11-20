package PaperPile::Schema;

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_classes;


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-11-18 21:04:40
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/R3jjPVsPV/vjg4IXz4How

use PaperPile::Library;
use PaperPile::Library::Publication;
use Data::Dumper;

# sub import{
#   (my $self, my $lib) = @_;

#   my $data={};

#   my $publicationTable = $self->resultset('Publication');
#   my $authorPublicationTable = $self->resultset('AuthorPublication');
#   my $authorTable = $self->resultset('Author');
#   my $journalTable = $self->resultset('Journal');

#   foreach my $pub (@{$lib->entries}){
#     foreach my $column ($publicationTable->result_source->columns){
#       next if $column eq 'id';
#       if ($pub->$column){
#         $data->{$column}=$pub->$column;
#       }
#     }

#     my $insertedPubID=$publicationTable->create($data)->id;

#     foreach my $author (@{$pub->authors}){
#       $authorTable->find_or_create($author->as_hash);
#       $authorPublicationTable->create({author_id=>$author->id, publication_id=>$insertedPubID});
#     }

#     $journalTable->find_or_create({id => $pub->journal->id,
#                                    name => $pub->journal->name});

#     #print Dumper($data);
#   }
# }

# sub get_entry{

#   (my $self, my $id) = @_;

#   my $publicationTable = $self->resultset('Publication');

#   my $pub=PaperPile::Library::Publication->new();

#   my $result=$publicationTable->find($id);

#   foreach my $column ($publicationTable->result_source->columns){

#     if (defined $result->$column){
#       $pub->$column($result->$column);
#     }

#   }

#   return $pub;

# }








# You can replace this text with custom content, and it will be preserved on regeneration
1;
