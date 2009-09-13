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
use Paperpile::Library::Journal;

extends 'Paperpile::Plugins::Import';

has '_db_file' => ( is => 'rw' );
has 'file' => ( is => 'rw' );
has '_data' => ( is => 'rw', isa => 'ArrayRef' );



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

  print STDERR "CONNECT: entering\n";

  $self->_db_file( $self->file );

  my $model = $self->get_model;
  #$self->total_entries( $model->fulltext_count("") );
  $self->_save_page_to_hash( $model->all );

  $self->_data([]);

# sort publications into hash of title-length-differences equivalence classes
# serves as a heuristic to figure out which publications have to be compared
# all of the same class (=same or similar length) have to be analysed in detail
# title length difference between two "neighboured" publications (same or similar title length) must be controlled
# min and max lengths of a equivalence class must be controlled (if difference is too big, different class)
  my %classes;    # used to sort items by title length and to define equivalence classes
  my %compare;    # keeps equivalence classes
  my %meta;       # additional info about equivalence classes, most important: min/max lengths
  my $titleLengthPartnersCutoff = 5;
  my $titleLengthMinMaxCutoff   = 5;
  my ( $minTitleLength, $maxTitleLength, $avgTitleLength ) = ( 9999999, 0, 0 );

  # get length statistics
  my $len = 0;
  foreach my $m ( @{ $model->all } ) {

    #print STDERR Dumper $m, "\n";exit;
    $len = length $m->title;

    #$maxTitleLength = $len if($len>$maxTitleLength);
    #$minTitleLength = $len if($len<$minTitleLength);
    #$avgTitleLength += $len;
    $classes{$len}{ $m->sha1 } = 1;
  }

  #$avgTitleLength /= $self->total_entries;

  #print STDERR "total entries : ", $self->total_entries, "\n";

  #print STDERR "minTitleLength: ", $minTitleLength, "\n";
  #print STDERR "maxTitleLength: ", $maxTitleLength, "\n";
  #print STDERR "avgTitleLength: ", $avgTitleLength, "\n";

  # sort by title length
  my $classID   = 1;
  my $oldLength = 0;
  my $round     = 0;

# min title length of current class
# max is always the current one, cause list is sorted, min is always the first one, cause list is sorted!
  my $minTitleClassLength = 0;

  # build equivalence classes
  foreach my $l ( sort { $a <=> $b } keys %classes ) {
    foreach my $sha1 ( keys %{ $classes{$l} } ) {

      #print STDERR $l, " ", $sha1, "\n";
      $round++;

      # now compare each other as long as their length difference doesn't exceed the length cutoff
      if ( $round > 1 ) {
        if ( ( $l - $oldLength ) <= $titleLengthPartnersCutoff
          && ( $l - $minTitleClassLength ) <= $titleLengthMinMaxCutoff )
        {    # similar length, they have to be analysed in detail
          $compare{$classID}{$sha1} = $l;
          $meta{$classID}{maxLength} = $l;
        } else {    # length difference is too big, we change equivalence class
          $classID++;
          $compare{$classID}{$sha1}  = $l;    # don't forget current item
          $minTitleClassLength       = $l;
          $meta{$classID}{minLength} = $l;
        }
      } elsif ( $round == 1 ) {
        $compare{$classID}{$sha1}  = $l;      # init with furst item
        $minTitleClassLength       = $l;
        $meta{$classID}{minLength} = $l;
      }

      $oldLength = $l;                        # remember for next round;
    }
  }

# we'll analyse all items of the same class with all items of the same class
# and
# although border-items (last item(s) of the current class (all items with maxClassLength) with first item(s) of the next class (all items with minClassLength))
  my $distance = 0;
	my $countDuplicates = 0;
  my @lastKeys;
  foreach my $classID ( sort { $a <=> $b } keys %compare ) {
    my @keys =
      sort { $compare{$classID}{$a} <=> $compare{$classID}{$b} } keys %{ $compare{$classID} };

    if ( scalar @keys > 1 ) {    # check within same class, but only if there are at least 2 items
      for ( my $i = 0 ; $i < $#keys ; $i++ ) {

        #print STDERR $classID, " ", $compare{$classID}{$keys[$i]}, " ", $keys[$i], "\n";
        for ( my $j = 0 ; $j < $#keys ; $j++ ) {
          if ( $i != $j && $i < $j ) {

            #print STDERR $keys[$i], ' VS ', $keys[$j], "\n";
            my $a = $self->find_sha1( $keys[$i] );
            my $b = $self->find_sha1( $keys[$j] );
						if( lc(substr($a->{title}, 0, 1)) eq lc(substr($b->{title}, 0, 1)) ) {
							if ( $self->_match_title( lc($a->{title}), lc($b->{title}) ) ) {
								print STDERR
									"duplicates: \"$a->{title}\" ($a->{sha1})  VS  \"$b->{title}\" ($b->{sha1})\n";

								push @{$self->_data}, $a;
								push @{$self->_data}, $b;
								
								$countDuplicates++;
							}
            }
          }
        }
      }
    }

    # additionally check border items
    if ( $classID > 1 ) {
      my $lastID = $classID - 1;

      # compare minLength items of current with maxLength items of last class
      for ( my $i = 0 ; $i < $#keys ; $i++ ) {
        if ( $meta{$classID}{minLength} == $compare{$classID}{ $keys[$i] } )
        {    # for all of current class with min length
          for ( my $j = 0 ; $j < $#lastKeys ; $j++ ) {
            if ( $meta{$lastID}{maxLength} == $compare{$lastID}{ $lastKeys[$j] } )
            {    # for all of last class with max length
              my $a = $self->find_sha1( $keys[$i] );
              my $b = $self->find_sha1( $lastKeys[$j] );
							if( lc(substr($a->{title}, 0, 1)) eq lc(substr($b->{title}, 0, 1)) ) {
								if ( $self->_match_title( lc($a->{title}), lc($b->{title}) ) ) {
									print STDERR
										"duplicates (border!): \"$a->{title}\" ($a->{sha1})  VS  \"$b->{title}\" ($b->{sha1})\n";
									
									push @{$self->_data}, $a;
									push @{$self->_data}, $b;
									
									$countDuplicates++;
								}
							}
            }
          }
        }
      }
    }

    @lastKeys = @keys;    # for next round

    #print STDERR "\n";
  }

	print STDERR "found ", $countDuplicates, " pairwise duplications!\n";
  print STDERR "CONNECT: leaving\n";

  $self->total_entries(scalar @{$self->_data});

  return $self->total_entries;
}

sub page {
  ( my $self, my $offset, my $limit ) = @_;

  #my $model = $self->get_model;
  #my $page;
  #$page = $model->fulltext_search( "", $offset, $limit );
  #$self->_save_page_to_hash($page);
  #return $page;

  my @page = ();

  for my $i ( 0 .. $limit - 1 ) {
    last if ($offset + $i == $self->total_entries );
    push @page, $self->_data->[ $offset + $i ];
  }

  $self->_save_page_to_hash(\@page);

  return \@page;

}

1;
