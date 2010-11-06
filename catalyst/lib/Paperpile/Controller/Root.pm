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


package Paperpile::Controller::Root;

use strict;
use warnings;
use MIME::Types qw(by_suffix);
use parent 'Catalyst::Controller';
use Data::Dumper;

__PACKAGE__->config->{namespace} = '';

# Load index file dynamically (i.e. when opened in a browser)
sub index : Path : Args(0) {
  my ( $self, $c ) = @_;

  # Add dynamically all *js files in the plugins directory
  my @list = glob( $c->path_to('root/js/import/plugins') . "/*js" );

  my @plugins = ();

  foreach my $plugin (@list) {
    my ( $volume, $directories, $file ) = File::Spec->splitpath($plugin);
    push @plugins, "js/import/plugins/$file";
  }

  $c->stash->{plugins} = [@plugins];

  $c->stash->{template} = 'index.mas';
  $c->forward('Paperpile::View::Mason');
}

# Serves dynamic HTML templates for the frontend.
sub screens : Regex('^screens/(.*)$') {

  my ( $self, $c ) = @_;

  my $screen = $c->req->captures->[0];

  if ($screen eq 'dashboard'){
    my $stats = $c->model('Library')->dashboard_stats;
    $c->stash->{num_items}       = $stats->{num_items};
    $c->stash->{num_pdfs}        = $stats->{num_pdfs};
    $c->stash->{num_attachments} = $stats->{num_attachments};
    $c->stash->{last_imported}   = $stats->{last_imported};
  }

  $c->stash->{template} = "/screens/$screen.mas";

  $c->forward('Paperpile::View::Mason');

}


# Serves static files and sets appropriate MIME type.
sub serve : Regex('^serve/(.*)$') {

  my ( $self, $c ) = @_;

  my $file = $c->req->captures->[0];

  if ( not open( IN, $file ) ) {
    $c->response->status(404);
    $c->response->body("Could not open $file.");
  } else {

    my $data = '';

    my ( $mime_type, $encoding ) = by_suffix($file);

    $data .= $_ foreach (<IN>);
    $c->response->status(200);
    $c->response->content_type($mime_type);
    $c->response->body($data);
  }
}

sub default : Path {
  my ( $self, $c ) = @_;
  $c->response->body('Page not found');
  $c->response->status(404);
}


sub end : Private {
  my ( $self, $c ) = @_;

  if ( scalar @{ $c->error } ) {

    my $error = $c->error->[0];

    if ( $error->isa('PaperpileError') ) {
      my $data = {
        msg  => $error->error,
        type => ref($error)
      };

      foreach my $field ( $error->Fields ) {
        $data->{$field} = $error->$field;
      }

      $c->stash->{error} = $data;
    } else {
      $c->response->status(500);
      $c->stash->{error} = {
        msg  => join( '<br>', @{ $c->error } ),
        type => 'Unknown',
      };
    }

    $c->forward('Paperpile::View::JSON');

    foreach my $error ( @{ $c->error } ) {
      $c->log->error($error);
    }

    $c->error(0);
  }

  return 1 if $c->response->status =~ /^3\d\d$/;
  return 1 if $c->response->body;

  $c->forward('Paperpile::View::JSON');

}

1;
