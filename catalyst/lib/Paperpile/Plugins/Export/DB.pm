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


package Paperpile::Plugins::Export::DB;

use Moose;
use Moose::Util::TypeConstraints;
use Data::Dumper;
use 5.010;

use File::Copy;
use Paperpile::Utils;
use Paperpile::Model::User;
use Paperpile::Plugins::Import::DB;

extends 'Paperpile::Plugins::Export';

# Supported settings:

# export_file
# export_include_pdfs
# export_include_attachments

sub write {

  my ($self) = @_;

  my $dbfile = $self->settings->{out_file};

  # First initialize with empty database file
  my $empty_db = Paperpile::Utils->path_to('db/library.db')->stringify;

  copy( $empty_db, $dbfile ) or FileWriteError->throw( error => "Could not write $dbfile." );

  my $model = Paperpile::Model::Library->new();
  $model->set_dsn( "dbi:SQLite:" . $dbfile );

  foreach my $pub ( @{ $self->data } ) {
    $pub->pdf(undef);
  }

  $model->insert_pubs( $self->data );

}

1;
