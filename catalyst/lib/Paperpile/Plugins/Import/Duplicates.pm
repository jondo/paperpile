# Copyright 2009, 2010 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.  You should have received a
# copy of the GNU General Public License along with Paperpile.  If
# not, see http://www.gnu.org/licenses.

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
has '_dupl_keys'     => ( is => 'rw' );                      # keeps sha1 keys of duplicates
has '_dupl_partners' => ( is => 'rw' );                      # keeps sha1 keys of duplicates
has '_searchspace'   => ( is => 'rw' )
  ;    # publications that we will loop throu while searching duplicates

has 'clear_duplicate_cache' => ( is => 'rw' );

sub BUILD {
  my $self = shift;
  $self->plugin_name('Duplicates');
}

sub get_model {
  my $self  = shift;
  my $model = Paperpile::Model::Library->new();
  $model->set_dsn( "dbi:SQLite:" . $self->_db_file );
  return $model;
}

sub connect {
  my $self = shift;

  $self->_db_file( $self->file );
  $self->_data( [] );
  $self->_dupl_keys(     {} );
  $self->_dupl_partners( {} );

  my $model = $self->get_model;

  # get all publications
  my @all_pubs = @{ $model->all_as_hash };

  # ignore trashed publications.
  @all_pubs = grep { !defined $_->{trashed} } @all_pubs;

  $self->_searchspace( \@all_pubs );
  print STDERR "count: ", $#{ $self->_searchspace }, "\n";

  # print STDERR Dumper $self->_searchspace->[0];

  # number of words for each title
  my @lengths = ();

  # array of hashes to index words of each title
  my @index = ();

  # number of general candidate duplications
  # e.g. title i might be substr of title j.
  my $countDuplCandidates = 0;

  # number of directly identified duplications
  my $countDuplDirect = 0;

  # number of duplications that additionally needed matching
  my $countDuplMatching = 0;

  # number of real duplications
  my $countDuplOverall = 0;

  # get and count words of titles
  foreach my $i ( 0 .. $#{ $self->_searchspace } ) {
    $index[$i] = {};
    my @words = split( /\s+/, lc( $self->_searchspace->[$i]->{title} ) );
    $lengths[$i] = scalar @words;
    foreach my $word (@words) {
      $index[$i]->{$word} = 1;
    }
  }

  foreach my $i ( 0 .. $#{ $self->_searchspace } ) {

    next if ( exists $self->_dupl_keys->{ $self->_searchspace->[$i]->{sha1} } );

    my @words = keys %{ $index[$i] };

    # 1/3 of words may mismatch; play with this cutoff
    my $max_mismatch = int( $lengths[$i] * 0.33 );

    foreach my $j ( 0 .. $#{ $self->_searchspace } ) {

      # don't check papers with themselves
      # and don't check pairs twice (i vs j and j vs i, i vs j is enough)
      next if $i >= $j;

      next if ( exists $self->_dupl_keys->{ $self->_searchspace->[$j]->{sha1} } );

      # Don't compare if lengths are too different
      # play with this cutoff
      next if abs( $lengths[$i] - $lengths[$j] ) > 5;

      my $matches    = 0;
      my $mismatches = 0;

      # Match each word, stop if too many words are missing
      foreach my $word (@words) {
        if ( $index[$j]->{$word} ) {
          $matches++;
        } else {
          $mismatches++;
        }
        last if $mismatches > $max_mismatch;
      }

      # Matches for further analysis; right now matches are printed if
      # all words could be matched;
      # Todo: choose criterion to select those for edit distance calculation
      #       if exact equality (x eq y) then we don't need distance calculation
      #       This should limit distance calculations to a reasonable number
      my $wordcount_i = scalar @words;
      my $wordcount_j = keys %{ $index[$j] };

      # extend mismatches (to get all differences	if wordcount differs)
      $mismatches += abs( $wordcount_i - $wordcount_j );

      if ( $mismatches <= $max_mismatch ) {
        $countDuplCandidates++;
        print STDERR $i, "\t", $self->_searchspace->[$i]->{title}, "\t(",
          $self->_searchspace->[$i]->{sha1}, ")\n";
        print STDERR $j, "\t", $self->_searchspace->[$j]->{title}, "\t(",
          $self->_searchspace->[$j]->{sha1}, ")\n";
        print STDERR
          "(words: $wordcount_i vs $wordcount_j, matches=$matches, mismatches=$mismatches, max_mismatches=$max_mismatch)\n";

        if ( abs( $wordcount_i - $wordcount_j ) <= $max_mismatch ) {
          print STDERR "BE CAREFULL...";

          if ( $mismatches == 0 ) {

            # exact equality (i eq j), we don't need distance calculation
            print STDERR "GOT YA! (direct)\n";
            $countDuplDirect++;
            $self->_store( $i, $j );
          } else {    # perform distance calculation
            if (
              $self->_match_title(
                lc( $self->_searchspace->[$i]->{title} ),
                lc( $self->_searchspace->[$j]->{title} )
              )
              ) {
              print STDERR "GOT YA! (matching)\n";
              $countDuplMatching++;
              $self->_store( $i, $j );
            } else {
              print STDERR "\n";
            }
          }
        }

        print STDERR "\n";
      }
    }
  }

  $countDuplOverall = $countDuplDirect + $countDuplMatching;

  print STDERR "max candidate duplicates     : ", $countDuplCandidates, "\n";
  print STDERR "  ->      directly identified: ", $countDuplDirect,     "\n";
  print STDERR "  -> via distance calculation: ", $countDuplMatching,   "\n";
  print STDERR "overall identified duplicates: ", $countDuplOverall,    "\n";
  print STDERR "neglected candidates         : ", ( $countDuplCandidates - $countDuplOverall ),
    "\n\n";

  print STDERR Dumper $self->_dupl_keys;

  $self->total_entries( scalar @{ $self->_data } );

  #####################################
  # switch background color (highlight)
  my $c0           = 'pp-grid-highlight1';
  my $c1           = 'pp-grid-highlight2';
  my $cur_color    = $c0;
  my $last_cluster = 0;

  # define the color-scheme
  # currently implemented: alternate between 2 colors
  my %cluster2color;
  foreach my $cluster ( sort { $a <=> $b } values %{ $self->_dupl_keys } ) {
    if ( $cluster != $last_cluster ) {
      if ( $cur_color eq $c0 ) {
        $cur_color = $c1;
      } else {
        $cur_color = $c0;
      }
    }

    print STDERR $cluster, " ", $cur_color, "\n";
    $cluster2color{$cluster} = $cur_color;
    $last_cluster = $cluster;
  }

  my $cluster_count = keys %cluster2color;
  print STDERR "Nr of clusters: ", $cluster_count, "\n";

  # update the background color
  for ( my $i = 0 ; $i < scalar( @{ $self->_data } ) ; $i++ ) {
    if ( defined $self->_dupl_keys->{ $self->_data->[$i]->{'sha1'} } ) {
      $self->_data->[$i]->{'_highlight'} =
        $cluster2color{ $self->_dupl_keys->{ $self->_data->[$i]->{'sha1'} } };
    }
    print STDERR $self->_data->[$i]->{'_highlight'}, "\n";
  }

  return $self->total_entries;
}

sub page {
  ( my $self, my $offset, my $limit ) = @_;

  my $model = $self->get_model;

  if ( $self->clear_duplicate_cache ) {
    $self->connect;
  }

  my @page = ();

  for my $i ( 0 .. $limit - 1 ) {
    last if ( $offset + $i == $self->total_entries );
    push @page, $self->_data->[ $offset + $i ];
  }

  $self->_save_page_to_hash( \@page );

  return \@page;

}

# take care of pairwise duplications
# remind the sha1 keys of identified duplicates
# and label the clusters
sub _store {
  my ( $self, $i, $j ) = @_;

  my $i_pub = $self->_searchspace->[$i];
  my $j_pub = $self->_searchspace->[$j];
  $self->_dupl_partners->{ $i_pub->{sha1} } = $j_pub;
  $self->_dupl_partners->{ $j_pub->{sha1} } = $i_pub;

  # remember the i.th publication
  if ( !defined $self->_dupl_keys->{ $i_pub->{sha1} } ) {

    #$self->_searchspace->[$i]->{_highlight} = 'pp-grid-highlight3';
    push @{ $self->_data }, Paperpile::Library::Publication->new($i_pub);
    $self->_dupl_keys->{ $i_pub->{sha1} } = $i;
  }

  # remember the j.th publication
  if ( !defined $self->_dupl_keys->{ $j_pub->{sha1} } ) {

    #$self->_searchspace->[$j]->{_highlight} = 'pp-grid-highlight3';
    push @{ $self->_data }, Paperpile::Library::Publication->new($j_pub);
    $self->_dupl_keys->{ $j_pub->{sha1} } = $i;
  }
}

1;
