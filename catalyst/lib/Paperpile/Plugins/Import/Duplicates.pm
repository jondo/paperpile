# Copyright 2009, 2010 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public License for more details.  You should have
# received a copy of the GNU Affero General Public License along with
# Paperpile.  If not, see http://www.gnu.org/licenses.


package Paperpile::Plugins::Import::Duplicates;

use Carp;
use Data::Page;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;
use Paperpile::Utils;
use Paperpile::Model::Library;
use Paperpile::Library::Publication;
use Paperpile::Library::Author;

extends 'Paperpile::Plugins::Import';

has '_db_file'       => ( is => 'rw' );
has 'file'           => ( is => 'rw' );
has '_data'          => ( is => 'rw', isa => 'ArrayRef' );
has 'clear_duplicate_cache' => ( is => 'rw' );

has 'index' => ( is => 'rw', isa => 'HashRef');

sub BUILD {
  my $self = shift;

  $self->index( { words => {}, lengths => {}, pubs => {} } );

  $self->plugin_name('Duplicates');
}

sub get_model {
  my $self = shift;
  my $model = Paperpile::Model::Library->new( { file => _db_file } );
  return $model;
}


sub connect {
  my $self = shift;

  $self->_db_file( $self->file );
  $self->_data( [] );

  my $dupl_keys={} ;
  my $dupl_partners = {};

  $self->build_index;

  my $N = @{ $self->index->{pubs} };

  foreach my $i ( 0 .. $N - 1 ) {

    my $guid_i = $self->index->{pubs}->[$i]->{guid};

    next if ( exists $dupl_keys->{$guid_i} );

    my @words_i  = keys %{ $self->index->{words}->{$guid_i} };
    my $title_i  = $self->index->{pubs}->[$i]->{title};
    my $length_i = $self->index->{lengths}->{$guid_i};

    # 1/3 of words may mismatch
    my $max_mismatch = int( $self->index->{lengths}->{$guid_i} * 0.33 );

    foreach my $j ( 0 .. $N - 1 ) {

      # Only consider half of the matrix and ignore diagonal
      next if $i >= $j;

      my $guid_j = $self->index->{pubs}->[$j]->{guid};

      next if ( exists $dupl_keys->{$guid_j} );

      if ( $self->_compare_pubs( $j, $length_i, \@words_i, $title_i, $max_mismatch ) ) {
        my $i_pub = $self->index->{pubs}->[$i];
        my $j_pub = $self->index->{pubs}->[$j];
        $dupl_partners->{ $i_pub->{guid} } = $j_pub;
        $dupl_partners->{ $j_pub->{guid} } = $i_pub;

        # remember the i.th publication
        if ( !defined $dupl_keys->{ $i_pub->{guid} } ) {
          push @{ $self->_data }, Paperpile::Library::Publication->new($i_pub);
          $dupl_keys->{ $i_pub->{guid} } = $i;
        }

        # remember the j.th publication
        if ( !defined $dupl_keys->{ $j_pub->{guid} } ) {
          push @{ $self->_data }, Paperpile::Library::Publication->new($j_pub);
          $dupl_keys->{ $j_pub->{guid} } = $i;
        }
      }
    }
  }

  $self->total_entries( scalar @{ $self->_data } );

  # switch background color (highlight)
  my $c0           = 'pp-grid-highlight1';
  my $c1           = 'pp-grid-highlight2';
  my $cur_color    = $c0;
  my $last_cluster = -1;

  # define the color-scheme
  # currently implemented: alternate between 2 colors
  my %cluster2color;
  foreach my $cluster ( sort { $a <=> $b } values %{ $dupl_keys } ) {
    if ( $cluster != $last_cluster ) {
      if ( $cur_color eq $c0 ) {
        $cur_color = $c1;
      } else {
        $cur_color = $c0;
      }
    }
    $cluster2color{$cluster} = $cur_color;
    $last_cluster = $cluster;
  }

  # update the background color
  for ( my $i = 0 ; $i < scalar( @{ $self->_data } ) ; $i++ ) {
    my $pub = $self->_data->[$i];
    if ( defined $dupl_keys->{ $pub->{guid} } ) {
      $pub->{'_highlight'} = $cluster2color{ $dupl_keys->{ $pub->{guid} } };
      $pub->{'_dup_id'}    = $dupl_keys->{ $pub->{guid} };

      # Make sure attachments are handled correctly
      $pub->_db_connection( "dbi:SQLite:" . $self->_db_file );
      $pub->refresh_attachments;
    }
  }

  return $self->total_entries;
}



sub page {
  ( my $self, my $offset, my $limit ) = @_;

  my $dbh = $self->get_model->dbh;

  my @page = ();

  # Check if data still exists and remove items that have been trashed
  my @new_data = ();
  my $sth      = $dbh->prepare("SELECT guid FROM publications WHERE guid=? AND trashed=0;");

  foreach my $pub ( @{ $self->_data } ) {
    $sth->execute( $pub->guid );
    my $exists = 0;
    while ( my $row = $sth->fetchrow_hashref() ) {
      $exists = 1;
    }
    push @new_data, $pub if $exists;
  }

  $self->_data( \@new_data );
  $self->total_entries( scalar @{ $self->_data } );

  for my $i ( 0 .. $limit - 1 ) {
    last if ( $offset + $i == $self->total_entries );
    push @page, $self->_data->[ $offset + $i ];
  }

  $self->_save_page_to_hash( \@page );

  return \@page;

}


## Generates data structure that holds all publications, the length of
## the titles and indices for the title words

sub build_index {

  my $self = shift;

  my $model = $self->get_model;

  my @all_pubs = @{ $model->all_as_hash };

  @all_pubs = grep { !defined $_->{trashed} } @all_pubs;

  my %lengths = ();
  my %index   = ();

  foreach my $i ( 0 .. $#all_pubs ) {

    my $guid = $all_pubs[$i]->{guid};

    $index{$guid} = {};
    my @words = split( /\s+/, lc( $all_pubs[$i]->{title} ) );
    $lengths{$guid} = scalar @words;
    foreach my $word (@words) {
      $index{$guid}->{$word} = 1;
    }
  }

  # List of all publications as flat hashes
  $self->index->{pubs}    = \@all_pubs;

  # Hash for all pubs indexed by guid that holds hash with title words
  $self->index->{words}   = \%index;

  # Hash for all pubs indexed by guid that holds length of title
  $self->index->{lengths} = \%lengths;

}

# Compare two publications. The first is given by the index number in
# $self->index->{pubs}, the second is given by length of tiltle, list
# of title words, and the title. The cutoff $max_mismatch specific for
# this comparison must also be passed. This function can be used to
# cluster all pubs or to compare one arbitrary pub to the index.

sub _compare_pubs {

  my ( $self, $j, $length_i, $words_i, $title_i, $max_mismatch ) = @_;

  my $guid_j   = $self->index->{pubs}->[$j]->{guid};
  my $length_j = $self->index->{lengths}->{$guid_j};

  # Don't compare if lengths are too different
  return (0) if abs( $length_j - $length_i ) > 5;

  my $matches    = 0;
  my $mismatches = 0;

  # Match each word, stop if too many words are missing
  foreach my $word (@$words_i) {
    if ( $self->index->{words}->{$guid_j}->{$word} ) {
      $matches++;
    } else {
      $mismatches++;
    }
    last if $mismatches > $max_mismatch;
  }

  # Add wordcount difference to mismatch count
  $mismatches += abs( $length_i - $length_j );

  if ( $mismatches <= $max_mismatch ) {

    #print STDERR "=> $title_i vs. ", $self->index->{pubs}->[$j]->{title}, "<= ($mismatches)\n";

    #if ( abs( $length_i - $length_j ) <= $max_mismatch ) {
    # Exact equality
    if ( $mismatches == 0 ) {
      return 1;

      # Try distance comparison
    } elsif ( $self->_match_title( lc($title_i), lc( $self->index->{pubs}->[$j]->{title} ) ) ) {
      return 1;
    }
    #}
  }

  return 0;
}

# Replace the cluster with $dup_id with a new merged publication
# object $merged_pub. The highlight is resetted.

sub replace_merged_items {

  my ($self, $dup_id, $merged_pub) = @_;

  my @new_data = ();

  my $is_first=1;

  foreach my $pub (@{$self->_data}){

    if ($is_first and ($pub->_dup_id eq $dup_id)){
      $merged_pub->_dup_id(undef);
      push @new_data, $merged_pub;
      $self->_hash->{$merged_pub->guid} = $merged_pub;
      $is_first=0;
    }

    if  ($pub->_dup_id eq $dup_id){
      delete($self->_hash->{$pub->guid});
    } else {
      push @new_data, $pub;
    }
  }

  $self->_data(\@new_data);

  $self->total_entries( scalar @{ $self->_data } );

}


1;
