
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

package Paperpile::MetaCrawler::Targets::Wiley;
use Moose;
use Paperpile::Utils;
use Paperpile::Formats;
use Encode;

extends 'Paperpile::MetaCrawler::Targets';

sub convert {

  my ( $self, $content, $content_URL ) = @_;
  my $browser =  Paperpile::Utils->get_browser;

  my $id;

  if ( $content_URL =~ m/(.*journal\/)(\d+)(\/.*)/ ) {
    $id = $2;
  }
  if ( ! $id ) {
    if ( $content =~ m/oid=(\d+)/ ) {
      $id = $2;
    }
  }

  if ( $id ) {
    my $base = 'http://www3.interscience.wiley.com/tools/citex?clienttype=1&subtype=1&mode';
    my $tmp_page_URL = "$base=1&version=1&id=$2&redirect=/journal/$id/abstract/";
    my $endnote_URL = "$base=2&format=3&type=2&file=1&id=$id";
    my $tmp_response = $browser->get($tmp_page_URL);
    my $response_endnote = $browser->get($endnote_URL);

    my $endnote = encode_utf8($response_endnote->content());

    my $f = Paperpile::Formats->new(format=>'ENDNOTE');
    my $pub = $f->read_string($endnote);
    return $pub->[0];
  } else {
    return undef;
  }

}

