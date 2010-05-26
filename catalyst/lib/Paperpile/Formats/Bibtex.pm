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

package Paperpile::Formats::Bibtex;
use Moose;
use Data::Dumper;
use YAML qw(LoadFile);
use BibTeX::Parser;
use IO::File;



extends 'Paperpile::Formats';

sub BUILD {
  my $self = shift;
  $self->format('BIBTEX');
  $self->readable(1);
  $self->writable(1);
}


sub read {

  my ($self) = @_;

  my $fh     = IO::File->new($self->file);

  my $config = LoadFile( Paperpile::Utils->path_to('conf/fields.yaml') );

  my %built_in = ();

  foreach my $field ( keys %{ $config->{pub_fields} } ) {
    $built_in{$field} = 1;
  }

  my @output = ();

  my $parser = BibTeX::Parser->new($fh);

  while (my $entry = $parser->next ) {

    next unless $entry->parse_ok;

    my $data = {};

    foreach my $field (  $entry->fieldlist  ) {
	print STDERR "Field: $field\n";
      if ( $built_in{$field} ) {
        $data->{$field} = $entry->field($field);
      }

      if ( $field eq 'author' || $field eq 'editor' ) {

        my @names;

        if ($field eq 'author'){
          @names = $entry->author;
        } else {
          @names = $entry->editor;
        }

        my @normalized = ();

        foreach my $name (@names) {

          my $von   = $name->von;
          my $last  = $name->last || "";
          my $jr    = $name->jr;
          my $first = $name->first || "";

          my $output = '';

          $output .= $von . " " if ($von);
          $output .= $last . ", ";
          $output .= $jr . ", " if ($jr);
          $output .= $first;

          push @normalized, $output;
        }
        my $final = join( " and ", @normalized );

        if ($field eq 'author'){
          $data->{authors} = $final;
        }

        if ($field eq 'editor'){
          $data->{editors} = $final;
        }
      }
    }

    $data->{_light}=1;
    $data->{_auto_refresh}=0;

    push @output, Paperpile::Library::Publication->new($data);

  };

  return [@output];

}



1;

