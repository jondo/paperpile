package Paperpile::Plugins::Import::GoogleBooks;
 
use Carp;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;
use XML::Simple;
use Lingua::EN::NameParse;
use HTML::TreeBuilder::XPath;
use Encode;
use 5.010;
 
use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Paperpile::Library::Journal;
use Paperpile::Utils;
 
extends 'Paperpile::Plugins::Import';
 
# The search query to be send to GoogleBooks
has 'query' => (is => 'rw');
 
# The main search URL
my $searchUrl = 'http://books.google.com/books/feeds/volumes?q=';

# GoogleBooks maximally provides 20 entries per search
has 'max' => ( is => 'rw', isa => 'Int', default => 20 );

sub BUILD {
  my $self = shift;
  $self->plugin_name('GoogleBooks');
}
 
 
 
sub connect {
  my $self = shift;
 
  my $browser = Paperpile::Utils->get_browser;  # get new browser
  my $response = $browser->get( $searchUrl . $self->query . "&start-index=1&max-results=" . $self->limit);
  
  $self->limit($self->max) if($self->limit >= $self->max);
  
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

  my $browser = Paperpile::Utils->get_browser;
  my $query =  '';
  my $response;
  my $responseDetails;
  
  $self->limit($self->max) if($self->limit >= $self->max);
  
  # google books is 1-based, paperpile seems to be 0-based
  $offset++;

  # Get the content of the page, either via cache for the first page
  # which has been retrieved in the connect function or send new query
  my $result = '';
  if ($self->_page_cache->{$offset}->{$limit}) {
    $result = $self->_page_cache->{$offset}->{$limit};
  } 
  else {
    $browser = Paperpile::Utils->get_browser;
    $query = $searchUrl . $self->query . "&start-index=$offset&max-results=$limit";
    $response = $browser->get($query);
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
  my $i=0;
  #for(my $i=1; $i<=$self->{max}; $i++) {
  foreach my $book (@{$result->{entry}}) {
    #my $book = ${$result->{entry}}[$i];
    $i++;
#print STDERR "entr=$urlID\n";
#print STDERR Dumper $book;

    my $pub = Paperpile::Library::Publication->new(pubtype=>"BOOK");
    my @tmp = ();
    
    #############################
    # collect titles
    my $title = '';
    if(exists $book->{'dc:title'}) {
      my @tmp = @{$book->{'dc:title'}};    
      $title = join(': ', @tmp);
    }
#print STDERR $i, "/", $limit, ": ", $title, "\n";

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
        my $failure = 0;
        if ( $error == 0 ) {
          my $correct_casing = $parser->case_all_reversed;
          my ($last, $first) = split(/, /, $correct_casing);
#print STDERR "last=$last, first=$first\n";
          # make a new author object
          if(length($last)>0 && length($first)>0) {
            push @authors,
              Paperpile::Library::Author->new(
                  last  => $last,
                  first => $first,
                  jr    => '',
              )->normalized;
          }
          else {
            $failure = 1;
          }
        }
        else {
          $failure = 1;
        }
        
        if($failure) {
          push @authors,
            Paperpile::Library::Author->new(
                collective => $author,
                last  => '',
                first => '',
                jr    => '',
            )->normalized; 
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
    my $year;
    @tmp = ();
    if(exists $book->{'dc:date'}) {
      foreach my $d (@{$book->{'dc:date'}}) {
        if($d =~ /(\d\d\d\d)/) {
            push @tmp, $1;
        }
      }
    }
    $year = join('; ', @tmp); # actually it should only be one year, but who knows...

    #############################
    # collect ISBN, ISSN
    my ($isbn, $issn) = ('', '');
    @tmp = ();
    if(exists $book->{'dc:identifier'}) {
      foreach my $id (@{$book->{'dc:identifier'}}) {
        if($id =~ /ISBN:(\S+)/) {
            push @tmp, $1;
        }
      }
      $isbn = join('; ', @tmp);
      
      foreach my $id (@{$book->{'dc:identifier'}}) {
        if($id =~ /ISSN:(\S+)/) {
            push @tmp, $1;
        }
      }
      $issn = join('; ', @tmp);
    }

    #############################
    # collect abstract
    # TODO: Maybe replace it with the more detailed description of the preview website
    my $abstract = '';
    @tmp = ();
    if(exists $book->{'dc:description'}) {
      @tmp = @{$book->{'dc:description'}};
    }
    $abstract = join('; ', @tmp);
#print STDERR "abstract=$abstract\n";

    #############################
    # collect url
    my $url = '';
    if(exists $book->{'link'}) {
      foreach my $link (@{$book->{'link'}}) {
        if(exists $link->{rel}) {
#print STDERR "link-rel  = $link->{rel}\n";
#print STDERR "link-href = $link->{href}\n";
          if($link->{rel} =~ /info$/) {
            $url = $link->{href} if(exists $link->{href});
          }
        }
      }      
    }
#print STDERR "url=$url\n";

    #############################
    # collect pages
    # not every book has pages info
    my $pages = '';
    foreach my $f (@{$book->{'dc:format'}}) {
      if($f =~ /(\d+)\s*pages/) {
				$pages = $1;
      }      
    }
#print STDERR "pages=$pages\n";

    #############################
    # collect pages
    # not every book has pages info

#print STDERR Dumper @authors;    
    $pub->title( $title ) if($title);
		$pub->booktitle( $title ) if($title); 
    $pub->_authors_display( $authors_display ) if($authors_display);
		if(scalar(@authors)==1) {
			$pub->authors($authors[0]);
		}
		elsif(scalar(@authors)>1) {
			$pub->authors( join( ' and ', @authors ) );
		}
    $pub->publisher( $publisher ) if($publisher);
    $pub->year( $year ) if($year);
    $pub->isbn( $isbn ) if($isbn);
    $pub->issn( $issn ) if($issn);
    $pub->abstract( $abstract ) if($abstract);		
    $pub->url( $url ) if($url);
		$pub->pages( $pages ) if($pages);
    #$pub->_citation_display(  );
    $pub->linkout($url) if($url);
    $pub->_details_link($url) if($url);
    $pub->refresh_fields;
    push @$page, $pub;
  }
 
  # we should always call this function to make the results available
  # afterwards via find_sha1
  $self->_save_page_to_hash($page);
 
  return $page;
}

sub complete_details {
  ( my $self, my $pub ) = @_;
#print STDERR Dumper $pub;

  my $browser = Paperpile::Utils->get_browser;

  # hold the data we already have
  my $full_pub = Paperpile::Library::Publication->new();
  $full_pub->title( $pub->title ) if($pub->title);
  $full_pub->booktitle( $pub->title ) if($pub->title); 
	$full_pub->_authors_display( $pub->_authors_display ) if($pub->_authors_display);
  $full_pub->authors( $pub->authors ) if($pub->authors);
  $full_pub->publisher( $pub->publisher ) if($pub->publisher);
  $full_pub->year( $pub->year ) if($pub->year);
  $full_pub->isbn( $pub->isbn ) if($pub->isbn);
  $full_pub->issn( $pub->issn ) if($pub->issn);
  $full_pub->abstract( $pub->abstract ) if($pub->abstract);
  $full_pub->url( $pub->url ) if($pub->url);
  $full_pub->pages( $pub->pages ) if($pub->pages);
	$full_pub->linkout($pub->linkout) if($pub->linkout);
  $full_pub->_details_link($pub->_details_link) if($pub->_details_link);


	my $responseDetails = $browser->get($pub->_details_link);
	if ( $responseDetails->is_error ) {
		NetGetError->throw(
			error => $self->{'plugin_name'} . ' query failed: ' . $responseDetails->message,
			code  => $responseDetails->code
		);
	}

  # now we parse the HTML for entries
  my $tree = HTML::TreeBuilder::XPath->new;
  $tree->utf8_mode(1);
  $tree->parse_content($responseDetails->{_content});
	
	

	#############################
  # get PDF-link
	if($responseDetails->{_content} =~ /a href="(\S+)">Download PDF/) {
      $pub->pdf_url($1); # we hold it in both opbjects, maybe we'll need it in the short pub object, too.
      $full_pub->pdf_url($1);
#print STDERR "PDF:", $full_pub->pdf_url, "\n";
  }
	
	#############################
  # try to get complete abstract	
	my @nodes = $tree->findnodes('//*[@id="synopsistext"]');
	if(scalar(@nodes) > 0) {
		my $tmpString = $nodes[0]->as_text();
		$pub->abstract( $tmpString ); # we hold it in both opbjects, maybe we'll need it in the short pub object, too.
    $full_pub->abstract( $tmpString );
	}

  # Note that if we change title, authors, and citation also the sha1
  # will change. We have to take care of this.
  my $old_sha1 = $pub->sha1;
  my $new_sha1 = $full_pub->sha1;
  delete( $self->_hash->{$old_sha1} );
  $self->_hash->{$new_sha1} = $full_pub;

  return $full_pub;
}

 
1;
