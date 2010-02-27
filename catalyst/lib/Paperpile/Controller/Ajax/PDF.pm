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

package Paperpile::Controller::Ajax::PDF;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Data::Dumper;
use XML::Simple;
use File::Temp;
use File::Path;
use File::Spec;
use Paperpile::Utils;

use 5.010;

sub render : Regex('^ajax/pdf/render/(.*\.pdf)/(\d+)/(\d+\.\d+)$') {
  my ( $self, $c ) = @_;

  my $path = $c->req->captures->[0];
  my $root = File::Spec->rootdir();

  # File dialogue prepends ROOT as marker for the system root
  $path =~ s/^ROOT//;

  my $bin = Paperpile::Utils->get_binary( 'extpdf', $c->config->{platform} );

  my %extpdf;

  $extpdf{command} = 'RENDER';
  $extpdf{inFile}  = File::Spec->catfile( $root, $path );
  $extpdf{page}    = $c->req->captures->[1];
  $extpdf{scale}   = $c->req->captures->[2];
  $extpdf{outFile} = 'STDOUT';

  my $xml = XMLout( \%extpdf, RootName => 'extpdf', XMLDecl => 1, NoAttr => 1 );

  my ( $fh, $filename ) = File::Temp::tempfile();
  print $fh $xml;
  close($fh);

  my @out = `$bin $filename`;

  unlink($filename);

  my $png = '';
  $png .= $_ foreach @out;

  $c->response->body($png);
  $c->response->content_type('image/png');
  $c->res->headers->header( 'Cache-Control' => 'max-age=3600' );

}

sub extpdf : Local {

  my ( $self, $c ) = @_;

  my $bin = Paperpile::Utils->get_binary( 'extpdf', $c->config->{platform} );

  # File dialogue prepends ROOT as marker for the system root
  $c->request->params->{inFile} =~ s/^ROOT//;

  my $xml = XMLout( $c->request->params, RootName => 'extpdf', XMLDecl => 1, NoAttr => 1 );

  my ( $fh, $filename ) = File::Temp::tempfile();
  print $fh $xml;
  close($fh);

  my @output = `$bin $filename`;

  unlink($filename);

  my $output = '';
  $output .= $_ foreach @output;

  $c->response->body($output);
  $c->response->content_type('text/xml');

}

1;
