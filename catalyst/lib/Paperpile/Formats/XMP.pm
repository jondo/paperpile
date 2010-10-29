# Copyright 2009, 2010 Paperpile
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


package Paperpile::Formats::XMP;
use Moose;
use XML::Simple;
use Data::Dumper;
use Paperpile::Library::Publication;
use Paperpile::Library::Author;

extends 'Paperpile::Formats';

has 'content' => ( is => 'rw', isa => 'Str', default => '' );

sub BUILD {
  my $self = shift;
  $self->format('XMP');
  $self->readable(1);
  $self->writable(0);
}

sub read {

  my $self = shift;

  if ( $self->file and !$self->content ) {
    open( FILE, $self->file );
    my ( $buf, $data, $n );
    my $last_entry = '';
    my $buffer     = '';
    my $flag       = 0;
    while ( ( $n = read FILE, $data, 16 ) != 0 ) {

      #print "$n bytes read $data\n";
      my $tmp = $last_entry . $data;
      if ( $tmp =~ m/(.*<?xpacket end=[^>]*>).*/ ) {
        if ( $data =~ m/([^>]*>).*/ ) {
          $buffer .= $1;
        }
        last;
      }
      if ( $flag == 1 ) {
        $buffer .= $data;
      }
      if ( $tmp =~ m/.*(<\?xpacket begin=.*)/ ) {
        $buffer = $1;
        $flag   = 1;
      }

      $last_entry = $data;
    }
    close(FILE);
    $self->content($buffer);
  }

  my $xmp = $self->content;

  my $pub = Paperpile::Library::Publication->new( pubtype => 'ARTICLE' );

  return $pub if ( !$xmp );
  return $pub if ( $xmp eq '' );
  return $pub if ( $xmp !~ m/^<\?xpacket begin=/ );

  my (
    $title,   $authors,    $journal,  $issue,     $volume,    $year, $month,
    $ISSN,    $pages,      $doi,      $abstract,  $booktitle, $url,  $pmid,
    $arxivid, $start_page, $end_page, $publisher, $dummy,     $keywords
  );

  my $xml  = new XML::Simple;
  my $data = undef;
  eval { $data = $xml->XMLin( $xmp, ForceArray => 1 ) };
  return $pub if ( !$data );

  # parse as seen for NPG PDFs
  my $tmp0 = $data->{'rdf:RDF'}->[0]->{'rdf:Description'};
  return $pub if ( !$tmp0 );

  my $tmp1 = ( $tmp0 =~ m/^ARRAY/ ) ? $tmp0 : [];
  foreach my $entry ( @{$tmp1} ) {
    foreach my $key ( keys %{$entry} ) {

      #print $key, " =================================\n";
      #print Dumper( $entry->{$key} );

      # PRISM
      if ( lc($key) eq 'prism:number' ) {
        next if ( $entry->{$key} =~ m/^HASH/ );
        if ( $entry->{$key} =~ m/^ARRAY/ ) {
          next if ( $entry->{$key}->[0] =~ m/^ARRAY/ );
          next if ( $entry->{$key}->[0] =~ m/^HASH/ );
          $issue = $entry->{$key}->[0];
        } else {
          $issue = $entry->{$key};
        }
      }
      if ( lc($key) eq 'prism:volume' ) {
        next if ( $entry->{$key} =~ m/^HASH/ );
        if ( $entry->{$key} =~ m/^ARRAY/ ) {
          next if ( $entry->{$key}->[0] =~ m/^ARRAY/ );
          next if ( $entry->{$key}->[0] =~ m/^HASH/ );
          $volume = $entry->{$key}->[0];
        } else {
          $volume = $entry->{$key};
        }
      }
      if ( lc($key) eq 'prism:startingpage' ) {
        next if ( $entry->{$key} =~ m/^HASH/ );
        if ( $entry->{$key} =~ m/^ARRAY/ ) {
          next if ( $entry->{$key}->[0] =~ m/^ARRAY/ );
          next if ( $entry->{$key}->[0] =~ m/^HASH/ );
          $start_page = $entry->{$key}->[0];
        } else {
          $start_page = $entry->{$key};
        }
      }
      if ( lc($key) eq 'prism:endingpage' ) {
        next if ( $entry->{$key} =~ m/^HASH/ );
        if ( $entry->{$key} =~ m/^ARRAY/ ) {
          next if ( $entry->{$key}->[0] =~ m/^ARRAY/ );
          next if ( $entry->{$key}->[0] =~ m/^HASH/ );
          $end_page = $entry->{$key}->[0];
        } else {
          $end_page = $entry->{$key};
        }
      }
      if ( lc($key) eq 'prism:doi' ) {
        next if ( $entry->{$key} =~ m/^HASH/ );
        if ( $entry->{$key} =~ m/^ARRAY/ ) {
          next if ( $entry->{$key}->[0] =~ m/^ARRAY/ );
          next if ( $entry->{$key}->[0] =~ m/^HASH/ );
          $doi = $entry->{$key}->[0];
        } else {
          $doi = $entry->{$key};
        }
      }
      if ( lc($key) eq 'prism:issn' ) {
        next if ( $entry->{$key} =~ m/^HASH/ );
        if ( $entry->{$key} =~ m/^ARRAY/ ) {
          next if ( $entry->{$key}->[0] =~ m/^ARRAY/ );
          next if ( $entry->{$key}->[0] =~ m/^HASH/ );
          $ISSN = $entry->{$key}->[0];
        } else {
          $ISSN = $entry->{$key};
        }
      }
      if ( lc($key) eq 'prism:publicationdate' ) {
        my $ref = $entry->{$key}->[0]->{'rdf:Bag'}->[0]->{'rdf:li'};
        next if ( !$ref );
        next if ( $ref !~ m/^ARRAY/ );
        if ( $ref->[0] =~ m/(\d{4})-\d\d-\d\d/ ) {
          $year = $1;
        }
        if ( $ref->[0] =~ m/^(\d{4})$/ ) {
          $year = $1;
        }
      }

      # Dublin Core
      if ( lc($key) eq 'dc:creator' ) {
	next if ( $entry->{$key} !~ m/^ARRAY/ );
	next if ( $entry->{$key}->[0] !~ m/^HASH/ );
        my $ref = $entry->{$key}->[0]->{'rdf:Seq'}->[0]->{'rdf:li'};
        if ($ref) {
          next if ( $ref !~ m/^ARRAY/ );
          my @creators = ();
          foreach my $creator ( @{$ref} ) {
            next if ( $creator =~ m/^ARRAY/ );
            next if ( $creator =~ m/^HASH/ );
	    next if ( $creator !~ m/[a-z]/i );
	    if ( $creator =~ m/et\sal\.$/ ) {
	      @creators = ();
	      last;
	    }
            push @creators, Paperpile::Library::Author->new()->parse_freestyle($creator)->bibtex();
          }
          $authors = join( " and ", @creators );
        }
      }

      if ( lc($key) eq 'dc:title' ) {
        my $ref = $entry->{$key}->[0]->{'rdf:Alt'}->[0]->{'rdf:li'};
        next if ( !$ref );
        next if ( $ref !~ m/^ARRAY/ );
        $title = $ref->[0]->{'content'} if ( $ref->[0]->{'content'} );
      }

      if ( lc($key) eq 'dc:identifier' ) {
        my $tmp_doi = '';
        next if ( $entry->{$key} =~ m/^HASH/ );
        if ( $entry->{$key} =~ m/^ARRAY/ ) {
          $tmp_doi = $entry->{$key}->[0];
        } else {
          $tmp_doi = $entry->{$key};
        }

        if ( $tmp_doi =~ m/^doi:(.*)/ and !$doi ) {
          $doi = $1;
        }
        if ( $tmp_doi =~ m/^.*doi\.org\/(10\..*)/ and !$doi ) {
          $doi = $1;
        }
        if ( $tmp_doi =~ m/^(10\..*)/ and !$doi ) {
          $doi = $1;
        }
      }
      if ( lc($key) eq 'dc:publisher' ) {
        my $ref = $entry->{$key}->[0]->{'rdf:Bag'}->[0]->{'rdf:li'};
        $publisher = $ref->[0] if ( $ref->[0] );
      }

      if ( lc($key) eq 'dc:date' ) {
        my $ref = $entry->{$key}->[0]->{'rdf:Seq'}->[0]->{'rdf:li'};
        next if ( !$ref );
        next if ( $ref !~ m/^ARRAY/ );
        if ( $ref->[0] =~ m/(\d{4})-\d\d-\d\d/ ) {
          $year = $1 if ( !$year );
        }
        if ( $ref->[0] =~ m/^(\d{4})$/ ) {
          $year = $1 if ( !$year );
        }
      }
      if ( lc($key) eq 'dc:description' ) {
        my $ref = $entry->{$key}->[0]->{'rdf:Alt'}->[0]->{'rdf:li'};
        next if ( !$ref );
        next if ( $ref !~ m/^ARRAY/ );
        $dummy = $ref->[0]->{'content'} if ( $ref->[0]->{'content'} );
      }

      # BibteXmp used by JabRef

      if ( lc($key) eq 'bibtex:journal' ) {
        next if ( $entry->{$key} =~ m/^HASH/ );
        if ( $entry->{$key} =~ m/^ARRAY/ ) {
          next if ( $entry->{$key}->[0] =~ m/^ARRAY/ );
          next if ( $entry->{$key}->[0] =~ m/^HASH/ );
          $journal = $entry->{$key}->[0];
        } else {
          $journal = $entry->{$key};
        }
      }
      if ( lc($key) eq 'bibtex:volume' ) {
        next if ( $entry->{$key} =~ m/^HASH/ );
        if ( $entry->{$key} =~ m/^ARRAY/ ) {
          next if ( $entry->{$key}->[0] =~ m/^ARRAY/ );
          next if ( $entry->{$key}->[0] =~ m/^HASH/ );
          $volume = $entry->{$key}->[0];
        } else {
          $volume = $entry->{$key};
        }
      }
      if ( lc($key) eq 'bibtex:number' ) {
        next if ( $entry->{$key} =~ m/^HASH/ );
        if ( $entry->{$key} =~ m/^ARRAY/ ) {
          next if ( $entry->{$key}->[0] =~ m/^ARRAY/ );
          next if ( $entry->{$key}->[0] =~ m/^HASH/ );
          $issue = $entry->{$key}->[0];
        } else {
          $issue = $entry->{$key};
        }
      }
      if ( lc($key) eq 'bibtex:pages' ) {
        next if ( $entry->{$key} =~ m/^HASH/ );
        if ( $entry->{$key} =~ m/^ARRAY/ ) {
          next if ( $entry->{$key}->[0] =~ m/^ARRAY/ );
          next if ( $entry->{$key}->[0] =~ m/^HASH/ );
          $pages = $entry->{$key}->[0];
        } else {
          $pages = $entry->{$key};
        }
      }
      if ( lc($key) eq 'bibtex:abstract' ) {
        next if ( $entry->{$key} =~ m/^HASH/ );
        if ( $entry->{$key} =~ m/^ARRAY/ ) {
          next if ( $entry->{$key}->[0] =~ m/^ARRAY/ );
          next if ( $entry->{$key}->[0] =~ m/^HASH/ );
          $abstract = $entry->{$key}->[0];
        } else {
          $abstract = $entry->{$key};
        }
      }
      if ( lc($key) eq 'bibtex:doi' ) {
        next if ( $entry->{$key} =~ m/^HASH/ );
        if ( $entry->{$key} =~ m/^ARRAY/ ) {
          next if ( $entry->{$key}->[0] =~ m/^ARRAY/ );
          next if ( $entry->{$key}->[0] =~ m/^HASH/ );
          $doi = $entry->{$key}->[0] if ( !$doi );
        } else {
          $doi = $entry->{$key} if ( !$doi );
        }
      }
      if ( lc($key) eq 'bibtex:pmid' ) {
        next if ( $entry->{$key} =~ m/^HASH/ );
        if ( $entry->{$key} =~ m/^ARRAY/ ) {
          next if ( $entry->{$key}->[0] =~ m/^ARRAY/ );
          next if ( $entry->{$key}->[0] =~ m/^HASH/ );
          $pmid = $entry->{$key}->[0];
        } else {
          $pmid = $entry->{$key};
        }
      }
      if ( lc($key) eq 'bibtex:year' ) {
        next if ( $entry->{$key} =~ m/^HASH/ );
        if ( $entry->{$key} =~ m/^ARRAY/ ) {
          next if ( $entry->{$key}->[0] =~ m/^ARRAY/ );
          next if ( $entry->{$key}->[0] =~ m/^HASH/ );
          $year = $entry->{$key}->[0];
        } else {
          $year = $entry->{$key};
        }
      }
      if ( lc($key) eq 'bibtex:month' ) {
        next if ( $entry->{$key} =~ m/^HASH/ );
        if ( $entry->{$key} =~ m/^ARRAY/ ) {
          next if ( $entry->{$key}->[0] =~ m/^ARRAY/ );
          next if ( $entry->{$key}->[0] =~ m/^HASH/ );
          $month = $entry->{$key}->[0];
        } else {
          $month = $entry->{$key};
        }
      }
      if ( lc($key) eq 'bibtex:keywords' ) {
        next if ( $entry->{$key} =~ m/^HASH/ );
        if ( $entry->{$key} =~ m/^ARRAY/ ) {
          next if ( $entry->{$key}->[0] =~ m/^ARRAY/ );
          next if ( $entry->{$key}->[0] =~ m/^HASH/ );
          $keywords = $entry->{$key}->[0];
        } else {
          $keywords = $entry->{$key};
        }
      }
      if ( lc($key) eq 'bibtex:url' ) {
        next if ( $entry->{$key} =~ m/^HASH/ );
        if ( $entry->{$key} =~ m/^ARRAY/ ) {
          next if ( $entry->{$key}->[0] =~ m/^ARRAY/ );
          next if ( $entry->{$key}->[0] =~ m/^HASH/ );
          $url = $entry->{$key}->[0];
        } else {
          $url = $entry->{$key};
        }
      }
    }
  }

  if ( $start_page and $end_page ) {
    $pages = "$start_page-$end_page";
  }
  if ( $start_page and !$end_page ) {
    $pages = "$start_page";
  }
  if ($pages) {
    $pages =~ s/-+/-/g;
  }

  if ($volume) {
    if ( $volume =~ m/^\d+$/ ) {
      $volume = undef if ( $volume < 1 );
    }
  }

  if ($issue) {
    if ( $issue =~ m/^\d+$/ ) {
      $issue = undef if ( $issue < 1 );
    }
  }

  # title filtering
  if ($title) {
    if ( $title =~ m/^doi:(.*)/ ) {
      $doi = $1 if ( !$doi );
      $title = undef;
    }
  }
  if ($title) {
    if ( $title =~ m/^.*doi\.org\/(10\..*)/ ) {
      $doi   = $1;
      $title = undef;
    }
  }
  if ($title) {
    if ( $title =~ m/^(10\..*)/ ) {
      $doi   = $1;
      $title = undef;
    }
  }

  if ($title) {
    $title =~ s/\s+/ /g;
    my $title_flag = 0;
    $title_flag = 1 if ( $title =~ m/(\.doc|\.tex|\.dvi|\.ps|\.pdf|\.rtf|\.qxd|\.fm|\.fm\)|\.eps)$/ );
    $title_flag = 1 if ( $title =~ m/^\s*$/ );
    $title_flag = 1 if ( $title =~ m/^Microsoft/ );
    $title_flag = 1 if ( $title =~ m/^gk[a-z]\d+/i );
    $title_flag = 1 if ( $title =~ m/^Title/i );
    $title_flag = 1 if ( $title =~ m/\.\.\.$/ );
    $title_flag = 1 if ( $title =~ m/^LNCS/ );
    
    my $nr_words = ($title =~ tr/ / /);
    $title_flag = 1 if ( $nr_words <= 1 );
    $title = undef if ( $title_flag == 1 );
  }

  if ($authors) {
    my $authors_flag = 0;
    $authors_flag = 1 if ( $authors =~ m/^\d/ );
    $authors_flag = 1 if ( $authors =~ m/^Author/ );
    $authors_flag = 1 if ( $authors =~ m/.*,\s*$/ );
    $authors = undef if ( $authors_flag == 1 );
  }

  # parse journal name from description dummy tag
  # works for XMP from NPG
  if ( $volume and $start_page and !$journal ) {
    if ( $dummy =~ m/^([^\d]+)\s+$volume,\s+$start_page/ ) {
      $journal = $1;
    }
  }

  $pub->journal($journal)     if $journal;
  $pub->volume($volume)       if $volume;
  $pub->issue($issue)         if $issue;
  $pub->year($year)           if $year;
  $pub->month($month)         if $month;
  $pub->pages($pages)         if $pages;
  $pub->abstract($abstract)   if $abstract;
  $pub->title($title)         if $title;
  $pub->doi($doi)             if $doi;
  $pub->issn($ISSN)           if $ISSN;
  $pub->pmid($pmid)           if $pmid;
  $pub->eprint($arxivid)      if $arxivid;
  $pub->authors($authors)     if $authors;
  $pub->publisher($publisher) if $publisher;
  $pub->keywords($keywords)   if $keywords;
  $pub->url($url)             if $url;

  return $pub;
}

1;
