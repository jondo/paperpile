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


package Paperpile::MetaCrawler::Targets::SpringerLink;
use Moose;
use Paperpile::Utils;
use WWW::Mechanize;
use HTML::TreeBuilder;
use Paperpile::Formats::Bibtex;

extends 'Paperpile::MetaCrawler::Targets';

sub convert {

  my ( $self, $content, $url ) = @_;

  # Any export format reurned by Springer skips the middle names of
  # the authors
  # We parse them from the HTML page and then correct the Bibtex
  # author sting
  # I THINK THEY JUST DO IT TO MAKE PEOPLE GO MAD
  my $tree = HTML::TreeBuilder->new;
  $tree->utf8_mode(1);
  $tree->parse_content($content);

  my @tags = $tree->look_down( '_tag' => 'p', 'class' => 'authors' );
  my @authors = split( /,\s+|\s+and\s+/, $tags[0]->as_text() );

  # Now that we're done with it, we must destroy it.
  $tree = $tree->delete;

  my $id;
  if ( $url =~ m/(.*(?:content|index)\/)(\w+)(.*)/ ) {
    $id = $2;
  }

  return undef if ( ! $id );

  my $new_url = "http://www.springerlink.com/content/$id/export-citation/";

  my $mech = WWW::Mechanize->new( autocheck => 1 );
  $mech->agent_alias('Windows IE 6');

  $mech->get($new_url);

  my $form = $mech->form_name("aspnetForm");

  my @input_fields = $form->inputs;

  $mech->field( 'ctl00$ContentPrimary$ctl00$ctl00$Export', "AbstractRadioButton" );
  $mech->field( 'ctl00$ContentPrimary$ctl00$ctl00$Format', "TextRadioButton" );
  $mech->select( 'ctl00$ContentPrimary$ctl00$ctl00$CitationManagerDropDownList', "BibTex" );

  my $response = $mech->click('ctl00$ContentPrimary$ctl00$ctl00$ExportCitationButton');
  my $bibtex   = $response->decoded_content();

  $bibtex =~ s/(.*)(@(?:article|book|booklet|conference|inbook|incollection|inproceedings|manual|mastersthesis|misc|phdthesis|proceedings|techreport|unpublished|comment|string)\s*\{.*)/$2/i;

  # import the information from the BibTeX string
  my $f = Paperpile::Formats::Bibtex->new();
  my $pub = $f->read_string($bibtex)->[0];

  # here we correct the authors from the bibtex 
  my @authors_bib = split( /\s+and\s+/, $pub->authors );
  if ( $#authors_bib == $#authors ) {
    foreach my $i ( 0 .. $#authors_bib ) {
      ( my $last, my $first ) = split( /,\s+/, $authors_bib[$i] );
      $authors[$i] =~ s/$last//;
      ( my $tmp_first   = $first )       =~ s/\s+//g;
      ( my $tmp_authors = $authors[$i] ) =~ s/\s+//g;
      if ( $tmp_first ne $tmp_authors ) {
        $first = $authors[$i];
        $authors_bib[$i] = "$last, $first";
      }
    }

    my $new_authors = join( " and ", @authors_bib );
    $new_authors =~ s/\s+/ /g;
    $pub->authors($new_authors);
  }

  if ( $pub->annote() =~ m/^10\./ ) {
    $pub->doi($pub->annote());
    $pub->annote('');
  }

  # bibtex import deactivates automatic refresh of fields
  # we force it now at this point
  $pub->_light(0);
  $pub->refresh_fields();
  $pub->refresh_authors();

  return $pub;
}

