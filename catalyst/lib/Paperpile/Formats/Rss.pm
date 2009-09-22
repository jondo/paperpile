package Paperpile::Formats::Rss;
use Moose;
use XML::Simple;

extends 'Paperpile::Formats';

sub BUILD {
  my $self = shift;
  $self->format('RSS');
  $self->readable(1);
  $self->writable(0);
}


sub read {

    my $self = shift;

    my @output = ();
    
    # read in XML
    my $result = XMLin($self->file, ForceArray => 1);

    # get the list of items
    my @entries = @{$result->{item}};
    foreach my $entry (@entries)
    {
	my $title;
	my $authors;
	my $journal;
	my $volume;
	my $issue;
	my $pages;
	my $year;
	my $doi;
	my $description;
	my $link;
	
	if ( $entry->{'dc:title'} ) {
	    $title = join( '',@{$entry->{'dc:title'}} );
	}
	
	if ( $entry->{'dc:creator'} ) {
	    $authors = join( ', ',@{$entry->{'dc:creator'}} );
	}
	
	if ( $entry->{'prism:publicationName'} ) {
	    $journal = join( '',@{$entry->{'prism:publicationName'}} );
	}
	
	if ( $entry->{'prism:volume'} ) {
	    $volume = join( '',@{$entry->{'prism:volume'}} );
	}
	
	if ( $entry->{'prism:number'} ) {
	    $issue = join( '',@{$entry->{'prism:number'}} );
	}
	
	if ( $entry->{'prism:startingPage'} and $entry->{'prism:endingPage'} ) {
	    $pages = join( '',@{$entry->{'prism:startingPage'}} ).' - '.
		join( '',@{$entry->{'prism:endingPage'}} );
	    
	}
	
	if ( $entry->{'prism:doi'} ) {
	    $doi = join( '',@{$entry->{'prism:doi'}} );
	}
	
	if ( $entry->{'description'} ) {
	    $description = join( '',@{$entry->{'description'}} );
	}
	
	if ( $entry->{'link'} ) {
	    $link = join( '',@{$entry->{'link'}} );
	}
	
	my $pub = Paperpile::Library::Publication->new( pubtype => 'ARTICLE' );
	
	$pub->title( $title )   if ( $title );
	$pub->authors ( 'Gruber AR' );
	$pub->volume($volume)   if ( $volume );
	$pub->issue($issue)     if ( $issue  );
	$pub->year($year)       if ( $year );
	$pub->pages($pages)     if ( $pages );
	$pub->journal($journal) if ( $journal );

	push @output, $pub;

	#print STDERR "$title\n";

    }



    return [@output];

}

sub write{



}



1;



