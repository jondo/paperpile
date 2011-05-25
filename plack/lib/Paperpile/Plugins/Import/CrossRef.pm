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

package Paperpile::Plugins::Import::CrossRef;

use Mouse;
use XML::Simple;
use Paperpile::Utils;
use Paperpile::Library::Publication;

extends 'Paperpile::Plugins::Import';

sub BUILD {
  my $self = shift;
  $self->plugin_name('CrossRef');
}

sub match {

  ( my $self, my $inpub ) = @_;

  if ( !defined $inpub->doi() ) {
    NetMatchError->throw( error => 'No DOI provided.' );
    return undef;
  }

  my $doi = $inpub->doi();
  $doi =~ s!http://dx\.doi\.org/!!;

  my $url     = 'http://dx.doi.org/' . $doi;
  my $browser = Paperpile::Utils->get_browser;

  # CrossRef offers content negotiation
  # instead of plain forwarding to the publisher page
  # one can obtain detailed infos in XML
  my $req = HTTP::Request->new( GET => $url );
  $req->header( Accept => "application/unixref+xml" );

  my $response = $browser->request($req);

  my $xml = $response->content();

  my $pub = _parseXML($xml);

  return $pub;
}

sub _parseXML {
  my $in = $_[0];

  if ( $in !~ m/^\s*<\?xml/ ) {
    if ( $in =~ m/<title>DOI Not Found<\/title>/ ) {
      NetMatchError->throw( error => 'DOI not found.' );
      return undef;
    } else {
      NetMatchError->throw( error => 'Not indexed in CrossRef.' );
      return undef;
    }
  }

  my $xml = XMLin( $in, ForceArray => [ 'person_name', 'organization' ] );

  my $data;
  if ( exists $xml->{doi_record}->{crossref} ) {
    $data = $xml->{doi_record}->{crossref};
  }

  if ( !defined $data ) {
    NetMatchError->throw( error => 'DOI not valid or not indexed in CrossRef.' );
    return undef;
  }

  my %vars = ( 'type' => 'MISC' );

  # set of rules that map Crossrefs unixref entities from the parsed XML
  # to Paperile entities
  my %parsingrules = (
    'title' => [
      'journal|journal_article|titles|title', 'conference|conference_paper|titles|title',
      'book|book_metadata|titles|title',      'book|book_series_metadata|titles|title'
    ],
    'booktitle' => ['conference|proceedings_metadata|proceedings_title'],
    'chapter'   => ['book|content_item|component_type=chapter:titles|title'],
    'page_f'    => [
      'journal|journal_article|pages|first_page',
      'conference|conference_paper|pages|first_page',
      'book|content_item|component_type=chapter:pages|first_page'
    ],
    'page_l' => [
      'journal|journal_article|pages|last_page',
      'conference|conference_paper|pages|last_page',
      'book|content_item|component_type=chapter:pages|last_page'
    ],
    'year' => [
      'journal|journal_article|publication_date|year',
      'conference|conference_paper|publication_date|year',
      'conference|proceedings_metadata|publication_date|year',
      'book|book_metadata|publication_date|year',
      'book|book_series_metadata|publication_date|year'
    ],
    'month' => [
      'journal|journal_article|publication_date|month',
      'conference|conference_paper|publication_date|month',
      'conference|proceedings_metadata|publication_date|month',
      'book|book_metadata|publication_date|month',
      'book|book_series_metadata|publication_date|month'
    ],
    'year_p' => [
      'journal|journal_article|publication_date|?|media_type=print:year',
      'conference|conference_paper|publication_date|?|media_type=print:year',
      'conference|proceedings_metadata|publication_date|?|media_type=print:year',
      'book|book_metadata|publication_date|?|media_type=print:year',
      'book|book_series_metadata|publication_date|?|media_type=print:year'
    ],
    'month_p' => [
      'journal|journal_article|publication_date|?|media_type=print:month',
      'conference|conference_paper|publication_date|?|media_type=print:month',
      'conference|proceedings_metadata|publication_date|?|media_type=print:month',
      'book|book_metadata|publication_date|?|media_type=print:month',
      'book|book_series_metadata|publication_date|?|media_type=print:month'
    ],
    'year_o' => [
      'journal|journal_article|publication_date|?|media_type=online:year',
      'conference|conference_paper|publication_date|?|media_type=online:year',
      'conference|proceedings_metadata|publication_date|?|media_type=online:year',
      'book|book_metadata|publication_date|?|media_type=online:year',
      'book|book_series_metadata|publication_date|?|media_type=online:year'
    ],
    'month_o' => [
      'journal|journal_article|publication_date|?|media_type=online:month',
      'conference|conference_paper|publication_date|?|media_type=online:month',
      'conference|proceedings_metadata|publication_date|?|media_type=online:month',
      'book|book_metadata|publication_date|?|media_type=online:month',
      'book|book_series_metadata|publication_date|?|media_type=online:month'
    ],
    'volume' => [
      'journal|journal_issue|journal_volume|volume', 'book|book_metadata|volume',
      'book|book_series_metadata|volume'
    ],
    'issue'   => ['journal|journal_issue|issue'],
    'edition' => ['book|book_metadata|edition_number'],
    'journal' => [ 'journal|journal_metadata|abbrev_title', 'journal|journal_metadata|full_title' ],
    'issn_p'  => [
      'journal|journal_metadata|issn|?|media_type=print:content',
      'book|book_series_metadata|series_metadata|issn|?|media_type=print:content'
    ],
    'issn_e' => [
      'journal|journal_metadata|issn|?|media_type=electronic:content',
      'book|book_series_metadata|series_metadata|issn|?|media_type=electronic:content'
    ],
    'issn' => [ 'journal|journal_metadata|issn', 'book|book_series_metadata|series_metadata|issn' ],
    'isbn' => [
      'conference|proceedings_metadata|isbn', 'book|book_metadata|isbn',
      'book|book_series_metadata|isbn'
    ],
    'isbn_p' => [
      'conference|proceedings_metadata|isbn|?|media_type=print:content',
      'book|book_metadata|isbn|?|media_type=print:content',
      'book|book_series_metadata|isbn|?|media_type=print:content'
    ],
    'isbn_e' => [
      'conference|proceedings_metadata|isbn|?|media_type=electronic:content',
      'book|book_metadata|isbn|?|media_type=electronic:content',
      'book|book_series_metadata|isbn|?|media_type=electronic:content'
    ],
    'publisher' => [
      'conference|proceedings_metadata|publisher|publisher_name',
      'book|book_metadata|publisher|publisher_name',
      'book|book_series_metadata|publisher|publisher_name'
    ],
    'address' => [
      'conference|proceedings_metadata|publisher|publisher_place',
      'book|book_metadata|publisher|publisher_place',
      'book|book_series_metadata|publisher|publisher_place'
    ],
    'series'               => ['book|book_series_metadata|series_metadata|titles|title'],
    'article_contributors' => [
      'journal|journal_article|contributors|person_name',
      'journal|journal_article|contributors|organization',
      'conference|conference_paper|contributors|person_name',
      'conference|conference_paper|contributors|organization'
    ],
    'book_contributors'   => ['book|book_metadata|contributors|person_name'],
    'series_contributors' => ['book|book_series_metadata|series_metadata|contributors|person_name'],
    'bookseries_contributors' => ['book|book_series_metadata|contributors|person_name'],
    'chapter_contributors' => ['book|content_item|component_type=chapter:contributors|person_name'],
    'doi'                  => [
      'journal|journal_article|doi_data|doi',
      'conference|conference_paper|doi_data|doi',
      'book|content_item|component_type=chapter:doi_data|doi',
      'book|book_metadata|doi_data|doi',
      'book|book_series_metadata|doi_data|doi'
    ]
  );

  # rules are applied here and %vars gets populated with entries
  foreach my $rule ( keys %parsingrules ) {
    my @subrules = @{ $parsingrules{$rule} };
    foreach my $subrule (@subrules) {

      # XML entities are separated by |
      # an entity is either a single word or a series of
      # words  of the form: word1=word2:word3
      # word1 - entity or attribute
      # word2 - attribute value
      # word3 - entity or attribute to follow
      my @F = split( /\|/, $subrule );
      my $p = $data;
      foreach my $k ( 0 .. $#F ) {
        ( my $field, my $value, my $target ) = split( /[=:]/, $F[$k] );
        $target = $field if ( not defined $target );
        if ( ref($p) eq 'HASH' ) {
          if ( defined $p->{$field} ) {
            if ( $k == $#F ) {

              # authors/editors are processed specially
              if ( $field eq 'person_name' or $field eq 'organization' ) {
                ( my $authors, my $editors ) = _process_authors( $p->{$field} );
                $vars{$rule} = { 'authors' => $authors, 'editors' => $editors };
                last;
              }

              # it seems that we do not reached a SCALAR
              last if ( ref( $p->{$field} ) eq 'HASH'
                or ref( $p->{$field} ) eq 'ARRAY' );

              # last if it is not the value we are looking for
              if ( defined $value ) {
                last if ( $p->{$field} ne $value );
              }
              last if ( not defined $p->{$target} );
              $vars{$rule} = $p->{$target};
            }

            # last if it is not the value we are looking for
            if ( defined $value ) {
              last if ( $p->{$field} ne $value );
            }
            last if ( !defined $p->{$target} );
            $p = $p->{$target};
          }
        } elsif ( ref($p) eq 'ARRAY' ) {

          # arrays are marked with ?
          # all possible indices are generated
          # and subrules are added accordingly
          if ( $field eq '?' ) {
            $field = 0;
            for my $l ( 1 .. $#{$p} ) {
              $F[$k] = $l;
              push @subrules, join( '|', @F );
            }
            $F[$k] = 0;
          } elsif ( $field !~ m/^\d+/ ) {
            last;
          }
          if ( $p->[$field] ) {
            $p = $p->[$field];
          }
        }
      }

      # we found a value, remaining subrules are skipped
      last if ( defined $vars{$rule} );
    }
  }

  # determine pubtype
  $vars{type} = 'ARTICLE'       if ( $data->{journal} );
  $vars{type} = 'INPROCEEDINGS' if ( $data->{conference} );
  $vars{type} = 'BOOK'          if ( $data->{book} );
  if ( $vars{type} eq 'BOOK' and $data->{book}->{content_item} ) {
    if ( $data->{book}->{content_item}->{component_type} ) {
      $vars{type} = 'INCOLLECTION'
        if ( $data->{book}->{content_item}->{component_type} eq 'chapter' );
    }
  }

  my $pub = Paperpile::Library::Publication->new( pubtype => $vars{type} );

  # Authors
  ( my $authors, my $editors );

  if ( exists $vars{article_contributors}->{authors} ) {
    $authors = $vars{article_contributors}->{authors};
  }
  if ( exists $vars{book_contributors}->{authors} ) {
    $authors = $vars{book_contributors}->{authors};
    $editors = $vars{book_contributors}->{editors};
  }
  if ( $vars{type} eq 'INCOLLECTION' ) {
    if (  defined $vars{book_contributors}->{authors}
      and defined $vars{chapter_contributors}->{authors} ) {
      $authors = $vars{chapter_contributors}->{authors};
      $editors = $vars{book_contributors}->{authors};
    } else {
      $authors = $vars{chapter_contributors}->{authors};
      $editors = $vars{book_contributors}->{editors};
    }
  }
  if ( $vars{type} eq 'BOOK' ) {
    if (  defined $vars{series_contributors}
      and defined $vars{bookseries_contributors} ) {
      if (  defined $vars{series_contributors}->{editors}
        and defined $vars{bookseries_contributors}->{editors} ) {
        $vars{type} = 'PROCEEDINGS';
        $pub->pubtype('PROCEEDINGS');
        $authors = $vars{bookseries_contributors}->{editors};
        $editors = $vars{series_contributors}->{editors};
      } else {
        $vars{type} = 'INCOLLECTION';
        $pub->pubtype('INCOLLECTION');
        $authors = $vars{bookseries_contributors}->{authors};
        $editors = $vars{series_contributors}->{editors};
        if ( not defined $vars{series_contributors}->{editors} ) {
          $editors = $vars{series_contributors}->{authors};
        }
      }
    }
  }

  $pub->authors($authors) if $authors;
  $pub->editors($editors) if $editors;

  # ISBN
  if ( defined $vars{isbn} ) {
    $pub->isbn( $vars{isbn} );
  } elsif ( defined $vars{isbn_p} ) {
    $pub->isbn( $vars{isbn_p} );
  } elsif ( defined $vars{isbn_e} ) {
    $pub->isbn( $vars{isbn_e} );
  }

  # ISSN
  if ( defined $vars{issn} ) {
    $pub->issn( $vars{issn} );
  } elsif ( defined $vars{issn_p} ) {
    $pub->issn( $vars{issn_p} );
  } elsif ( defined $vars{issn_e} ) {
    $pub->issn( $vars{issn_e} );
  }

  # YEAR
  if ( defined $vars{year} ) {
    $pub->year( $vars{year} );
  } elsif ( defined $vars{year_p} ) {
    $pub->year( $vars{year_p} );
  } elsif ( defined $vars{year_o} ) {
    $pub->year( $vars{year_o} );
  }

  # MONTH
  if ( defined $vars{month} ) {
    $pub->month( $vars{month} );
  } elsif ( defined $vars{month_p} ) {
    $pub->month( $vars{month_p} );
  } elsif ( defined $vars{month_o} ) {
    $pub->month( $vars{month_o} );
  }

  # PAGES
  if ( defined $vars{page_f} and defined $vars{page_l} ) {
    $pub->pages("$vars{page_f}-$vars{page_l}");
  } elsif ( defined $vars{page_f} ) {
    $pub->pages( $vars{page_f} );
  }

  if ( defined $vars{title} ) {
    $vars{title} =~ s/\s*\.\s*$//;
  }
  if ( defined $vars{booktitle} ) {
    $vars{booktitle} =~ s/\s*\.\s*$//;
  }

  $pub->publisher( $vars{publisher} ) if ( defined $vars{publisher} );
  $pub->address( $vars{address} )     if ( defined $vars{address} );
  $pub->series( $vars{series} )       if ( defined $vars{series} );
  $pub->title( $vars{title} )         if ( defined $vars{title} );
  $pub->booktitle( $vars{booktitle} ) if ( defined $vars{booktitle} );
  $pub->chapter( $vars{chapter} )     if ( defined $vars{chapter} );
  $pub->volume( $vars{volume} )       if ( defined $vars{volume} );
  $pub->issue( $vars{issue} )         if ( defined $vars{issue} );
  $pub->journal( $vars{journal} )     if ( defined $vars{journal} );
  $pub->doi( $vars{doi} )             if ( defined $vars{doi} );

  return $pub;
}

sub _process_authors {
  my $in = $_[0];

  my ( $authors, $editors );
  return ( $authors, $editors ) if ( ref($in) ne 'ARRAY' );

  my @tmp_authors = ();
  my @tmp_editors = ();
  foreach my $entry ( @{$in} ) {
    my ( $first, $last, $jr, $von );
    $first = $entry->{given_name} if ( $entry->{given_name} );
    $last  = $entry->{surname}    if ( $entry->{surname} );
    my $name;
    if ( defined $first and defined $last ) {
      $name = "$last, $first";
    } elsif ( !defined $first and defined $last ) {
      $name = "{$last}";
    } elsif ( !defined $first and !defined $last ) {
      if ( defined $entry->{content} ) {
        $name = "{$entry->{content}}";
      }
    }
    next if ( !defined $name );
    if ( defined $entry->{contributor_role} ) {
      if ( $entry->{contributor_role} eq 'editor' ) {
        push @tmp_editors, $name;
      } else {
        push @tmp_authors, $name;
      }
    } else {
      push @tmp_authors, $name;
    }
  }

  if ( $#tmp_authors > -1 ) {
    $authors = join( ' and ', @tmp_authors );
    $authors =~ s/\.(?!-)/. /g;
    $authors =~ s/\s+/ /g;
    $authors =~ s/\s+$//g;
  }
  if ( $#tmp_editors > -1 ) {
    $editors = join( ' and ', @tmp_editors );
    $editors =~ s/\.(?!-)/. /g;
    $editors =~ s/\s+/ /g;
    $editors =~ s/\s+$//g;
  }

  return ( $authors, $editors );
}

1;
