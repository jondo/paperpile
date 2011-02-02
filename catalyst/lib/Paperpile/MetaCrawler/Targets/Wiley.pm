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


package Paperpile::MetaCrawler::Targets::Wiley;
use Moose;
use Paperpile::Utils;
use Paperpile::Formats;
use Encode;
use WWW::Mechanize;

extends 'Paperpile::MetaCrawler::Targets';

sub convert {

  my ( $self, $content, $content_URL ) = @_;

  ( my $linkout = $content ) =~ s/(.*")(\/documentcitationdownload[^"]+)(".*)/$2/ms;
  $linkout =~ s/&amp;/&/g;
  $linkout = 'http://onlinelibrary.wiley.com' . $linkout;

  my $mech = WWW::Mechanize->new( autocheck => 1 );
  $mech->agent_alias('Windows IE 6');

  $mech->get($linkout);

  my $form = $mech->form_number(2);

  my @input_fields = $form->inputs;

  $mech->select( 'fileFormat',  "ENDNOTE" );
  $mech->select( 'hasAbstract', "CITATION_AND_ABSTRACT" );

  my $response = $mech->click();

  my $f = Paperpile::Formats->new( format => 'RIS' );
  my $pub = $f->read_string( $response->decoded_content() );

  return $pub->[0];
}

