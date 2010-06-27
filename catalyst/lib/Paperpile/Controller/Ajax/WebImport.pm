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

package Paperpile::Controller::Ajax::WebImport;

use strict;
use warnings;
use Paperpile::Utils;
use Paperpile::MetaCrawler;

use parent 'Catalyst::Controller';

sub import_urls : Local {
  my ( $self, $c ) = @_;

  $c->component('View::JSON')->allow_callback(1);

  my @urls    = $self->_as_array( $c->request->params->{urls} );
  my @indices = $self->_as_array( $c->request->params->{indices} );

  my $model = Paperpile::Utils->get_library_model();

  my $crawler = new Paperpile::MetaCrawler();
  $crawler->driver_file( Paperpile::Utils->path_to( 'data', 'meta-crawler.xml' )->stringify );
  $crawler->load_driver();

  my @results;

  for ( my $i = 0 ; $i < scalar(@urls) ; $i++ ) {
    my $url   = $urls[$i];
    my $index = $indices[$i];
    my $pub   = eval { $crawler->search_file($url) };

    my $e;
    if ( $e = Exception::Class->caught ) {

      #      if ( Exception::Class->caught('CrawlerError') ) {
      push @results, {
        index  => $index,
        status => 'failure',
        error  => $e
        };

      #      }
      next;
    }

    if ( defined $pub ) {
      $model->insert_pubs( [$pub], 1 );
      push @results, {
        index  => $index,
        status => 'success'
        };
    } else {
      print STDERR "NO error but no pub!!!\n";
      push @results, {
        index  => $index,
        status => 'failure',
	error => "Error extracting bibliographic information."
        };
    }
  }
  $c->stash->{results} = \@results;
  $c->forward('View::JSON');
}

sub _as_array {
  my $self = shift;
  my $obj  = shift;

  my @arr;
  if ( ref $obj eq 'ARRAY' ) {
    @arr = @$obj;
  } else {
    @arr = ($obj);
  }
  return @arr;
}

sub submit_page : Local {

  my ( $self, $c ) = @_;

  $c->component('View::JSON')->allow_callback(1);

  my $url = $c->request->params->{url};

  print STDERR "URL: $url\n";

  my $browser  = Paperpile::Utils->get_browser;
  my $response = $browser->get($url);

  if ( $response->is_error ) {
    NetGetError->throw(
      error => 'Network error while scanning page for links: ' . $response->message,
      code  => $response->code
    );
  }

  my $page_type = $self->_detect_page_type( $c, $response );

  if ( $page_type eq 'list' ) {
    $self->_get_links_from_page( $c, $response );
  } elsif ( $page_type eq 'single' ) {
    $self->_import_single_page( $c, $response );
  }

  print STDERR "PAGE TYPE: $page_type\n";

  $c->stash->{page_type} = $page_type;
  $c->forward('View::JSON');
}

sub _get_links_from_page {
  my ( $self, $c, $response ) = @_;

  my $gs = Paperpile::Plugins::Import::GoogleScholar->new();

  #  print STDERR $response."\n";
  my $page = $gs->_parse_googlescholar_page( $response->content );

  my @entries = ();
  my $i       = 0;
  foreach my $pub (@$page) {
    print STDERR "-> " . $pub->_web_import_selector . "\n";
    print STDERR "-> " . $pub->linkout . "\n";
    push @entries, {
      selector   => $pub->_web_import_selector,
      import_url => $pub->linkout
      };
  }
  $c->stash->{entries} = \@entries;
}

sub _import_single_page {
  my ( $self, $c, $response ) = @_;

}

# Detects the page 'type' given its HTML content.
# We need to distinguish between 'single' pages, where the current page
# is a single reference, and 'list' pages, where the current page
# is listing links to a variety of references.
sub _detect_page_type {
  my ( $self, $c, $response ) = @_;

  my $url = $response->request->uri;

  my $list   = 'list';
  my $single = 'single';

  return $list if ( $url =~ m/scholar\.google/gi );
  return $single;
}

1;
