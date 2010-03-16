# Copyright 2009, 2010 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.  You should have received a
# copy of the GNU General Public License along with Paperpile.  If
# not, see http://www.gnu.org/licenses.

package Paperpile::Plugins::Import::OxfordJournals;

use Carp;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;
use HTML::TreeBuilder::XPath;
use 5.010;

use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Paperpile::Utils;

extends 'Paperpile::Plugins::Import';

sub BUILD {
  my $self = shift;
  $self->plugin_name('OxfordJournals');
}

sub connect {
  my $self = shift;

  return 0;
}

sub page {
  ( my $self, my $offset, my $limit ) = @_;

  my $page = [];

  $self->_save_page_to_hash($page);

  return $page;
}

sub complete_details {

  ( my $self, my $pub ) = @_;

  if ( !$pub->_details_link() ) {
    NetFormatError->throw( error => 'No link provided to get bibliographic detils.' );
  }

  ( my $link = $pub->_details_link() ) =~ s/\.pdf$//;

  my $browser  = Paperpile::Utils->get_browser;
  my $response = $browser->get($link);
  my $content  = $response->content;

  # We parse the HTML via XPath
  my $tree = HTML::TreeBuilder::XPath->new;
  $tree->utf8_mode(1);
  $tree->parse_content($content);

  my (
    $title, $authors, $journal, $year, $month,    $pmid,
    $doi,   $volume,  $issue,   $issn, $abstract, $pages
  );

  my @meta_tags = $tree->findnodes('/html/head/meta[@name="citation_mjid"]');
  if ( $#meta_tags == -1 ) {
    NetFormatError->throw( error => 'No meta tag named citation_mjid found.' );
  }

  # Get the bibtex link
  my $id = $meta_tags[0]->attr('content');
  $id =~ s/v\d$//;
  @meta_tags = $tree->findnodes('/html/head/meta[@name="citation_abstract_html_url"]');
  my $base_url = $meta_tags[0]->attr('content');
  $base_url =~ s/(.*\/)(content.*)/$1/;
  my $bibtex_url = $base_url."citmgr?type=bibtex&gca=$id";

  my $bibtex_tmp = $browser->get($bibtex_url);
  my $bibtex     = $bibtex_tmp->content;

  # Create a new Publication object
  my $full_pub = Paperpile::Library::Publication->new();

  # import the information from the BibTeX string
  $full_pub->import_string( $bibtex, 'BIBTEX' );

  # It seems that there is some trouble with Bibtex export at OUP
  # let's screen for missed information in the HTML meta tags

  if ( !$full_pub->volume() ) {
    my @tmp = $tree->findnodes('/html/head/meta[@name="citation_volume"]');
    $full_pub->volume( $tmp[0]->attr('content') ) if ( $tmp[0] );
  }
  if ( !$full_pub->issue() ) {
    my @tmp = $tree->findnodes('/html/head/meta[@name="citation_issue"]');
    $full_pub->issue( $tmp[0]->attr('content') ) if ( $tmp[0] );
  }
  if ( !$full_pub->pmid() ) {
    my @tmp = $tree->findnodes('/html/head/meta[@name="citation_pmid"]');
    $full_pub->pmid( $tmp[0]->attr('content') ) if ( $tmp[0] );
  }
  if ( !$full_pub->pages() ) {
    my @tmp = $tree->findnodes('/html/head/meta[@name="citation_firstpage"]');
    $full_pub->pages( $tmp[0]->attr('content') ) if ( $tmp[0] );
  }

  # bibtex import deactivates automatic refresh of fields
  # we force it now at this point
  $full_pub->_light(0);
  $full_pub->refresh_fields();
  $full_pub->refresh_authors();

  $full_pub->citekey('');

  # Note that if we change title, authors, and citation also the sha1
  # will change. We have to take care of this.
  my $old_sha1 = $pub->sha1;
  my $new_sha1 = $full_pub->sha1;
  delete( $self->_hash->{$old_sha1} ) if ($old_sha1);
  $self->_hash->{$new_sha1} = $full_pub;

  return $full_pub;
}

1;
