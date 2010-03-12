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

package Paperpile::Controller::Ajax::Charts;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Data::Dumper;
use 5.010;

sub chart : Local {

  my ( $self, $c ) = @_;
  my $type = $c->request->params->{type};

  # This controlles is currently called from an iframe which has not
  # set the session variables of the main application
  $c->session->{library_db} = $c->config->{'user_settings'}->{library_db};

  my $chart;

  if ($type eq 'top_authors'){
    my $hist = $c->model('Library')->histogram('authors');
    $chart = $self->_chart($hist, 'bar');
  }

  if ($type eq 'top_journals'){
    my $hist = $c->model('Library')->histogram('journals');
    $chart = $self->_chart($hist, 'bar');
  }

  if ($type eq 'top_tags'){
    my $hist = $c->model('Library')->histogram('tags');
    $chart = $self->_chart($hist, 'bar');
  }

  if ($type eq 'pubtypes'){
    my $hist = $c->model('Library')->histogram('pubtype');

    foreach my $key (keys %$hist){
      $hist->{$key}->{name}=$c->config->{pub_types}->{$key}->{name};
    }

    $hist->{BOOK}->{count}+=$hist->{INBOOK}->{count};
    delete($hist->{INBOOK});

    $chart = $self->_chart($hist, 'pie');
  }

  foreach my $key ( keys %$chart ) {
    $c->stash->{$key} = $chart->{$key};
  }

}


sub _chart : Local {

  my ( $self, $hist, $type ) = @_;

  my @values = ();
  my @labels = ();

  my $counter = 0;

  if ( $type eq 'bar' ) {

    foreach my $key ( sort { $hist->{$b}->{count} <=> $hist->{$a}->{count} } keys %$hist ) {
      push @values, $hist->{$key}->{count};
      push @labels, $hist->{$key}->{name};
      $counter++;
      last if $counter >= 10;
    }
  }

  if ( $type eq 'pie' ) {
    foreach my $key ( sort { $hist->{$b}->{count} <=> $hist->{$a}->{count} } keys %$hist ) {
      push @values, { value => $hist->{$key}->{count}, label => $hist->{$key}->{name} };
    }
  }

  my $chart = {
    "bg_colour" => "#FFFEEB",
    elements    => [ {
        type            => $type,
        "gradient-fill" => \1,
        values    => [@values],
        "on-show" => {
          "type"    => "grow-up",
          "cascade" => 0,
          "delay"   => 0
        }
      },
    ],
    y_axis => {
      'min'         => 0,
      'max'         => $values[0] + 10,
      steps         => 5,
      "grid-colour" => "#FFFFFF",
      "colour"      => "#000000",
      "font-size"   => 26
    },

    x_axis => {
      "grid-colour" => "#FFFFFF",
      labels        => {
        rotate => 315,
        labels => [@labels]
      },
      "colour" => "#000000"
    },
  };

  if ( $type eq 'bar' ) {
    $chart->{elements}->[0]->{colour} = "#006AFF";
    $chart->{elements}->[0]->{alpha}  = 0.6;
  }

  my $colors = [ '#006AFF', '#44c450', '#f12d0d', '#f3f602', '#c502f6', '#f6a802' ];

  if ( $type eq 'pie' ) {
    $chart->{elements}->[0]->{colours} = $colors;
    $chart->{elements}->[0]->{alpha}   = 1.0;
  }

  return $chart;

}


sub clouds : Local {

  my ( $self, $c ) = @_;
  my $field = $c->request->params->{field};
  my $sort_by = $c->request->params->{sorting};

  $sort_by = 'alphabetical' unless (defined $sort_by);

  my $hist = $c->model('Library')->histogram($field);

  my $minSize = 10;
  my $maxSize = 20;

  my $max_items = 300;

  my @list = ();

  my $counter = 0;

  foreach my $key ( sort { $hist->{$b}->{count} <=> $hist->{$a}->{count} } keys %$hist ) {
    push @list, $hist->{$key};
    last if $counter++ > $max_items;
  }

  my $max = $list[0]->{count};
  my $min = $list[$#list]->{count};

  my $output = '';

  my @sorted_list;
  @sorted_list = sort { lc($a->{name}) cmp lc($b->{name})} @list;
  @sorted_list = sort { $b->{count} <=> $a->{count}} @list if ($sort_by eq 'count');

  foreach my $item ( @sorted_list ) {

    my $x = $item->{count};

    my $weight = 1.0;

    if ($max > $min){
      $weight=( log($x) - log($min) ) / ( log($max) - log($min) );
    }

    my $size = $minSize + int( ( $maxSize - $minSize ) * $weight );

    my $name = $item->{name};
    my $id   = $item->{id};

    if ($item->{style}) {
      # We have style information for the tag cloud.
      my $style = $item->{style};
      $output .= "<a class=\"pp-tag-cloud pp-tag-style-${style}\" key=\"$name\" style_number=\"${style}\" href=\"#\" style=\"font-size:$size;\">$name</a> ";
    } else {
      $output .= "<a key=\"$id\" class=\"pp-cloud-item\" href=\"#\" style=\"font-size:$size;\">$name</a> ";
    }

  }

  $c->stash->{html} = $output;

}




1;
