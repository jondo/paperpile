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


package Paperpile::Plugins::Export::Bibfile;

use Mouse;
use Data::Dumper;
use 5.010;

extends 'Paperpile::Plugins::Export';

sub write {
  my ( $self, $write_string ) = @_;

  my $format = $self->settings->{out_format};
  $format = lc($format);
  $format = ucfirst($format);

  my $module = "Paperpile::Formats::$format";

  my $writer = eval("use $module; $module->new()");

  $writer->file( $self->settings->{out_file} ) if ( defined $self->settings->{out_file} );
  $writer->settings( $self->settings );
  $writer->data( $self->data );

  if ($write_string) {
    my $str = $writer->write_string();
    return $str;
  } else {
    $writer->write();
  }
}

1;
