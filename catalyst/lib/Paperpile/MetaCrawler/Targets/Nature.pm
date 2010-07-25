
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

package Paperpile::MetaCrawler::Targets::Nature;
use Moose;
use HTML::TreeBuilder::XPath;
use Paperpile::Formats::HTML;

extends 'Paperpile::MetaCrawler::Targets';

sub convert {

  my ($self, $content, $url) = @_;

  print STDERR "AAAAA\n";
  # First we parse Meta Tags with the regular module
  my $f = new Paperpile::Formats::HTML;
  $f->content($content);
  my $pub = $f->read();

  # We parse the HTML via XPath to get the abstract
  my $tree = HTML::TreeBuilder::XPath->new;
  $tree->utf8_mode(1);
  $tree->parse_content($content);

  my $abstract = '';

  $abstract = $tree->findnodes_as_string(q{/html/body/div/div/div/div/div/div[@id='abs']});
  $abstract = $tree->findnodes_as_string(q{/html/body/div/div/div/div/div[@id='abs']}) if ( $abstract eq '' );

  # We get the abstract in HTML and format it then a little bit prettier
  $abstract =~ s/\sclass="[a-z\d\-\s_]+"//g;
  $abstract =~ s/\sid="[a-z]+"//g;
  $abstract =~ s/<\/?div>//g;
  $abstract =~ s/<\/?span>//g;
  $abstract =~ s/<h\d>/<b>/g;
  $abstract =~ s/<\/h\d>/<\/b>/g;
  $abstract =~ s/<a href="#top">Top of page<\/a>//;
  $abstract =~ s/<b>Abstract<\/b>//;
  $abstract =~ s/<p><\/p>//g;
  $abstract =~ s/\shref="[^"]+"//g;
  $abstract =~ s/<\/?a>//g;
  

  $pub->abstract( $abstract ) if ( $abstract );

  return $pub;

}
