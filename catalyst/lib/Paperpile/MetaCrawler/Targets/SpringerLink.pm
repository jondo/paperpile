
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

package Paperpile::MetaCrawler::Targets::SpringerLink;
use Moose;
use Paperpile::Plugins::Import::SpringerLink;

extends 'Paperpile::MetaCrawler::Targets';

sub convert {

  my ($self, $content, $url) = @_;

  my $SpringerLinkPlugin = Paperpile::Plugins::Import::SpringerLink->new();
  my $pub = Paperpile::Library::Publication->new();
  $pub->annote( $content );

  my $full_pub = $SpringerLinkPlugin->complete_details($pub);

  return $full_pub;
}
