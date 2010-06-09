
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

package Paperpile::FileSync;

use Moose;
use Moose::Util::TypeConstraints;

use Paperpile;
use Paperpile::Utils;
use Paperpile::Formats::Bibtex;

use File::Path;
use File::Spec::Functions qw(catfile splitpath canonpath abs2rel);
use File::Copy;
use FreezeThaw qw/freeze thaw/;

use Data::Dumper;

use 5.010;

has 'map' => ( is => 'rw', default => sub { return {} } );

sub sync_collection {

  my ( $self, $collection ) = @_;

  my $target = $self->map->{$collection};

  if ( !-e $target ) {
    my $data = $self->_get_data_from_library($collection);
    $self->_write_file( $collection, $data );
    $self->_write_dump( $collection, $data );
  } else {

    my $data = $self->_get_data_from_file($collection);

    print STDERR Dumper($data);

  }
}

sub _get_data_from_library {

  my ( $self, $collection ) = @_;

  my $model = Paperpile::Utils->get_library_model;

  my $dbh = $model->dbh;

  my $sth = $dbh->prepare(
    "SELECT * FROM Publications join Collection_Publication on guid = publication_guid WHERE collection_guid='$collection';"
  );

  $sth->execute;

  my %data = ();

  while ( my $row = $sth->fetchrow_hashref() ) {
    my $pub = Paperpile::Library::Publication->new($row);
    $data{ $row->{guid} } = $pub;
  }

  return \%data;

}

sub _get_data_from_file {

  my ( $self, $collection ) = @_;

  my $file = $self->map->{$collection};

  my $f = Paperpile::Formats::Bibtex->new( file => $file );

  my %data = ();

  foreach my $pub ( @{ $f->read } ) {
    $data{ $pub->guid } = $pub;
  }

  return \%data;
}

sub _write_file {

  my ( $self, $collection, $data ) = @_;

  my $file = $self->map->{$collection};

  my $f = Paperpile::Formats::Bibtex->new( file => $file, data => [ values %$data ] );

  $f->write;

}

sub _write_dump {

  my ( $self, $collection, $data ) = @_;

  my $md5 = Paperpile::Utils->calculate_md5( $self->map->{$collection} );

  my $dump_object = { md5 => $md5, data => $data };

  my $dest = $self->_get_dump_file($collection);

  open( OUT, ">$dest" ) || die("Could not open to $dest during file sync.");

  print OUT freeze($dump_object);

}

sub _get_dump_file {

  my ( $self, $collection ) = @_;
  return catfile( Paperpile::Utils->get_tmp_dir, "filesync", $collection );

}

1;
