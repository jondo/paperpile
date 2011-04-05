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


package Paperpile::Migrate;
use Mouse;

use DBI;
use Data::Dumper;
use File::Copy;
use File::Spec::Functions qw(catfile splitpath);
use Data::GUID;
use File::Path qw(rmtree);
use File::stat;

use Paperpile;
use Paperpile::Library::Publication;

# The version numbers of the current installation
has app_library_version  => ( is => 'rw' );
has app_settings_version => ( is => 'rw' );

# The files to be migrated
has library_db  => ( is => 'rw' );
has settings_db => ( is => 'rw' );

# The path to the 'tmp' dir that holds temporary information and may
# need to be resetted/updated together with a db_update
has tmp_dir => ( is => 'rw' );

# The default settings of the current version
has library_settings => ( is => 'rw' );
has user_settings => ( is => 'rw' );

sub get_dbh {

  my ( $self, $file ) = @_;

  my $dbh = DBI->connect( "dbi:SQLite:$file", '', '', { AutoCommit => 1, RaiseError => 1 } );

  return $dbh;
}

sub migrate {

  my ( $self, $what ) = @_;

  # Get version number required for current installation and the
  # actual version number of the database file
  my $file = $what eq 'library' ? $self->library_db : $self->settings_db;
  my $dbh = $self->get_dbh($file);
  ( my $version ) = $dbh->selectrow_array("SELECT value FROM Settings WHERE key='db_version' ");
  my $app_version = $what eq 'library' ? $self->app_library_version : $self->app_settings_version;

  # We are up-to-date and don't have to do anyting
  if ( $app_version == $version ) {
    return;
  }

  # Call lift function for each version step
  for my $x ( $version .. $app_version - 1 ) {
    my $y    = $x + 1;
    my $lift = "lift_$what\_$x\_$y";
    $self->$lift;
  }
}

## Add a new column and fix sha1s

sub lift_library_1_2 {

  my ($self) = @_;

  $self->backup_library_file();

  my $dbh = $self->get_dbh( $self->library_db );

  $dbh->begin_work;

  eval {

    ### Add new column to tag table
    $dbh->do("ALTER TABLE tags ADD COLUMN sort_order INTEGER");

    ### Fill new sort_order values
    my $sth = $dbh->prepare("SELECT rowid FROM tags;");

    my $rowid;
    $sth->bind_columns( \$rowid );
    $sth->execute;

    my $counter = 0;

    while ( $sth->fetch ) {
      $dbh->do("UPDATE Tags SET sort_order=$counter WHERE rowid=$rowid");
      $counter++;
    }

    ### Make sure every entry has a correct sha1 (there was a bug so
    ### some entries did not get a sha1 stored in the database)
    $self->update_sha1s($dbh);

    ### If we made it here, we can update the database version
    $dbh->do("UPDATE Settings SET value=2 WHERE key='db_version'");

  };

  if ($@) {
    $dbh->rollback;
    die("Error while updating library: $@");
  }

  $dbh->commit;

}

sub lift_settings_1_2 {

  my ($self) = @_;

  my $dbh = $self->get_dbh( $self->settings_db );

  # Add new settings
  foreach my $new_setting ('zoom_level','split_fraction_tree','split_fraction_grid'){
    Paperpile::Model::Library->set_setting($new_setting, $self->user_settings->{$new_setting}, $dbh);
  }

  # Drop unused settings
  $dbh->do("DELETE FROM SETTINGS WHERE key='_queue';");

  # Update database version number
  $dbh->do("UPDATE SETTINGS SET value='2' WHERE key='db_version';");

}


sub lift_library_2_3 {

  my ($self) = @_;

  # Reset all temporary data by deleting all folders in "tmp"
  foreach my $dir ( 'rss', 'import', 'download', 'queue' ) {
    rmtree( catfile( $self->tmp_dir, $dir ) );
  }
  unlink( catfile( $self->tmp_dir, 'queue.db' ) );

  ### Backup old library file and get database handle

  copy( $self->library_db, $self->library_db . ".backup" )
    or die("Could not backup library file. Aborting migration ($!)");

  my $dbh_old = $self->get_dbh( $self->library_db . ".backup" );

  ### Initialize empty database from template and get handle

  my ( $volume, $dirs, $base_name ) = splitpath( $self->library_db );
  copy( Paperpile->path_to('db/library.db')->stringify, catfile( $dirs, $base_name ) )
    or die("Error initializing new database. Aborting migration ($!)");

  my $dbh_new = $self->get_dbh( $self->library_db );

  $dbh_new->do('BEGIN EXCLUSIVE TRANSACTION');

  eval {

    my ( $fields, $values );

    ( my $paper_root ) =
      $dbh_old->selectrow_array("SELECT value FROM Settings WHERE key='paper_root'");

    my $sth = $dbh_old->prepare("SELECT *, rowid as _rowid FROM Publications;");
    $sth->execute;

    my %rowid_to_guid;

    while ( my $old_data = $sth->fetchrow_hashref() ) {

      my $pub = Paperpile::Library::Publication->new($old_data);
      $pub->create_guid;
      $pub->labels(undef);

      $rowid_to_guid{ $old_data->{_rowid} } = $pub->guid;

      ### Handle PDF attachments

      if ( $old_data->{pdf} ) {
        my $file = catfile( $paper_root, $old_data->{pdf} );
        my $stats = $self->_attachments_stats($file);
        $stats->{publication} = $pub->guid;
        $stats->{is_pdf}      = 1;
        $stats->{name}        = $old_data->{pdf};
        $stats->{name} =~ s/^(.*\/)(.*)$/$2/;
        ( $fields, $values ) = $self->_hash2sql( $stats, $dbh_new );
        $dbh_new->do("INSERT INTO Attachments ($fields) VALUES ($values)");

        $pub->pdf( $stats->{guid} );
        $pub->pdf_name( $old_data->{pdf} );
      }

      ### Handle other attachments

      if ( $old_data->{attachments} > 0 ) {

        my $rowid = $old_data->{_rowid};

        my $sth1 = $dbh_old->prepare("SELECT * FROM Attachments WHERE publication_id=$rowid;");
        $sth1->execute;

        my @guids;

        while ( my $attachments = $sth1->fetchrow_hashref() ) {
          my $file = catfile( $paper_root, $attachments->{file_name} );
          my $stats = $self->_attachments_stats($file);
          $stats->{publication} = $pub->guid;
          $stats->{is_pdf}      = 0;
          $stats->{name}        = $attachments->{file_name};
          $stats->{name} =~ s/^(.*\/)(.*)$/$2/;
          ( $fields, $values ) = $self->_hash2sql( $stats, $dbh_new );
          $dbh_new->do("INSERT INTO Attachments ($fields) VALUES ($values)");
          push @guids, $stats->{guid};
        }

        $pub->attachments( join( ',', @guids ) );

      } else {
        $pub->attachments(undef);
      }

      ### Insert into main Publication table

      ( $fields, $values ) = $self->_hash2sql( $pub->as_hash(), $dbh_new );

      $dbh_new->do("INSERT INTO Publications ($fields) VALUES ($values)");

      my $pub_rowid = $dbh_new->func('last_insert_rowid');

      ### Insert into Fulltext table

      my $ft = $dbh_old->selectrow_hashref("SELECT * FROM Fulltext_full WHERE rowid=$pub_rowid");

      $ft->{rowid} = $pub_rowid;
      $ft->{guid}  = $pub->guid;

      delete( $ft->{folder} );
      delete( $ft->{label} );
      delete( $ft->{folderid} );
      delete( $ft->{labelid} );

      ( $fields, $values ) = $self->_hash2sql( $ft, $dbh_new );

      $dbh_new->do("INSERT INTO Fulltext ($fields) VALUES ($values)");

    }

    ### Handle Tags

    $sth = $dbh_old->prepare("SELECT *, rowid FROM Tags ORDER BY sort_order;");
    $sth->execute;

    my $sort_order = 0;

    my %tagrowid_to_tagguid;

    while ( my $tag = $sth->fetchrow_hashref() ) {

      my $guid = Data::GUID->new->as_hex;
      $guid =~ s/^0x//;
      my $style = $tag->{style};
      my $name  = $dbh_new->quote( $tag->{tag} );

      $dbh_new->do(
        "INSERT INTO Collections (guid, name, type, parent, sort_order, style) VALUES ('$guid',$name,'LABEL','ROOT', $sort_order, $style)"
      );

      $tagrowid_to_tagguid{ $tag->{rowid} } = $guid;

      $sort_order++;
    }

    $sth = $dbh_old->prepare("SELECT * FROM Tag_Publication;");
    $sth->execute;

    my %tags;

    while ( my $link = $sth->fetchrow_hashref() ) {

      my $pub_guid = $rowid_to_guid{ $link->{publication_id} };
      my $tag_guid = $tagrowid_to_tagguid{ $link->{tag_id} };

      # Some databases seem to be corrupted and the publication entry
      # referenced in the tag_publication table does not exist any
      # more
      next if ( !$pub_guid or !$tag_guid );

      if ( !exists $tags{$pub_guid} ) {
        $tags{$pub_guid} = [$tag_guid];
      } else {
        push @{ $tags{$pub_guid} }, $tag_guid;
      }

      $dbh_new->do(
        "INSERT INTO Collection_Publication (collection_guid, publication_guid) VALUES ('$tag_guid','$pub_guid') "
      );
    }

    foreach my $pub_guid ( keys %tags ) {
      my $list = join( ',', @{ $tags{$pub_guid} } );
      $dbh_new->do("UPDATE Publications SET labels='$list' WHERE guid = '$pub_guid'");
      $dbh_new->do("UPDATE Fulltext SET labelid='$list' WHERE guid = '$pub_guid'");
    }

    ### Handle Folders

    my $tree = Paperpile::Model::Library->get_setting( '_tree', $dbh_old );

    my @folders;

    # Tree might be empty if user has not changed anything
    if ($tree) {
      $tree->traverse(
        sub {
          my ($_tree) = @_;
          my $params = $_tree->getNodeValue();
          return if $params->{type} ne 'FOLDER';
          return if $params->{text} eq 'All Papers';

          my $id     = $params->{id};
          my $name   = $params->{text};
          my $parent = $_tree->getParent;

          my $parent_id;

          if ( ( !defined $parent->getNodeValue->{id} )
            && ( $parent->getNodeValue->{path} eq '/' ) ) {
            $parent_id = 'ROOT';
          } else {
            $parent_id = $parent->getNodeValue->{id};
          }

          push @folders, { name => $name, id => $id, parent_id => $parent_id };
        }
      );
    }

    my %folderid_to_folder_guid = ( ROOT => 'ROOT' );

    foreach my $folder (@folders) {
      my $guid = Data::GUID->new->as_hex;
      $guid =~ s/^0x//;
      $folder->{guid} = $guid;
      $folderid_to_folder_guid{ $folder->{id} } = $guid;
    }

    my %sort_order_by_parent;
    foreach my $folder (@folders) {
      $sort_order_by_parent{ $folderid_to_folder_guid{ $folder->{parent_id} } } = 0;
    }

    foreach my $folder (@folders) {
      my $name   = $dbh_new->quote( $folder->{name} );
      my $guid   = $folder->{guid};
      my $parent = $folderid_to_folder_guid{ $folder->{parent_id} };

      my $sort_order = $sort_order_by_parent{$parent}++;

      $dbh_new->do(
        "INSERT INTO Collections (guid, name, type, parent, sort_order, style) VALUES ('$guid',$name,'FOLDER','$parent', $sort_order, 0)"
      );

    }

    $sth = $dbh_new->prepare("SELECT guid, folders FROM Publications WHERE Folders !=''");
    $sth->execute;

    while ( my $row = $sth->fetchrow_hashref() ) {

      my $guid = $row->{guid};
      my @old_folders = split( /,/, $row->{folders} );

      my @new_folders;

      foreach my $old_folder (@old_folders) {
        push @new_folders, $folderid_to_folder_guid{$old_folder};
      }

      my $folders = join( ',', @new_folders );

      $dbh_new->do("UPDATE Publications SET Folders='$folders' WHERE guid='$guid'");
      $dbh_new->do("UPDATE Fulltext SET folderid='$folders' WHERE guid='$guid'");
    }

    ### Migrate Library settings

    my $old_settings = Paperpile::Model::Library->settings($dbh_old);
    my $new_settings = $self->library_settings;

    # We take the new defaults for '_tree', 'bibtex' and db_version and
    # take old settings for all other fields:
    foreach
      my $key ( 'attachment_pattern', 'key_pattern', 'pdf_pattern', 'paper_root', 'search_seq' ) {
      $new_settings->{$key} = $old_settings->{$key};
    }

    Paperpile::Model::Library->set_settings( $self->library_settings, $dbh_new );

  };

  if ($@) {
    $dbh_new->rollback;

    # Copy old file back from backup
    copy( $self->library_db . ".backup", $self->library_db );
    unlink( $self->library_db . ".backup" );
    die("Error while updating library: $@");
  }

  $dbh_new->commit;

}





sub backup_library_file {

  my ($self) = @_;

  copy( $self->library_db, $self->library_db . ".backup" )
    or die("Could not backup library file. Aborting migration ($!)");

}

# Make sha1s stored in database consistent with current sha1
# function. Originally written to fix sha1 bug in 0.4.2 but can be
# re-used whenever the sha1 function changes.

sub update_sha1s {

  my ($self, $dbh) = @_;

  my $sth = $dbh->prepare("SELECT rowid, * FROM Publications;");

  $sth->execute;

  my %sha1_seen;

  while ( my $row = $sth->fetchrow_hashref() ) {

    my $data = {};

    foreach my $key ( keys %$row ) {

      next if $key eq 'sha1';

      my $value = $row->{$key};

      if ( defined $value and $value ne '' ) {
        $data->{$key} = $value;
      }
    }

    my $rowid = $row->{rowid};
    my $pub   = Paperpile::Library::Publication->new($data);

    my $updated_sha1 = $pub->sha1;

    my $new_title = undef;

    # In the *very* unlikely case that our new sha1 function produces
    # duplicates for entries that were different before, we force them
    # to be different by adding a random number to the title
    if ($sha1_seen{$updated_sha1}){
      $data->{title}= $data->{title} . " " . int(rand(100));
      $new_title = $data->{title};
      $pub   = Paperpile::Library::Publication->new($data);
      $updated_sha1 = $pub->sha1;
    }

    if ($updated_sha1 ne $row->{sha1}){
      $dbh->do("UPDATE Publications SET sha1='$updated_sha1' WHERE rowid=$rowid");
      # Also update the new title when it was changed
      if ($new_title){
        $dbh->do("UPDATE Publications SET title='$new_title' WHERE rowid=$rowid");
      }
    }

    $sha1_seen{$updated_sha1}=1;

  }
}


sub _hash2sql {

  ( my $self, my $hash, my $dbh ) = @_;

  my @fields = ();
  my @values = ();

  foreach my $key ( keys %{$hash} ) {

    my $value = $hash->{$key};

    # ignore fields starting with underscore
    # They are not stored to the database by convention
    next if $key =~ /^_/;

    if (($key ne 'trashed') && ($key ne 'last_read') && 
        ($key ne 'times_read') && ($key ne 'created')){
      $value ='' if not defined $value;
    } else {
      next if not defined $value;
    }

    push @fields, $key;

    if ( $value eq '' ) {
      push @values, "''";
    } else {
      push @values, $dbh->quote($value);
    }
  }

  my @output = ( join( ',', @fields ), join( ',', @values ) );

  return @output;
}

sub _attachments_stats {

  my ($self, $file) = @_;

  my $output = {};

  $output->{guid} = Data::GUID->new->as_hex;
  $output->{guid} =~ s/^0x//;
  $output->{size} = stat($file)->size;
  $output->{md5} = Paperpile::Utils->calculate_md5($file);
  $output->{local_file} = $file;

  return $output;

}

1;
