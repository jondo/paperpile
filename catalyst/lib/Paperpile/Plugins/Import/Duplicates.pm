# Copyright 2009-2011 Paperpile
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
use File::Temp qw(tempfile);

extends 'Paperpile::Plugins::Import';

has '_db_file'              => ( is => 'rw' );
has 'file'                  => ( is => 'rw' );
has '_data'                 => ( is => 'rw', isa => 'ArrayRef' );
has 'clear_duplicate_cache' => ( is => 'rw' );
has 'shash'                 => ( is => 'rw', isa => 'Str' );
has 'index'                 => ( is => 'rw', isa => 'HashRef' );

sub BUILD {
  my $self = shift;

  $self->index( { words => {}, lengths => {}, pubs => {} } );

  $self->plugin_name('Duplicates');
}

sub get_model {
  my $self = shift;
  my $model = Paperpile::Model::Library->new( { file => $self->_db_file } );
  return $model;
}

sub connect {
  my $self = shift;

  $self->_db_file( $self->file );
  $self->_data( [] );

  my $dupl_keys     = {};
  my $dupl_partners = {};

  # parameters that control the number of
  # putative duplicates to look at
  my $hd_small          = 30;
  my $hd_medium         = 20;
  my $hd_large          = 12;
  my $nearest_neighbors = 10;
  my $shash             = $self->shash;

  $self->build_index;

  my $N               = @{ $self->index->{pubs} };
  my %comparison_hash = ();

  # I benchmarked it on my computer; and binary key
  # calculations and sorting come with some overhead
  # Below a library size of 500, we stick to the
  # old approach and do all pairwise comparisons
  if ( $N < 500 ) {
    foreach my $i ( 0 .. $N - 2 ) {
      $comparison_hash{$i} = [];
      foreach my $j ( $i + 1 .. $N - 1 ) {
        push @{ $comparison_hash{$i} }, $j;
      }
    }
  } else {

    # call shash and get binary keys
    ( my $tmp_fh, my $tmpfile_in ) = tempfile( OPEN => 1 );
    ( undef, my $tmpfile_out ) = tempfile( OPEN => 0 );
    my @tmp_merged  = ();
    my @tmp_lengths = ();

    foreach my $i ( 0 .. $N - 1 ) {
      $comparison_hash{$i} = [];
      my $tmptitle = 'dummy';
      if ( $self->index->{pubs}->[$i]->{title} ) {
        $tmptitle = $self->index->{pubs}->[$i]->{title};
      }
      $tmptitle =~ s/\n//g;
      push @tmp_lengths, length($tmptitle);
      print $tmp_fh $tmptitle, "\n";
    }
    close($tmp_fh);

    # call shash
    system("$shash '$tmpfile_in' > '$tmpfile_out'");

    # read in binary strings
    open( FILE, $tmpfile_out );
    my $c = 0;
    while ( my $line = <FILE> ) {
      chomp $line;
      ( my $key = $line ) =~ s/(\S+)(.*)/$1/;
      push @tmp_merged, [ $key, $c ];
      $c++;
    }
    close(FILE);
    unlink($tmpfile_in);
    unlink($tmpfile_out);

    if ( $c != $N ) {
      NetFormatError->throw(
        error   => 'Failed to calculate binary key for all instances',
        content => ''
      );
    }

    # sort binary keys alphabetically
    @tmp_merged = sort { $$a[0] cmp $$b[0] } @tmp_merged;

    # in each round:
    # calculate hamming distance to nearest neigbhors and remeber those
    # that are below the threshold
    # shift string by one char
    # sort binary keys again
    for my $bincounter ( 2 .. 64 ) {
      foreach my $j ( 0 .. $#tmp_merged - 1 ) {

        # take a look at the nearest neighbors
        my $max_to_look_at =
          ( $j + $nearest_neighbors > $#tmp_merged ) ? $#tmp_merged - $j : $nearest_neighbors;

        for my $k ( 1 .. $max_to_look_at ) {
          my $idx = $j + $k;
          my $distance = _hd( $tmp_merged[$j]->[0], $tmp_merged[$idx]->[0] );

          my $local_threhold = $hd_small;
          $local_threhold = $hd_medium
            if ($tmp_lengths[ $tmp_merged[$j]->[1] ] >= 50
            and $tmp_lengths[ $tmp_merged[$j]->[1] ] <= 150 );
          $local_threhold = $hd_large if ( $tmp_lengths[ $tmp_merged[$j]->[1] ] > 150 );
          if ( $distance <= $local_threhold ) {

            # if they differ dramatically in length, we skip
            my $length_comp =
              $tmp_lengths[ $tmp_merged[$j]->[1] ] / $tmp_lengths[ $tmp_merged[$idx]->[1] ];
            next if ( $length_comp < 0.5 or $length_comp > 2 );

            push @{ $comparison_hash{ $tmp_merged[$j]->[1] } }, $tmp_merged[$idx]->[1];
          }
        }
      }

      # we do not need to shift and sort after the last one
      last if ( $bincounter == 64 );

      # shift by one
      foreach my $j ( 0 .. $#tmp_merged ) {
        $tmp_merged[$j]->[0] =~ s/(.)(.*)/$2$1/;
      }

      # sort again
      @tmp_merged = sort { $$a[0] cmp $$b[0] } @tmp_merged;
    }

  }

  # now do regular pairwise comparisons on the selected
  # candidates
  foreach my $i ( 0 .. $N - 1 ) {
    next if ( $#{ $comparison_hash{$i} } == -1 );

    my $guid_i = $self->index->{pubs}->[$i]->{guid};
    next if ( exists $dupl_keys->{$guid_i} );

    my @words_i  = keys %{ $self->index->{words}->{$guid_i} };
    my $title_i  = $self->index->{pubs}->[$i]->{title};
    my $length_i = $self->index->{lengths}->{$guid_i};

    # 1/3 of words may mismatch
    my $max_mismatch = int( $self->index->{lengths}->{$guid_i} * 0.33 );

    my %seen = ();
    my @uniqu = grep { !$seen{$_}++ } @{ $comparison_hash{$i} };

    foreach my $j (@uniqu) {
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
  foreach my $cluster ( sort { $a <=> $b } values %{$dupl_keys} ) {
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
      $pub->_db_connection( $self->_db_file );
      $pub->refresh_attachments;
    }
  }

  return $self->total_entries;
}

sub page {
  ( my $self, my $offset, my $limit ) = @_;

  my $dbh = $self->get_model->dbh;

  my @page = ();

  # Check if data still exists and remove items that have been
  # trashed; should be moved into a transaction to be thread safe like
  # everything else;
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
  $self->index->{pubs} = \@all_pubs;

  # Hash for all pubs indexed by guid that holds hash with title words
  $self->index->{words} = \%index;

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

  my ( $self, $dup_id, $merged_pub ) = @_;

  my @new_data = ();

  my $is_first = 1;

  foreach my $pub ( @{ $self->_data } ) {

    if ( $is_first and ( $pub->_dup_id eq $dup_id ) ) {
      $merged_pub->_dup_id(undef);
      push @new_data, $merged_pub;
      $self->_hash->{ $merged_pub->guid } = $merged_pub;
      $is_first = 0;
    }

    if ( $pub->_dup_id eq $dup_id ) {
      delete( $self->_hash->{ $pub->guid } );
    } else {
      push @new_data, $pub;
    }
  }

  $self->_data( \@new_data );

  $self->total_entries( scalar @{ $self->_data } );

}

sub _hd {
  return ( $_[0] ^ $_[1] ) =~ tr/\001-\255//;
}

1;
