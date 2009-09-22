package Paperpile::Formats::Rss;
use Moose;
use XML::Simple;
use HTML::TreeBuilder::XPath;

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

    # let's first screen the channel tag
    my $channel_journal_name;
    if ( $result->{ channel }->[0]->{ 'prism:publicationName' } ) {
	$channel_journal_name = join( '', @{ $result->{ channel }->[0]->{ 'prism:publicationName' } } );
    }

    my $channel_title;
    if ( $result->{ channel }->[0]->{ 'title' } ) {
	$channel_title = join( '', @{ $result->{ channel }->[0]->{ 'title' } } );
    }
    
    my $issn;
    if ( $result->{ channel }->[0]->{ 'prism:issn' } ) {
	$issn = join( '', @{ $result->{ channel }->[0]->{ 'prism:issn' } } );
    }


    # get the list of items
    my @entries;
    
    if ( $result->{ item } ) {
	@entries = @{ $result->{ item } };
    }

    # Some publishers do not use standarized formats (e.g. Springer)
    # so we need some special handling
    if (!@entries) {
	
	# let's see why the regular way did not work
	my $channel_title = join( '', @{ $result->{ channel }->[0]->{ 'title' } } );
	my $channel_link = join( '', @{ $result->{ channel }->[0]->{ 'link' } } );

	# ScienceDirect 
	if ( $channel_title =~ m/ScienceDirect/ ) {
	    @entries = @{ $result->{ channel }->[0]->{ item } };
	    return $self->_parse_ScienceDirect( \@entries );
	} 
	
	# SpringerLink
	if ( $channel_link =~ m/springerlink/ ) {
	    @entries = @{ $result->{ channel }->[0]->{ item } };
	    return $self->_parse_SpringerLink( \@entries );
	} 

	# let's try it again the regular way
	@entries = @{ $result->{ channel }->[0]->{ item } };
	return $self->_parse_RegularFeed( \@entries, $channel_journal_name,
					  $channel_title, $issn );

    } else {

	# if we are here then we have a regular RSS feed
	return $self->_parse_RegularFeed( \@entries, $channel_journal_name,
					  $channel_title, $issn );
    }

}


sub _parse_RegularFeed {

    my $self = shift;
    my @entries = @{ $_[0] };
    my $channel_journal_name = $_[1];
    my $channel_title = $_[2];
    my $issn = $_[3];

    my @output = ();
    foreach my $entry (@entries)
    {
	my $title;
	my $authors;
	my $journal;
	my $volume;
	my $issue;
	my $pages;
	my $year;
	my $month;
	my $doi;
	my $description;
	my $link;

	# parsing of the title; let's try first if there is a regular
	# title tag and if not if there is a dublin core title
	if ( $entry->{ 'title' } ) {
	    $title = join( '',@{$entry->{ 'title' } } );
	}
		
	if ( $entry->{ 'dc:title' } and !$title) {
	    $title = join( '',@{$entry->{ 'dc:title' } } );
	    if ( $title =~ m/(.*)(\s\[[A-Z]+\]$)/ ) {
		$title = $1;
	    }
	}

	print STDERR "$title\n";

       	    
	# although the element dc:creator can be used (and should be used) for 
	# more than once if there are multiple authors, some publishers just 
	# put all the names in one field. This makes it necessary to do some parsing.
	if ( $entry->{'dc:creator'} ) {
	    my @authors = ( );
	    my @authors_tmp = @{$entry->{'dc:creator'}};

	    if ( $authors_tmp[0] =~ m/^HASH\(/ ) {
		$authors = 'Unknown';
	    } 

	    if ($#authors_tmp == 0 and !$authors) {
		# first we check if there is really just one author
		my $nr_separators = 0;

		$nr_separators += ($authors_tmp[0] =~ tr/,//);
		if ( $nr_separators == 0 ) {
		    $authors = Paperpile::Library::Author->new()->
			parse_freestyle( $authors_tmp[0] )->bibtex();
		} else {
		    # Strategy 1: works well for Oxford journals
		    my @tmp1 = split(/\., /, $authors_tmp[0]);
		    if ($#tmp1 > 0) {
			$authors = join(" and ", @tmp1 );
		    }

		    # Strategy 2: works well for Blackwell journals
		    @tmp1 = split(/, /, $authors_tmp[0]);
		    if ($#tmp1 > 0 and !$authors) {
			$authors = join(" and ", @tmp1 );
		    }


		    
		}
	    } 
	    if ($#authors_tmp > 0 and !$authors) {
		# it seems that there are multiple fields, so we assume that
		# each field is one author
 
	    	foreach my $author ( @authors_tmp ) {
		    print STDERR "$author\n";

		    # parsing using parse_freestyle seems to give properly formatted
		    # results, but it takes far too long
		    # We just use the unformtted author tags now
		    #push @authors, Paperpile::Library::Author->new()->
		    #	parse_freestyle( $author )->bibtex();
		    push @authors, $author;
		    
		}

		$authors = join( ' and ', @authors );
	    }
	}

	# observed for IEEE journals
	if ( $entry->{'authors'} ) {
	    $authors = join( '', @{ $entry->{ 'authors' } } );
	    if ( $authors =~ m/;/ ) {
		my @tmp = split( /;/, $authors );
		pop ( @tmp ) if ( $tmp[$#tmp] eq '' );
		$authors = join ( " and ", @tmp );
	    }
	    $authors = 'Unknown' if ( $authors =~ m/^HASH\(/ );
	}

	# observed for Emerald journals
	if ( $entry->{'author'} ) {
	    $authors = join( '', @{ $entry->{ 'author' } } );
	    $authors =~ s/,\s/ and /g;
	}
	
	# now we parse other bibliographic data
	
	if ( $entry->{ 'prism:publicationName' } ) {
	    $journal = join( '',@{$entry->{ 'prism:publicationName' }} );
	}
	
	# volume
	if ( $entry->{ 'prism:volume' } ) {
	    $volume = join( '', @{ $entry->{ 'prism:volume' } } );
	}

	if ( $entry->{ 'volume' } and !$volume) {
	    $volume = join( '', @{ $entry->{ 'volume' } } );
	}	
	
	# issue
	if ( $entry->{ 'prism:number' } ) {
	    $issue = join( '', @{ $entry->{'prism:number'} } );
	}

	if ( $entry->{ 'issue' } and !$issue) {
	    $issue = join( '', @{ $entry->{'issue'} } );
	}
	
	# page numbers 
	if ( $entry->{ 'prism:startingPage' } and $entry->{ 'prism:endingPage' } ) {
	    $pages = join( '', @{ $entry->{ 'prism:startingPage' } } ) . '-' .
		join( '',@{ $entry->{ 'prism:endingPage' } } );
	}
	if ( $entry->{ 'prism:startingPage' } and !$pages ) {
	    $pages = join( '', @{ $entry->{ 'prism:startingPage' } } );
	}

	if ( $entry->{ 'startPage' } and $entry->{ 'endPage' } and !$pages ) {
	    $pages = join( '', @{ $entry->{ 'startPage' } } ).'-'.
		join( '',@{ $entry->{ 'endPage' } } );
	}

	# DOI is interesting. There can be multiple entries.
	if ( $entry->{ 'prism:doi' } ) {
	    $doi = join( '', @{ $entry->{ 'prism:doi' } } );
	}

	if ( $entry->{ 'dc:identifier' } ) {
	    my $tmp = join( '', @{ $entry->{ 'dc:identifier' } } );
	    if ( $tmp =~ m/doi/ ) {
		$tmp =~ s/(.*doi:?\/?)(\d\d\.\d\d\d.*)/$2/;
		if ( !$doi ) {
		    $doi = $tmp;
		}
	    }
	    if ( $tmp =~ m/^\d\d\.\d\d\d/ and !$doi ) {
		    $doi = $tmp;
	    }
	}

	# year
	if ( $entry->{ 'dc:date' } ) {
	    my $tmp = join( '', @{ $entry->{ 'dc:date' } } );
	    if ( $tmp =~ m/^(\d\d\d\d)-(\d\d)-\d\d/ ) {
		$year = $1;
	    }
	    if ( $tmp =~ m/\s(\d\d\d\d)$/ and !$year ) {
		$year = $1;
	    }
	}

	if ( $entry->{ 'pubDate' } and !$year ) {
	    my $tmp = join( '', @{ $entry->{ 'pubDate' } } );
	    if ( $tmp =~ m/^[A-Z]+\s+(\d\d\d\d)$/i ) {
		$year = $1;
	    }
	    if ( $tmp =~ m/\d{1,2}\s+[A-Z]{3}\s+(\d\d\d\d)/i ) {
		$year = $1;
	    }
	}
	
	if ( $entry->{ 'description' } ) {
	    $description = join( '', @{ $entry->{ 'description' } } );
	    $description = 'Not available' if ( $description =~ m/^HASH\(/ );
	}
	
	if ( $entry->{ 'link' } ) {
	    $link = join( '', @{ $entry->{ 'link' } } );
	}

	if ( $channel_journal_name and !$journal ) {
	    $journal = $channel_journal_name;
	}

	if ( $channel_title and !$journal ) {
	    $journal = $channel_title;
	}

	if ( !$description ) {
	    $description = 'Not available';
	}
	
	my $pub = Paperpile::Library::Publication->new( pubtype => 'ARTICLE' );
	
	$pub->title( $title )          if ( $title );
	$pub->authors ( $authors )     if ( $authors );
	$pub->volume( $volume )        if ( $volume );
	$pub->issue( $issue )          if ( $issue  );
	$pub->year( $year )            if ( $year );
	$pub->pages( $pages )          if ( $pages );
	$pub->journal( $journal )      if ( $journal );
	$pub->abstract( $description ) if ( $description );
	$pub->doi ( $doi )             if ( $doi );
	$pub->linkout ( $link )        if ( $link );
	$pub->issn ( $issn )           if ( $issn );
	$pub->year ( $year )           if ( $year );
	#$pub->month ( $month )         if ( $month );

	push @output, $pub;

	#print STDERR "$title\n";

    }

    return [@output];
}

sub _parse_SpringerLink {
    my $self = shift;
    my @entries = @{ $_[0] };

    my @output = ();

    foreach my $entry ( @entries )
    {
	my $title;
	my $authors;
	my $description;
	my $doi;
	my $journal;
	my $volume;
	my $issue;
	my $year;
	my $link;
	
	if ( $entry->{ 'title' } ) {
	    $title = join( '',@{ $entry->{ 'title' } } );
	}
	
	
	if ( $entry->{ 'description' } ) {
	    
	    # now we have HTML markup that we can parse with XPath
	    my $html = join( '', @{ $entry->{ 'description' } } );
	    $html =~ s/([^[:ascii:]])/sprintf("&#%d;",ord($1))/eg;
	    $html = '<html><body>'.$html.'</html>/<body>';
	    
	    my $tree = HTML::TreeBuilder::XPath->new;
	    $tree->utf8_mode(1);
	    $tree->parse_content($html);
	    
	    # abstract
	    my @tmp = $tree->findnodes('/html/body/p');
	    $description = $tmp[0]->as_text();
	    $description =~ s/Abstract\s//;
	    
	    # authors
	    @tmp = $tree->findnodes('/html/body/ul/li/ul/li');
	    my @authors = ( );
	    foreach my $line (@tmp) {
		my @temp = split( /,/, $line->as_text() );
		push @authors, $temp[0];
		
	    }
	    $authors = join( ' and ', @authors );
	    
	    # doi
	    @tmp = $tree->findnodes('/html/body/ul/li');
	    foreach my $line (@tmp) {
		my $tmp = $line->as_text();
		if ($tmp =~ m/(DOI.*)(\d\d\.\d\d\d\d.*)/i) {
		    $doi = $2;
		}
	    }
	    
	    # more bibliographic data
	    @tmp = $tree->findnodes('/html/body/ul/ul/li');
	    foreach my $line (@tmp) {
		my $tmp = $line->as_text();
		if ($tmp =~ m/Journal/ and $tmp !~ m/Volume/) {
		    ($journal = $tmp) =~ s/Journal\s//;
		}
		if ($tmp =~ m/Volume\s(\d+)/) {
		    $volume = $1;
		}	
		if ($tmp =~ m/Number\s(\d+)/) {
		    $issue = $1;
		}
		if ($tmp =~ m/,\s(\d\d\d\d)$/) {
		    $year = $1;
		}	
	    }
	}

	if ( $entry->{ 'link' } ) {
	    $link = join( '', @{ $entry->{ 'link' } } );
	}

	if ( $entry->{ 'pubDate' } and !$year) {
	    my $tmp = join( '', @{ $entry->{ 'pubDate' } } );
	    if ( $tmp =~ m/\d+\s[A-Z]{3}\s(\d\d\d\d)/i ) {
		$year = $1;
	    }
	}
	
	my $pub = Paperpile::Library::Publication->new( pubtype => 'ARTICLE' );
	
	$pub->title( $title )              if ( $title );
	$pub->authors ( $authors )         if ( $authors );
	$pub->abstract ( $description )    if ( $description );
	$pub->doi ( $doi )                 if ( $doi );
	$pub->journal( $journal )          if ( $journal );
	$pub->volume( $volume )            if ( $volume );
	$pub->issue( $issue )              if ( $issue );
	$pub->year( $year )                if ( $year );
	$pub->linkout( $link )             if ( $link );
	push @output, $pub;
    }
    
    return [@output];
}

sub _parse_ScienceDirect {

    my $self = shift;
    my @entries = @{ $_[0] };

    my @output = ();

    foreach my $entry ( @entries )
    {
	my $title;
	my $authors;
	my $description;
	my $doi;
	my $journal;
	my $volume;
	my $issue;
	my $year;
	my $link;
	my $pages;
	my $note;

	if ( $entry->{ 'title' } ) {
	    $title = join( '', @{ $entry->{ 'title' } } );
	}

	if ( $entry->{ 'link' } ) {
	    $link = join( '', @{ $entry->{ 'link' } } );
	}

	if ( $entry->{ 'description' } ) {
	    my @tmp = split(/<br>/, join( '', @{ $entry->{ 'description' } } ) );
	    
	    
	    # 0 .. usually the year
	    if ( $tmp[0] =~ m/Publication\syear:\s(\d\d\d\d)/ ) {
		$year = $1;
	    }

	    # 1 .. usually journal and other bibliographic stuff
	    my @tmp2 = split( /,/, $tmp[1] );
	    if ( $tmp2[0] =~ m/<b>Source:<\/b>\s(.*)/ ) {
		$journal = $1;
	    }

	    if ( $tmp[1] =~ m/Volume\s(\d+)/ ) {
		$volume = $1;
	    }

	    if ( $tmp[1] =~ m/Issue\s(\d+)/ ) {
		$issue = $1;
	    }

	    if ( $tmp[1] =~ m/Pages\s(\d+-\d+)/ ) {
		$pages = $1;
	    }

	    if ( $tmp[1] =~ m/In\sPress/ and !$volume ) {
		$volume = "In Press";
	    }
	    
	    # 2 .. usually author line ( sometimes incomplete ends with ,... )
	    if ( $tmp[2] !~ m/No\sauthor\sname\savailable/ ) {
		my $etal = '';
		if ($tmp[2] =~ m/(.*)(\s,\s\.\.\.)$/ ) {
		    $tmp[2] = $1;
		    $etal = "et al.";
		}
		my @tmp3 = split(/ , /, $tmp[2]);
		my @authors = ( );
		foreach my $author (@tmp3) {
		    if ( $author =~ m/(.+)(,\s)(.+)/ ) {
			push @authors, "$3,$1";
		    }
		}
		push @authors, $etal if ($etal ne '');

		$authors = join( ' and ', @authors);
	    }
	    
	    # the rest we put into the abstract field
	    foreach my $i (3 .. $#tmp){
		$description .= " $tmp[$i]" if ( $tmp[$i] );
	    }
		

	}

	my $pub = Paperpile::Library::Publication->new( pubtype => 'ARTICLE' );

	$pub->title( $title )              if ( $title );
	$pub->authors ( $authors )         if ( $authors );
	$pub->abstract ( $description )    if ( $description );
	$pub->doi ( $doi )                 if ( $doi );
	$pub->journal( $journal )          if ( $journal );
	$pub->volume( $volume )            if ( $volume );
	$pub->issue( $issue )              if ( $issue );
	$pub->year( $year )                if ( $year );
	$pub->pages( $pages )              if ( $pages );
	$pub->linkout( $link )             if ( $link );
	push @output, $pub;
    }
    
    return [@output];
}




sub write{



}



1;



