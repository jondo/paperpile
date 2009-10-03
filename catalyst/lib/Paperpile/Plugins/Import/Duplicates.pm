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

  $self->_db_file( $self->file );
	$self->_data([]);
	
  my $model = $self->get_model;
  
	#$self->total_entries( $model->fulltext_count("") );
  #$self->_save_page_to_hash( $model->all );
  

	print STDERR "calling model -> all!\n"; 
	my @data = @{ $model->all }; # get all publications
	print STDERR "finished calling model -> all!\n";
	my @lengths=(); # number of words for each title
	my @index=(); # array of hashes to index words of each title
	my $countDuplCandidates = 0; # number of general candidate duplications, e.g. title i might be substr of title j. 
	my $countDuplDirect = 0; # number of directly identified duplications
	my $countDuplMatching = 0; # number of duplications that additionally needed matching
	my $countDuplOverall = 0; # number of real duplications
	
	# get and count words of titles
	foreach my $i (0..$#data){	
		$index[$i]={};
		my @words = split(/\s+/, lc($data[$i]->{title}));
		$lengths[$i]=scalar @words;
		foreach my $word (@words){
			$index[$i]->{$word}=1;
		}
	}
	
	foreach my $i (0..$#data){
		my @words=keys %{$index[$i]};

		# 1/3 of words may mismatch; play with this cutoff
		my $max_mismatch=int($lengths[$i]*0.33);

		foreach my $j (0..$#data){
			
			# don't check papers with themselves
			# and don't check pairs twice (i vs j and j vs i, i vs j is enough)
			next if $i >= $j; 

			# Don't compare if lengths are too different
			# play with this cutoff
			next if abs($lengths[$i]-$lengths[$j])>5;

			my $matches=0;
			my $mismatches=0;

			# Match each word, stop if too many words are missing
			foreach my $word (@words){
				if ($index[$j]->{$word}){
					$matches++;
				} else {
					$mismatches++;
				}
				last if $mismatches>$max_mismatch;
			}

			# Matches for further analysis; right now matches are printed if
			# all words could be matched;
			# Todo: choose criterion to select those for edit distance calculation
			#       if exact equality (x eq y) then we don't need distance calculation
			#       This should limit distance calculations to a reasonable number
			my $wordcount_i = scalar @words;
			my $wordcount_j = keys %{$index[$j]};
			
			# extend mismatches (to get all differences	if wordcount differs)	
			$mismatches += abs($wordcount_i - $wordcount_j);
			
			if( $mismatches <= $max_mismatch ){
				$countDuplCandidates++;
				print STDERR "$i\t", $data[$i]->{title}, "\n";
				print STDERR "$j\t", $data[$j]->{title}, "\n";
				print STDERR "($wordcount_i vs $wordcount_j, matches=$matches, mismatches=$mismatches, max_mismatches=$max_mismatch)\n";
				
				if(abs($wordcount_i - $wordcount_j)<=$max_mismatch) {
					print STDERR "BE CAREFULL...";
					
					if($mismatches==0) {
						# exact equality (x eq y), we don't need distance calculation
						print STDERR "GOT YA! (direct)\n";
						$countDuplDirect++;
						push @{$self->_data}, $data[$i];
						push @{$self->_data}, $data[$j];
					}
					else { # perform distance calculation
						if ( $self->_match_title( lc($data[$i]->{title}), lc($data[$j]->{title}) ) ) {
							print STDERR "GOT YA! (matching)\n";
							$countDuplMatching++;
							push @{$self->_data}, $data[$i];
							push @{$self->_data}, $data[$j];							
						}
						else {
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
	print STDERR "  ->      directly identified: ", $countDuplDirect, "\n";
	print STDERR "  -> via distance calculation: ", $countDuplMatching, "\n";
	print STDERR "overall identified duplicates: ", $countDuplOverall, "\n";
	print STDERR "neglected candidates         : ", ($countDuplCandidates-$countDuplOverall), "\n\n";
  
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
