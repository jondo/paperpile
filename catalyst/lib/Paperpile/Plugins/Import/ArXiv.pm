package Paperpile::Plugins::Import::ArXiv;

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

# The search query to be send to GoogleScholar
has 'query'           => ( is => 'rw' );

# We need to set a cookie to get links to BibTeX file.
has '_session_cookie' => ( is => 'rw' );

# The main search URL
my $searchUrl = 'http://export.arxiv.org/api/query?search_query=';

sub connect {
  my $self = shift;

  # First we get a LWP user agent. We always should get it via the
  # Utils function because this way we get a correctly configured
  # browser. Additional configuration can be added afterwards if
  # needed.
  my $browser = Paperpile::Utils->get_browser;

  # We have to modify the query string to fit arxiv needs
  my @tmp_words = split(/ /, $self->query);
  foreach my $i (0 .. $#tmp_words)
  {
      $tmp_words[$i] = "all:$tmp_words[$i]";
  }
  my $query_string = join('+AND+', @tmp_words);

  # We now call execute the search
  my $response = $browser->get( $searchUrl . $query_string . '&max_results=100' );

  my $result    = XMLin($response->content, ForceArray => 1);

  #open(TMP,">/home/wash/tmp.dat");
  #print TMP Dumper($response->content);

  # Determine the number of hits
  my $number = 0;
  my @entries = @{$result->{entry}};
  $number = $#entries+1;
  $self->total_entries($number);

  # We store the results so that they can be retrieved afterwards
  # We keep the way of storage that is used in other Plugins
  # The problem is that ArXiv supports paging, i.e. you can
  # retrieve results xx to xx, however you get all results at once
  # So there is no need to store them page-wise
  $self->_page_cache( {} );
  $self->_page_cache->{0}->{0} = \@entries;

  # Return the number of hits
  return $self->total_entries;
}




sub page {
  ( my $self, my $offset, my $limit ) = @_;

  # Get the content of the page via cache
  my @content;
  if ( $self->_page_cache->{0}->{0} ) {
    @content = @{ $self->_page_cache->{0}->{0} };
  }

  my $page = [];
  my $max = ( $#content < $offset + $limit - 1 ) ? $#content : $offset + $limit - 1;
  foreach my $i ( $offset .. $max ) {
    my $entry = $content[$i];

    # Title and abstract are easy, they are regular elements
    my $title    = join( ' ', @{ $entry->{title} } );
    my $abstract = join( ' ', @{ $entry->{summary} } );

    # Now we add the authors
    my @authors = ();

    foreach my $author ( @{ $entry->{author} } ) {

      print STDERR Dumper($author->{name}), "\n";

      Paperpile::Library::Author->new();

      push @authors, Paperpile::Library::Author->new()->parse_freestyle($author->{name}->[0])->bibtex();


    #  my @tmp_names = split( / /, join( ' ', @{ $author->{name} } ) );
    #  my $first     = '';
    #  my $last      = '';
    #  if ( $#tmp_names == 1 ) {
    #    $first = $tmp_names[0];
    #    $last  = $tmp_names[1];
    #  }
    #  if ( $#tmp_names == 2 ) {
    #    $first = $tmp_names[0] . ' ' . $tmp_names[1];
    #    $last  = $tmp_names[2];
    #  }

    #  push @authors,
    #    Paperpile::Library::Author->new(
    #    last  => $last,
    #    first => $first,
    #    jr    => ''
    #    )->normalized;
    }

    # If there is a journal reference, we can parse it and
    # fill the following fields

    my $journal = '';
    my $year    = '';
    my $volume  = '';
    my $issue   = '';
    my $pages   = '';
    my $comment = '';
    my $pubtype = 'MISC';
    if ( $entry->{'arxiv:journal_ref'} ) {
      my $journal_line = @{ $entry->{'arxiv:journal_ref'} }[0]->{content};
      $journal_line =~ s/\n//g;
      $journal_line =~ s/\s+/ /g;
      ( $journal, $year, $volume, $issue, $pages, $comment ) = parseJournalLine($journal_line);
      $pubtype = 'ARTICLE' if ( $journal ne '' );

      # NOTE: if there is something in comment and journal is empty
      # then we were not able to parse the journal string correctly
    }

    # get id
    my $id = join( ' ', @{ $entry->{id} } );
    ( my $pdf = $id ) =~ s/\/abs\//\/pdf\//;

    my $pub = Paperpile::Library::Publication->new( pubtype => $pubtype );

    #$pub->howpublished($id);
    $pub->url($id);

    #$pub->pdf_url($pdf);
    $pub->linkout($pdf);
    $pub->title($title)       if $title;
    $pub->abstract($abstract) if $abstract;
    $pub->authors( join( ' and ', @authors ) );
    $pub->volume($volume)   if ( $volume  ne '' );
    $pub->issue($issue)     if ( $issue   ne '' );
    $pub->year($year)       if ( $year    ne '' );
    $pub->pages($pages)     if ( $pages   ne '' );
    $pub->journal($journal) if ( $journal ne '' );
    $pub->journal($comment) if ( $journal eq '' and $comment ne '' );

    $pub->refresh_fields;
    push @$page, $pub;
  }

  # we should always call this function to make the results available
  # afterwards via find_sha1
  $self->_save_page_to_hash($page);


  #print STDERR Dumper($page);

  return $page;

}

sub parseJournalLine
{
    my $line = $_[0];
    my $backup = $line;
    my $journal = '';
    my $year = '';
    my $volume = '';
    my $issue = '';
    my $pages = '';
    my $strange = '';
    my $comment = '';

    my $debug = 0;

    # some preprocessing
    $line =~ s/-+/-/g;
    $line =~ s/\s-\s/-/g;
    $line =~ s/\s-/-/g;
    $line =~ s/~/-/g;
    $line =~ s/\.$//;
    $line =~ s/\./. /g;
    $line =~ s/:/ /g;
    $line =~ s/,/ /g;
    $line =~ s/;/ /g;
    $line =~ s/\(/ (/g;
    $line =~ s/\)/) /g;

    # sometime there is TeX in it
    $line =~ s/\\bf//g;
    $line =~ s/{//g;
    $line =~ s/}//g;

    $line =~ s/\s+/ /g;

    # get rid of month/date stuff
    $line =~ s/(.*)(\d{0,2}\s?(january|february|march|mar\.|april|may|june|july|august|Aug\.|september|october|Oct\.|november|Nov\.|december|Dec\.))\s((19|20)\d\d)(.*)/$1$4$6/gi;
    $line =~ s/(.*)((january|february|march|mar\.|april|may|june|july|august|Aug\.|september|october|Oct\.|november|Nov\.|december|Dec\.)\s\d{0,2}\s?)((19|20)\d\d)(.*)/$1$4$6/gi;

    # get rid of some pages stuff
    $line =~ s/(.*)(\(\d+\spages\))(.*)/$1$3/;
    
    $line .= ' ';

    # sometime there is no space between a word and the number (eg. journal and volume)
    my @tmp = split(//, $line);
    for my $i (0 .. $#tmp-1)
    {
	$tmp[$i] = $tmp[$i].' ' if ($tmp[$i] =~ m/[A-Z]/i and $tmp[$i+1] =~ m/[1-9]/);
    }
    $line = join('', @tmp);

    print "   PREPROC: $line\n" if ($debug == 1);

    # first we use regular expressions to parse things that are obvious

    # ======================= PAGES ===========================
    # so far I have seen pages like the following:
    # 1) pages ???-???
    # 2) pp. ???-???
    # 2a) pp. ????~???
    # 3) p. ???-???
    # 4) p ???-???

    if ($line =~ m/((pp\.?|p\.?|pages)\s?\d+-\d+)\D*/)
    {
	$pages = $1;
	$line =~ s/$pages//;
	print "   MODIFIED: $line\n" if ($debug == 1);
	$pages =~ s/(.*\D)(\d+-\d+)/$2/;
    }

    # 4) ???-???
    # 4a) S???-????
    # 4b) R???-????
    if ($line =~ m/\s((R|S)*\s*\d+-\d+)\D/ and $pages eq '')
    {
	$pages = $1;
	$line =~ s/$pages\s//;
	$pages =~ s/[^\d|-]//g;
	print "   MODIFIED: $line\n" if ($debug == 1);
    }

    # 5) R ???-R ???
    # 6) S ???-S ???
    # 6a) L ???-L ???
    if ($line =~ m/\s((R|S|L)\s\d+-(R|S|L)\s\d+)\s/ and $pages eq '')
    {
	$pages = $1;
	$line =~ s/$pages\s//;
	$pages =~ s/[^\d|-]//g;
	print "   MODIFIED: $line\n" if ($debug == 1);	
    }

    # 7) S ???
    # 8) R ???
    # 9) L ???
    if ($line =~ m/\s((R|S|L)\s\d+)\s/ and $pages eq '')
    {
	$pages = $1;
	$line =~ s/$pages\s//;
	$pages =~ s/[^\d|-]//g;
	print "   MODIFIED: $line\n" if ($debug == 1);	
    }

    # ======================= VOLUME ===========================
    # 1) Vol. ??
    # 2) vol. ??
    # 3) Volume ??
    # 4) v. ??
    # 5) v ??

    if ($line =~ m/\s((Vol\.?|Volume|v\.?)\s\d+)\D*/i)
    {
	$volume = $1;
	$line =~ s/$volume//;
	$volume =~ s/\D//g;
	print "   MODIFIED: $line\n" if ($debug == 1);
    }

    # ======================= ISSUE ===========================
    # 1) Number ??
    # 2) No. ??\w
    # 2) No ??
    # 3) N ??
    # 4) n. ??
    # 5) Issue ??

    if ($line =~ m/\s((No\.?|number|N|n\.|Issue)\s\d+[A-Za-z]?)\D*/i)
    {
	$issue = $1;
	$line =~ s/$issue//;
	$issue =~ s/\D//g;
	print "   MODIFIED: $line\n" if ($debug == 1);
    }

    # 6) (?)
    if ($line =~ m/\s(\(\d\d?\))\s/i and $issue eq '')
    {
	$issue = $1;
	$line =~ s/\($issue\)//;
	$issue =~ s/\D//g;
	print "   MODIFIED: $line\n" if ($debug == 1);
    }
    # 7) (?-?)
    # 8) (?/?)
    if ($line =~ m/\s(\(\d+-\d+\))\s/i and $issue eq '')
    {
	$issue = $1;
	$line =~ s/\($issue\)//;
	$issue =~ s/(.*)(\d+-\d+)(.*)/$2/g;
	print "   MODIFIED: $line\n" if ($debug == 1);
    }
    if ($line =~ m/\s(\(\d+\/\d+\))\s/i and $issue eq '')
    {
	$issue = $1;
	$line =~ s/\($issue\)//;
	$issue =~ s/(.*)(\d+\/\d+)(.*)/$2/g;
	print "   MODIFIED: $line\n" if ($debug == 1);
    }
    
    

    # ====================== YEAR ==============================
    # 1) (19xx) or (20xx)
    if ($line =~ m/(\((19|20)\d\d\))/i)
    {
	$year = $1;
	$line =~ s/\($year\)//;
	$year =~ s/\D//g;
	print "   MODIFIED: $line\n" if ($debug == 1);	
    }

    # 2) (??/??/19xx) or (??/??/20xx)
    if ($line =~ m/(\(\d\d\/\d\d\/(19|20)\d\d\))/i)
    {
	$year = $1;
	$line =~ s/\($year\)//;
	$year =~ s/(.*)((19|20)\d\d)(\))/$2/g;
	print "   MODIFIED: $line\n" if ($debug == 1);	
    }

    # 3) (?? month 19|20xx)
    #if ($line =~ m/(\(.*(january|february|march|april|may|june|july|august|september|october|november|december)\s(19|20)\d\d\))/i)
    #{
    # 	$year = $1;
    #	$line =~ s/\($year\)//;
    #	$year =~ s/(.*)((19|20)\d\d)(\))/$2/g;
    #	print "   MODIFIED: $line\n" if ($debug == 1);	
    #}

    
    # ====================== STRANGE NUMBERS ===================
    # 1) 0??????? sometime article numnbers
    my @strange_numbers = ();
    my $flag_0 = 1;
    while ($flag_0 == 1)
    {
	$flag_0 = 0;
	if ($line =~ m/\s([A-Z]?0\d+)\s/)
	{
	    $strange = $1;
	    push @strange_numbers, $strange;
	    $line =~ s/$strange//;
	    print "   MODIFIED: $line\n" if ($debug == 1);
	    $flag_0 = 1;
	}
    }

    # ====================== JOURNAL NAME ===================
    # 1) until we see two spaces
    # 2) until we see a number
    
    if ($line =~ m/(^[A-Z|\s|\.|&]+)\s\s/i)
    {
	$journal = $1;
	$line =~ s/$journal//;
	print "   MODIFIED: $line\n" if ($debug == 1);	
    }
    
    if ($line =~ m/(^[A-Z|\s|\.|&]+)\s\d/i and $journal eq '')
    {
	$journal = $1;
	$line =~ s/$journal//;
	print "   MODIFIED: $line\n" if ($debug == 1);	
    }
    

    # ====================== VOLUME AGAIN ===================
    # next number

    if ($line =~ m/(^\s*\d+[A-Z]?)\s/i and $volume eq '')
    {
	my $tmp1 = $1;
	if ($tmp1 =~ m/^\d+$/)
	{
	    if ($tmp1 < 5000)
	    {
		$volume = $tmp1;
		$line =~ s/$volume//;
		print "   MODIFIED: $line\n" if ($debug == 1);
	    }
	}
	else
	{
	    $volume = $tmp1;
	    $line =~ s/$volume//;
	    print "   MODIFIED: $line\n" if ($debug == 1);
	}
    }

    # ====================== VOLUME/ISSUE ===================
    if ($line =~ m/(^\s*\d+\/\d+)\s/i and $volume eq '' and $issue eq '')
    {
	my $tmp0 = $1;
	($volume, $issue) = split(/\//, $tmp0);
	$line =~ s/$tmp0//;
	print "   MODIFIED: $line\n" if ($debug == 1);
    }

    # ================ STILL SOMETHING LEFT? =================
    if ($line =~ m/(^\s*\d+)\s/)
    {
	my $tmp1 = $1;
	my $flag = 0;
	if ($tmp1 < 10 and $issue eq '' and $pages ne '')
	{
	    $issue = $tmp1;
	    $line =~ s/$issue//;
	    print "   MODIFIED: $line\n" if ($debug == 1);
	    $flag = 1;
	}
	if ($tmp1 < 10000 and $pages eq '' and $flag == 0)
	{
	    $pages = $tmp1;
	    $line =~ s/$pages//;
	    print "   MODIFIED: $line\n" if ($debug == 1);
	}
    }

    # ================ STILL YEAR LEFT? =================
    if ($line =~ m/(^\s*\d+)\s/)
    {
	my $tmp1 = $1;
	my $flag = 0;
	if ($tmp1 >= 1900 and $tmp1 <= 2099 and $year eq '')
	{
	    $year = $tmp1;
	    $line =~ s/$year//;
	    print "   MODIFIED: $line\n" if ($debug == 1);
	}
	else
	{
	    # we just remove it
	    $line =~ s/$tmp1//;
	    push @strange_numbers, $tmp1;
	    print "   MODIFIED: $line\n" if ($debug == 1);

	}
    }

    # some postprocessing and control
    $journal =~ s/\s+/ /g;
    $journal =~ s/\s$//;
    $volume =~ s/\s//g;
    $pages =~ s/\s//g;
    $year =~ s/\s//g;
    $issue =~ s/\s//g;
    $line =~ s/\s+/ /g;
    $comment .= join(" ", @strange_numbers) if ($#strange_numbers > -1);
    my $length = length($line);
    # if there is something left
    if (length($line) > 1)
    {
	# looks fine, the rest is set as comment
	my $flag_1 = 0;
	if ($journal ne '' and $year ne '' and $pages ne '' and $volume ne '')
	{
	    $comment .= " $line";
	    $flag_1 = 1;
	}
	if ($journal ne '' and $year ne '' and $volume ne '' and length($line) < 10)
	{
	    $comment .= " $line";
	    $flag_1 = 1;
	}
	if ($flag_1 == 0)
	{
	    $journal = '';
	    $year = '';
	    $volume = '';
	    $issue = '';
	    $pages = '';
	    $comment = $backup;
	}
    }
    
    return ($journal, $year, $volume, $issue, $pages, $comment);
}





1;
