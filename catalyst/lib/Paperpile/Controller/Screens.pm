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

package Paperpile::Controller::Screens;

use strict;
use warnings;
use Data::Dumper;
use parent 'Catalyst::Controller';

sub patterns : Local {
  my ( $self, $c ) = @_;
  $c->stash->{template} = '/screens/patterns.mas';
  $c->forward('Paperpile::View::Mason');
}

sub settings : Local {
  my ( $self, $c ) = @_;
  $c->stash->{template} = '/screens/settings.mas';
  $c->forward('Paperpile::View::Mason');
}

sub tex_settings : Local {
  my ( $self, $c ) = @_;

  #$c->stash->{settings} = $c->model('Library')->settings;

  $c->stash->{template} = '/screens/tex_settings.mas';
  $c->forward('Paperpile::View::Mason');
}

sub license : Local {
  my ( $self, $c ) = @_;
  $c->stash->{template} = '/screens/license.mas';
  $c->forward('Paperpile::View::Mason');
}

sub credits : Local {
  my ( $self, $c ) = @_;
  $c->stash->{template} = '/screens/credits.mas';
  $c->forward('Paperpile::View::Mason');
}

sub flash_container : Local {

  my ( $self, $c ) = @_;
  $c->stash->{template} = '/screens/flash_container.mas';

  $c->stash->{type} = $c->request->params->{type};
  $c->forward('Paperpile::View::Mason');

}

sub dashboard : Local {
  my ( $self, $c ) = @_;

  my $stats = $c->model('Library')->dashboard_stats;

  $c->stash->{num_items}       = $stats->{num_items};
  $c->stash->{num_pdfs}        = $stats->{num_pdfs};
  $c->stash->{num_attachments} = $stats->{num_attachments};
  $c->stash->{last_imported}   = $stats->{last_imported};

  $c->stash->{template} = '/screens/dashboard.mas';
  $c->forward('Paperpile::View::Mason');
}

1;
