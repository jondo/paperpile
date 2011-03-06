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


package Paperpile::Controller::Root;

use strict;
use warnings;
use MIME::Types qw(by_suffix);
use Data::Dumper;


sub templates {

  my ( $self, $c, $name ) = @_;

  if ( $name eq 'dashboard' ) {
    my $stats = $c->model('Library')->dashboard_stats;
    $c->stash->{num_items}       = $stats->{num_items};
    $c->stash->{num_pdfs}        = $stats->{num_pdfs};
    $c->stash->{num_attachments} = $stats->{num_attachments};
    $c->stash->{last_imported}   = $stats->{last_imported};
    $c->stash->{version_name}    = $c->config->{app_settings}->{version_name};
    $c->stash->{platform}        = $c->config->{app_settings}->{platform};
  }
}


# # Serves static files and sets appropriate MIME type.
# sub serve : Regex('^serve/(.*)$') {

#   my ( $self, $c ) = @_;

#   my $file = $c->req->captures->[0];

#   if ( not open( IN, $file ) ) {
#     $c->response->status(404);
#     $c->response->body("Could not open $file.");
#   } else {

#     my $data = '';

#     my ( $mime_type, $encoding ) = by_suffix($file);

#     $data .= $_ foreach (<IN>);
#     $c->response->status(200);
#     $c->response->content_type($mime_type);
#     $c->response->body($data);
#   }
# }



1;
