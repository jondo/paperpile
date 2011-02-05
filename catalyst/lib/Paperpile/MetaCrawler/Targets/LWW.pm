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


package Paperpile::MetaCrawler::Targets::LWW;
use Moose;
use Paperpile::Utils;
use Paperpile::Formats;
use Encode;
use WWW::Mechanize;

extends 'Paperpile::MetaCrawler::Targets';

sub convert {

  my ( $self, $content, $content_URL ) = @_;

  my $mech = WWW::Mechanize->new( autocheck => 1 );
  $mech->agent_alias('Windows IE 6');

  $mech->get($content_URL);

  my $form = $mech->form_number(1);

  my @input_fields = $form->inputs;

  my $go_button;
  foreach my $field ( @input_fields ) {
    next if ( ! $field->name() );
    if ( $field->name() =~ m/radioBtnExportTypes/ ) {
      $mech->set_fields( $field->name(),  "Procite" );
    }
    if ( $field->name() =~ m/btnOpenExportDialog/ ) {
      $go_button = $field->name();
    }
  }

  my $response = $mech->click($go_button);

  my $f = Paperpile::Formats->new( format => 'RIS' );
  my $pub = $f->read_string( $response->decoded_content() );

  return $pub->[0];
}

