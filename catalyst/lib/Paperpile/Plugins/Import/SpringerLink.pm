package Paperpile::Plugins::Import::SpringerLink;

use Carp;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;
use XML::Simple;
use HTML::TreeBuilder::XPath;
use 5.010;

use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Paperpile::Library::Journal;
use Paperpile::Utils;

extends 'Paperpile::Plugins::Import';

# The search query to be send to SpringerLink Portal
has 'query' => ( is => 'rw' );


my $searchUrl = 'http://springerlink.com/content/?hl=u&k=';


sub BUILD {
  my $self = shift;
  $self->plugin_name('SpringerLink');
}

sub connect {
  my $self = shift;

  
  my $browser = Paperpile::Utils->get_browser;

  # Get the results
  (my $tmp_query = $self->query) =~ s/\s+/+/g;
  my $response = $browser->get( $searchUrl . $tmp_query );
  
  my $content  = $response->content;

  # save first page in cache to speed up call to first page afterwards
  $self->_page_cache( {} );
  $self->_page_cache->{0}->{ $self->limit } = $content;

  # Nothing found
  if ( $content =~ /No results returned for your criteria./ ) {
    $self->total_entries(0);
    return 0;
  }

  # Try to find the number of hits
  # Maybe that could be done faster with XPath, one has to rethink
  if ( $content =~ m/<td>([1234567890,]+)\sResults<\/td>/ ) {
    my $number = $1;
    $number =~ s/,//;
    $self->total_entries($number);
  } else {
    die('Something is wrong with the results page.');
  }

  # Return the number of hits
  return $self->total_entries;
}

sub page {
  ( my $self, my $offset, my $limit ) = @_;

  # Get the content of the page, either via cache for the first page
  # which has been retrieved in the connect function or send new query
  my $content = '';
  if ( $self->_page_cache->{$offset}->{$limit} ) {
      $content = $self->_page_cache->{$offset}->{$limit};
  } else {
      my $browser = Paperpile::Utils->get_browser;
      (my $tmp_query = $self->query) =~ s/\s+/+/g;
      my $response = $browser->get( $searchUrl . $tmp_query . '&o=' . $offset );
      $content = $response->content;
  }
  
  # now we parse the HTML for entries
  my $tree = HTML::TreeBuilder::XPath->new;
  $tree->utf8_mode(1);
  $tree->parse_content($content);

  my %data = (
    authors   => [],
    titles    => [],
    citations => [],
    urls      => [],
    bibtex    => [],
    pdf       => []  
  );

  # Each entry is part of an unorder list 
  my @nodes = $tree->findnodes('/html/body/*/*/*/*/*/*/*/*/*/*/*/*/*/div[@class="primitiveControl"]');
  
  foreach my $node (@nodes) {
      
      # Title 
      my ( $title, $author, $citation, $pdf, $url );
      $title = $node->findvalue('./div[@class="listItemName"]/a');

      # authors
      my @author_nodes = $node->findnodes('./div[@class="listAuthors"]');
      $author = $author_nodes[0]->as_text();
      # for some reasons it might happen that there are now authors (book chapters)
      # this will cuase problems with the sha key.
      # in these cases we give Nomen Nescio - NN
      $author = 'NN' if ($author eq '');

      # citation
      my @citation_nodes = $node->findnodes('./div[@class="listParents"]');
      $citation = $citation_nodes[0]->as_text();

      # PDF link
      $pdf = $node->findvalue('./table/tr/td/a/@href');
      $pdf = 'http://springerlink.com' . $pdf;
      $pdf =~ s/pdf\/content.*html$/pdf/;

      # URL linkout
      $url = $node->findvalue('./div[@class="listItemName"]/a/@href');
      $url = 'http://springerlink.com' . $url;
      
      print STDERR "URL :: $url\n";


      push @{ $data{titles} }, $title;
      push @{ $data{authors} }, $author;
      push @{ $data{citations} }, $citation;
      push @{ $data{pdf} }, $pdf;
      push @{ $data{urls} }, $url;
  }


  # Write output list of Publication records with preliminary
  # information. We save to the helper fields _authors_display and
  # _citation_display which will be displayed in the front end.
  my $page = [];

  foreach my $i ( 0 .. @{ $data{titles} } - 1 ) {
    my $pub = Paperpile::Library::Publication->new();
    $pub->title( $data{titles}->[$i] );
    $pub->_authors_display( $data{authors}->[$i] );
    $pub->_citation_display( $data{citations}->[$i] );
    $pub->linkout( $data{urls}->[$i] );
    $pub->pdf_url( $data{pdf}->[$i] );
    $pub->_details_link( $data{urls}->[$i] );
    $pub->refresh_fields;
    push @$page, $pub;
  }

  # we should always call this function to make the results available
  # afterwards via find_sha1
  $self->_save_page_to_hash($page);

  return $page;

}

# We parse ACM Portal in a two step process. First we scrape off what
# we see and display it unchanged in the front end via
# _authors_display and _citation_display. If the user clicks on an
# entry the missing information is completed from the details page
# where we find the abstract and a BibTeX link. This ensures fast
# search results and avoids too many requests to ACM which is
# potentially harmful.

sub complete_details {

  ( my $self, my $pub ) = @_;

  my $browser = Paperpile::Utils->get_browser;
  
  # Get the HTML page. I have tried to use the RIS export, but that
  # did not work. There seems to be a protection, can only be
  # used in the borwser.
  print STDERR $pub->_details_link,"\n";
  my $response = $browser->get( $pub->_details_link );
  my $content = $response->content;

  # now we parse the HTML for entries
  my $tree = HTML::TreeBuilder::XPath->new;
  $tree->utf8_mode(1);
  $tree->parse_content($content);

  my $title = $tree->findvalue('/html/body/form/table/tr/td[2]/table/tr/td/div[2]/table/tr/td[2]/h2');
  
  # let's find the abstract first
  my $abstract = $tree->findvalue('/*/*/*/*/*/*/*/*/*/*/*/*/*/div[@class="Abstract"]');
  $abstract =~ s/^Abstract\s+//i;

  # Now we complete the other details
  my @ids = $tree->findnodes('/*/*/*/*/*/*/*/*/*/div[@class="primitiveControl"]/table/tr/td/table/tr/td[@class="labelName"');
  my @values = $tree->findnodes('/*/*/*/*/*/*/*/*/*/div[@class="primitiveControl"]/table/tr/td/table/tr/td[@class="labelValue"');

  # We first build a nice hash, than we can see what stuff we have got
  my %details = ( );
  foreach my $i (0 .. $#ids) {
      # It might happen that there is the same identifier more than once
      if (defined $details{ $ids[$i]->as_text() }) {
	  $details{ $ids[$i]->as_text() } .= "%%BREAK%%".$values[$i]->as_text();
      } else {
	  $details{ $ids[$i]->as_text() } = $values[$i]->as_text();
      }
  }

  (my $journal, my $doi, my $volume, my $issue, my $pages, my $year, my $month, my $issn);
  
  # pages are easy
  $pages = $details{'Pages'} if ($details{'Pages'});

  # If there is a copyright field, then it is the year
  $year = $details{'Copyright'} if ($details{'Copyright'});

  # sometimes Volume, Issue and Year are in this field
  if ($details{'Issue'}) {
      if ($details{'Issue'} =~ m/Volume\s(\d+)/) {
	  $volume = $1;
      }
      if ($details{'Issue'} =~ m/Number\s(\d+)/) {
	  $issue = $1;
      }
      if ($details{'Issue'} =~ m/(January|February|March|April|May|June|July|August|September|October|November|December)/) {
	  $month = $1;
      }
      if ($details{'Issue'} =~ m/((19|20)\d\d)$/) {
	  $year = $1 if (!$year);
      }
  }

  # sometimes for book series, the volume might be a separate field
  if ($details{'Volume'}) {
      if ($details{'Volume'} =~ m/\s(\d+)/) {
	  $volume = $1;
      }
  }

  # there might be more DOIs. Usually, the DOI which is the longest
  # is the right one
  if ($details{'DOI'}) {
      my @tmp = split(/%%BREAK%%/, $details{'DOI'});
      my $max = 0;
      my $winner = -1;
      foreach my $i (0 .. $#tmp) {
	  if (length($tmp[$i]) > $max) {
	      $max = length($tmp[$i]);
	      $winner = $i;
  }
      }
      $doi = $tmp[$winner];
  }

  # ISSN 
  if ($details{'ISSN'}) {
      if ($details{'ISSN'} =~ m/(.*)\s\(Print/) {
	  $issn = $1;
      } else {
	  $issn = $details{'ISNN'};
      }
  }
  
  # let's see if there is a journal entry, otherwise it will be
  # a book chapter
  if ($details{'Journal'}) {
      $journal = $details{'Journal'};
  }
  if ($details{'Book Series'}) {
      $journal = $details{'Book Series'};
  }

  # Now we prepare the authors correctly
  my $authors_new = $tree->findvalue('/html/body/form/table/tr/td[2]/table/tr/td/table/tr/td/div[2]/p[@class="AuthorGroup"]');
  $authors_new =~ s/\d//g;
  $authors_new =~ s/\x{A0}/ /g;
  $authors_new =~ s/\s+,/,/g;
  $authors_new =~ s/,+/,/g;
  $authors_new =~ s/\s+/ /g;
  my @authors_tmp = split(/,/, $authors_new );
  if ( $authors_tmp[$#authors_tmp] =~ m/(.+)(\sand\s)(.*)/ ) {
      $authors_tmp[$#authors_tmp] = $1;
      $authors_tmp[$#authors_tmp+1] = $3;
  }
  if ( $authors_tmp[$#authors_tmp] =~ m/^\sand\s(.+)/ ) {
      $authors_tmp[$#authors_tmp] = $1;
  }
  my @authors = ();
  foreach my $entry (@authors_tmp) {
      $entry =~ s/ü/\\"{u}/;
      $entry =~ s/ö/\\"{o}/;
      $entry =~ s/ä/\\"{a}/;    
      push @authors,
        Paperpile::Library::Author->new()->parse_freestyle( $entry )->bibtex();
  }
   
  # Create a new Publication object
  my $full_pub = Paperpile::Library::Publication->new( pubtype => 'ARTICLE' );

  # Add new values 
  $full_pub->title( $title )       if ( $title );
  $full_pub->pages( $pages )       if ( $pages );
  $full_pub->journal( $journal )   if ( $journal );
  $full_pub->volume( $volume )     if ( $volume );
  $full_pub->issue( $issue )       if ( $issue );
  $full_pub->year( $year )         if ( $year );
  $full_pub->issn( $issn )         if ( $issn );
  $full_pub->abstract( $abstract ) if ( $abstract );
  $full_pub->authors( join( ' and ', @authors ) );

  # Add values from the old object  
  $full_pub->linkout( $pub->linkout );
  $full_pub->pdf_url( $pub->pdf_url );

  # Note that if we change title, authors, and citation also the sha1
  # will change. We have to take care of this.
  my $old_sha1 = $pub->sha1;
  my $new_sha1 = $full_pub->sha1;
  delete( $self->_hash->{$old_sha1} );
  $self->_hash->{$new_sha1} = $full_pub;

  return $full_pub;

}

1;
