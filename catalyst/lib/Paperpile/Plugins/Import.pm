package Paperpile::Plugins::Import;

use Moose;
use Moose::Util::TypeConstraints;
use Data::Dumper;
use Data::Page;
use POSIX qw(ceil floor);
use Text::Levenshtein qw(distance);

use Paperpile::Exceptions;

# Name of the plugin
has 'plugin_name' => ( is => 'rw', isa => 'Str');

# Number of all entries for the query/file
has 'total_entries' => ( is => 'rw', isa => 'Int' );

# Maximum number of entries per page
has 'limit' => ( is => 'rw', isa => 'Int', default => 10 );

# Internal hash to quickly access the entries via their sha1 key across pages
has '_hash' => ( is => 'rw', isa => 'HashRef', default => sub { return {} } );

# Stores pages to avoid re-loading in some situations. A page is
# stored by the first and last index, e.g. _page_cache->{0}->{10}
has '_page_cache' => ( is => 'rw', isa => 'HashRef', default => sub { return {} } );

# Function: connect

# Sets up connection to the source and sets and returns total_entries.
# It is *mandatory* to override this function.

sub connect {
  my $self = shift;
  return undef;
}

# Function: page

# Returns the entries for a page given by $offset and $limit. Return
# format is an ArrayRef with objects of type
# Paperpile::Library::Publication.

# It is *mandatory* to override this function.

sub page {
  ( my $self, my $offset, my $limit ) = @_;
  return [];
}


# Function: all

# Returns all entries. Override this function to limit maximum number
# of returned elements

sub all {

  ( my $self ) = @_;

  return $self->page(0,999999);

}



# Function: complete_details

# For efficiency reasons and to avoid harassing sites with too many
# requests, "page" may return incomplete entries form a quick
# preliminary scrape that can be filled in afterwards by this
# function. The Publication object has a dedicated helper field
# '_details_link' which holds some information on how to get the full
# information (e.g. via a link to a BibTex file as for GoogleScholar).

# Overriding this function is *optional*.

sub complete_details {

  ( my $self, my $pub ) = @_;

  return $pub;

}

# Function find_sha1

# Returns an entry by the sha1 index. To ensure that this function
# works the entries have to be stored by the plugin to the field _hash
# via the function _save_page_to_hash

# This function should *not* be overriden.

sub find_sha1 {

  ( my $self, my $sha1 ) = @_;

  return $self->_hash->{$sha1};

}

sub cleanup {


}


# Function _save_page_to_hash

# Saves Publication objects given in the ArrayRef $data to _hash via
# their sha1. Should be called in any implementation of the function
# "page".

sub _save_page_to_hash {

  ( my $self, my $data ) = @_;

  foreach my $entry (@$data) {
    $self->_hash->{ $entry->sha1 } = $entry;
  }
}

# Merges two publication objects
# Helper function for "match"

sub _merge_pub {
  my ($self, $old, $new) = @_;
  foreach my $key (keys %{$old->as_hash}){
    $old->$key($new->$key) if ($new->$key);
  }
  return $old;
}

# Compares two titles
# Helper function for "match"

sub _match_title {

  my ($self, $title1, $title2) = @_;

  my $cutoff=5;

  for my $t ($title1, $title2){
    $t=~s/\s+//g;
    $t=~s/[.:!?]//g;
    $t=uc($t);
  }

  my $distance=distance($title1,$title2);

  return $distance < $cutoff;

}




1;
