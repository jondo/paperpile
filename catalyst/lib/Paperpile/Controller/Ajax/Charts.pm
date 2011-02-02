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


package Paperpile::Controller::Ajax::Charts;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Data::Dumper;
use 5.010;

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
  $max = 1 if ($max == 0);
  $min = 1 if ($min == 0);

  my $output = '';

  my @sorted_list;
  @sorted_list = sort { lc($a->{name}) cmp lc($b->{name})} @list;
  @sorted_list = sort { $b->{count} <=> $a->{count}} @list if ($sort_by eq 'count');

  foreach my $item ( @sorted_list ) {

    my $count = $item->{count};
    my $x = $item->{count} || 1;

    my $weight = 1.0;

    if ($max > $min){
      $weight=( log($x) - log($min) ) / ( log($max) - log($min) );
    }

    my $size = $minSize + int( ( $maxSize - $minSize ) * $weight );

    my $name = $item->{name};
    my $guid   = $item->{id};

    my $style_string = "";
    my $class_string = "pp-cloud-item";
    my $key_string = "$guid";
    if ($item->{style}) {
      # We have style information for the label cloud.
      my $style = $item->{style};
      $style_string = qq^style_number="$style"^;
      $class_string = qq^pp-cloud-item pp-label-cloud pp-label-style-$style^;
    }

    $output .= "<a key=\"$key_string\" class=\"$class_string\" href=\"#\" $style_string style=\"font-size:$size;\" count=\"$count\">$name</a> ";

  }

  $c->stash->{html} = $output;

}


1;
