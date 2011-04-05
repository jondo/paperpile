
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


package Paperpile::FileSync;

use Mouse;

use Paperpile;
use Paperpile::Utils;
use Paperpile::Exceptions;
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

  my $target = $self->map->{$collection}->{file};

  ## For now we just dump the content and don't sync

  my $backup = '';

  if ( (-e $target) && (-e $self->_get_dump_file($collection).".info")) {

    my $current_md5 = Paperpile::Utils->calculate_md5($target);
    my ( $old_md5, $old_library_version ) = $self->_get_dump_info($collection);

    if ( $old_md5 ne $current_md5 ) {

      # Add a timestamp for backup copy to avoid overwriting an old backup
      my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
      my $timestamp =
        sprintf( "%4d-%02d-%02d-%02d-%02d-%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec );
      $backup = "$target.$timestamp";

      move( $target, $backup );
    }
  }

  my $data = $self->_get_library_data($collection);
  $self->_write_file( $collection, $data );
  $self->_write_dump( $collection, 0, $data );

  if ($backup) {
    FileSyncConflictError->throw(
      "$target has been changed outside of Paperpile. Saved a backup copy in $backup");
  }

  # If target file does not exist we dump all data to the file
  #if ( !-e $target ) {
  #  my $data = $self->_get_library_data($collection);
  #  $self->_write_file( $collection, $data );
  #  $self->_write_dump( $collection, 0, $data );
  #}
  # Target files already exists, so we need to sync it
  #else {
  #  my $current_md5 = Paperpile::Utils->calculate_md5( $self->map->{$collection} );
  #  my ( $old_md5, $old_library_version ) = $self->_get_dump_info($collection);
  # File has changed since last sync
  #if ( $current_md5 ne $old_md5 ) {
  #  my $current_data = $self->_get_file_data($collection);
  #  my $old_data     = $self->_get_dump_data($collection);
  #}
  #  my $library_diff = $self->_get_library_diff($collection, $old_library_version);
  #  print STDERR Dumper($library_diff);
  #  #print STDERR Dumper($data);
  #  #print "$md5, $old_library_version\n";
  #}
}

sub _get_library_data {

  my ( $self, $collection ) = @_;

  my $model = Paperpile::Utils->get_model("Library");

  my ($dbh, $in_prev_tx) = $model->begin_or_continue_tx;

  my $sth;
  if ( $collection eq 'FOLDER_ROOT' ) {
    $sth = $dbh->prepare("SELECT * FROM Publications WHERE trashed=0;");
  } else {

    my @guids = $model->find_subcollections( $collection );

    map { $_ = "collection_guid='$_'" } @guids;
    my $query = join( " OR ", @guids );

    $sth = $dbh->prepare(
      "SELECT * FROM Publications join Collection_Publication on guid = publication_guid WHERE ($query) AND trashed=0;"
    );
  }

  $sth->execute;

  my %data = ();

  while ( my $row = $sth->fetchrow_hashref() ) {
    my $pub = Paperpile::Library::Publication->new($row);
    $data{ $row->{guid} } = $pub;
  }

  $model->commit_or_continue_tx($in_prev_tx);

  return \%data;

}

sub _get_library_diff {

  my ( $self, $collection, $library_version ) = @_;

  my $model = Paperpile::Utils->get_model("Library");

  my ($dbh, $in_prev_tx) = $model->begin_or_continue_tx;


  # Get new and updated references
  my $sth = $dbh->prepare("SELECT * FROM Publications,Changelog WHERE Publications.guid=Changelog.guid AND counter>$library_version;");

  $sth->execute;

  my %new=();
  my %updated=();

  while ( my $row = $sth->fetchrow_hashref() ) {
    my $change_type = $row->{type};
    delete($row->{type});
    my $pub = Paperpile::Library::Publication->new($row);

    if ($change_type eq 'UDPATED'){
      $updated{$row->{guid}} = $pub;
    } else {
      $new{$row->{guid}} = $pub;
    }
  }

  # Get deleted references
  my @deleted;

  foreach my $row (@{$dbh->selectall_arrayref("SELECT guid FROM Changelog WHERE counter>$library_version AND type='DELETE';")}){
    push @deleted, $row->[0];
  }

  $model->commit_or_continue_tx($in_prev_tx);

  return {new=>\%new, updated=>\%updated, deleted=>\@deleted};

}


sub _get_file_data {

  my ( $self, $collection ) = @_;

  my $file = $self->map->{$collection}->{file};

  my $f = Paperpile::Formats::Bibtex->new( file => $file );

  my %data = ();

  foreach my $pub ( @{ $f->read } ) {
    $pub->create_guid if (!pub->guid);
    $data{ $pub->guid } = $pub;
  }

  return \%data;
}

sub _get_dump_data {

  my ( $self, $collection ) = @_;

  my $file = $self->_get_dump_file($collection);

  open( IN, "<$file.data" ) || die("Could not open $file.data during file sync.");

  my $string = join("", <IN>);

  ( my $dump_object ) = thaw($string);

  return $dump_object;

}



sub _get_dump_info {

  my ( $self, $collection ) = @_;

  my $file = $self->_get_dump_file($collection);

  open( IN, "<$file.info" ) || die("Could not open $file.info during file sync.");

  my $md5             = <IN>;
  my $library_version = <IN>;

  chomp($md5);
  chomp($library_version);

  return ( $md5, $library_version );

}




sub _write_file {

  my ( $self, $collection, $data ) = @_;

  my $file = $self->map->{$collection}->{file};

  my $settings = Paperpile::Utils->get_model("Library")->get_setting('bibtex');

  my $f = Paperpile::Formats::Bibtex->new( file => $file, data => [ values %$data ], settings=>$settings );

  $f->write;

}

sub _write_dump {

  my ( $self, $collection, $library_version, $data ) = @_;

  my $dest = $self->_get_dump_file($collection);

  my $md5 = Paperpile::Utils->calculate_md5( $self->map->{$collection}->{file} );

  open(OUT, ">$dest.info") || die("Could not open to $dest during file sync.");

  print OUT "$md5\n";
  print OUT "$library_version\n";

  open( OUT, ">$dest.data" ) || die("Could not open to $dest during file sync.");
  print OUT freeze($data);

}

sub _get_dump_file {

  my ( $self, $collection ) = @_;
  return catfile( Paperpile::Utils->get_tmp_dir, "filesync", $collection );

}

1;
