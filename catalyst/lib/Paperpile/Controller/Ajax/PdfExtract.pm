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


package Paperpile::Controller::Ajax::PdfExtract;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Paperpile::Queue;
use Paperpile::Job;
use Data::Dumper;
use File::Find;
use File::Path;

sub submit : Local {

  my ( $self, $c ) = @_;

  my $path             = $c->request->params->{path};
  my @collection_guids = $c->request->param('collection_guids');

  ## Get all PDFs in all subdirectories

  my @files = ();

  if ( -d $path ) {
    find(
      sub {
        my $name = $File::Find::name;
        push @files, $name if $name =~ /\.pdf$/i;
      },
      $path
    );
  } else {
    push @files, $path;
  }

  my $q = Paperpile::Queue->new();

  my @jobs = ();

  foreach my $file (@files) {

    # Use the pdf field to set the file (this normally holds the guid
    # of an already imported PDF)
    my $pub = Paperpile::Library::Publication->new( { pdf => $file } );

    my $job = Paperpile::Job->new( {
        type              => 'PDF_IMPORT',
        pub               => $pub,
        _collection_guids => \@collection_guids
      }
    );

    push @jobs, $job;

  }

  $q->submit( \@jobs );

  $q->save;
  $q->run;

  $c->stash->{data}->{job_delta} = 1;
}

sub count_files : Local {

  my ( $self, $c ) = @_;

  my $path = $c->request->params->{path};

  ## Get all PDFs in all subdirectories

  my @files = ();

  if ( -d $path ) {
    find(
      sub {
        my $name = $File::Find::name;
        push @files, $name if $name =~ /\.pdf$/i;
      },
      $path
    );
  } else {
    push @files, $path;
  }

  $c->stash->{count} = scalar @files;

}

1;
