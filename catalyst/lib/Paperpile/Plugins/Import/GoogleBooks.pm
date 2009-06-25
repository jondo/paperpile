package Paperpile::Plugins::Import::GoogleScholar;
 
use Carp;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;
use XML::Simple;
use Lingua::EN::NameParse;
#use Date::Components;
use 5.010;
 
use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Paperpile::Library::Journal;
use Paperpile::Utils;
 
extends 'Paperpile::Plugins::Import';
 
# The search query to be send to GoogleScholar
has 'query' => ( is => 'rw' );
 
# The main search URL
my $searchUrl = 'http://books.google.com/books/feeds/volumes?q=';

# GoogleBooks maximally provides 20 entries per search;
has 'max' => ( is => 'rw', isa => 'Int', default => 20 );

sub BUILD {
  my $self = shift;
  $self->plugin_name('GoogleScholar');
}
 
 
 
sub connect {
  my $self = shift;
 
  # Maximum number of entries per page, this is the maximal number google allows to fetch per call.
  $self->{limit} = $self->{max} if($self->{limit} >= $self->{max});
 
  my $browser = Paperpile::Utils->get_browser;  # get new browser
  my $response = $browser->get( $searchUrl . $self->query . "&start-index=1&max-results=" . $self->limit);
  
  if ( $response->is_error ) {
    NetGetError->throw(
      error => $self->{'plugin_name'} . ' query failed: ' . $response->message,
      code  => $response->code
    );
  }
  
  # The response is XML formatted and can be parsed with XML::Simple
  my $result = XMLin($response->content, ForceArray => 1);
#print STDERR Dumper $result;

  # overall number f results, although google only submits max 20 per query
  my $number = $result->{'openSearch:totalResults'}[0]; 
  #print STDERR "number $number\n";

  # cache the xml structure to speed up call to first page afterwards
  # google books ist one-based
  $self->_page_cache( {} );
  $self->_page_cache->{1}->{ $self->limit } = $result;
 
  $self->total_entries($number);
 
  # Return the number of hits
  return $self->total_entries;
}
 

sub page {
  ( my $self, my $offset, my $limit ) = @_;

  # google books is 1-based, paperpile seems to be 0-based
  $offset++;

  # Maximum number of entries per page, this is the maximal number google allows to fetch per call.
  $self->{limit} = $self->{max} if($self->{limit} >= $self->{max});

  # Get the content of the page, either via cache for the first page
  # which has been retrieved in the connect function or send new query
  my $result = '';
  if ($self->_page_cache->{$offset}->{$limit}) {
    $result = $self->_page_cache->{$offset}->{$limit};
  } 
  else {
    my $browser = Paperpile::Utils->get_browser;
    my $query = $searchUrl . $self->query . "&start-index=$offset&max-results=$limit";
    my $response = $browser->get($query);
    if ( $response->is_error ) {
      NetGetError->throw(
        error => $self->{'plugin_name'} . ' query failed: ' . $response->message,
        code  => $response->code
      );
    }
    $result = XMLin($response->content, ForceArray => 1);
  }
#print STDERR Dumper $result;

  # Write output list of Publication records with preliminary information 
  my $page = [];
  
  # args needed for Lingua::EN::NameParse
  my %args = (
    auto_clean     => 1,
    force_case     => 1,
    lc_prefix      => 1,
    initials       => 3,
    allow_reversed => 1
  );
  
  # collect data
  foreach my $book (@{$result->{entry}}) {
#print STDERR "entr=$urlID\n";
print STDERR Dumper $book;

    my $pub = Paperpile::Library::Publication->new(type=>"BOOK");
    my @tmp = ();
    
    #############################
    # collect titles
    my $title = '';
    if(exists $book->{'dc:title'}) {
      my @tmp = @{$book->{'dc:title'}};    
      $title = join(': ', @tmp);
    }
#print STDERR "titel: $title";
    #############################
    # collect authors
    my @authors;
    my $authors_display = '';
    @tmp = ();
    if(exists $book->{'dc:creator'}) {
      # unfortunately I saw authors separated by ' / '
      foreach my $aut (@{$book->{'dc:creator'}}) {
        if($aut =~ / \/ /) {
          my @ret = split / \/ /, $aut;
          foreach my $single_name (@ret) {
            push @tmp, $single_name;
          }
        }
        else {
          push @tmp, $aut;
        }
      }
      $authors_display = join(', ', @tmp);
#print STDERR "authors_display: $authors_display\n";

      # parse each author name
      foreach my $author (@tmp) {
#print STDERR "author: $author\n";
        my $parser = new Lingua::EN::NameParse(%args);
        my $error = $parser->parse($author);
        if ( $error == 0 ) {
          my $correct_casing = $parser->case_all_reversed;
          (my $last, my $first) = split(/, /, $correct_casing);
#print STDERR "last=$last, first=$first\n";
          # make a new author object
          push @authors,
            Paperpile::Library::Author->new(
                collective => $author,
                last  => $last,
                first => $first,
                jr    => '',
            )->normalized;          
        }
        else {
          print STDERR "Warning: Could not parse author '$author'\n";
        }
      }    
    }
    
    #############################
    # collect publisher
    my $publisher = '';
    @tmp = ();
    if(exists $book->{'dc:publisher'}) {
      @tmp = @{$book->{'dc:publisher'}};
    }
    $publisher = join('; ', @tmp); # actually it should only be one publisher, but who knows...
#print STDERR "publisher: $publisher\n";
    
    #############################
    # collect date (only year?)
#    my ($month, $day, $year);
#    @tmp = ();
#    if(exists $book->{'dc:date'}) {
#      foreach my $d (@{$book->{'dc:date'}}) {
#        my ($month, $day, $year);# = date_only_parse($d);
#        push @tmp, $year;
#      }
#    }
#    $year = join('; ', @tmp); # actually it should only be one year, but who knows...



    
    $pub->title( $title ) if($title ne '');
    $pub->_authors_display( $authors_display ) if($authors_display ne '');
    $pub->authors( join( ' and ', @authors ) ) if(scalar(@authors)>1);
    $pub->publisher( $publisher ) if($publisher ne '');
    #$pub->year( $year ) if($year);    
    #$pub->_citation_display(  );
    #$pub->linkout(  );
    #$pub->_details_link(  );
    #$pub->refresh_fields;
    push @$page, $pub;
  }
 
  # we should always call this function to make the results available
  # afterwards via find_sha1
  $self->_save_page_to_hash($page);
 
  return $page;
}



 
1;