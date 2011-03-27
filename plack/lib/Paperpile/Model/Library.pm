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

package Paperpile::Model::Library;

use strict;
use base 'Paperpile::Model::SQLite';
use Data::Dumper;
use Tree::Simple;
use XML::Simple;
use FreezeThaw qw/freeze thaw/;
use File::Path;
use File::Spec::Functions qw(catfile splitpath canonpath abs2rel);
use File::Copy;
use File::Copy::Recursive qw(dirmove);
use File::stat;
use Mouse;
use Encode qw(encode decode);
use File::Temp qw/tempfile tempdir /;
use Data::GUID;

use Paperpile::Utils;
use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Paperpile::Model::App;



has 'light_objects' => ( is => 'rw', isa => 'Int', default => 0 );

#sub build_per_context_instance {
#  my ( $self, $c ) = @_;
#  my $file = Paperpile::Utils->session($c)->{library_db};
#  my $model = Paperpile::Model::Library->new( { file => $file } );

#  return $model;
#}


# Inserts a list $pubs of publication objects into the database. If
# $user_library=1, we treat this as *the* library, i.e. we generate
# citation keys and import attachments.

sub insert_pubs {

  ( my $self, my $pubs, my $user_library ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  # First make sure all objects have a guid
  foreach my $pub (@$pubs) {
    if ( !$pub->guid ) {
      $pub->create_guid;
    }
  }

  # Generate unique keys taking into accounts keys already in the
  # database and the pubs about to be imported now.
  if ($user_library) {
    my @existing;
    foreach my $pub (@$pubs) {
      # For now we ignore pre-set keys and always generate our own keys on insert
      $pub->citekey(undef);
      my $key = $self->generate_unique_key( $pub, \@existing);
      push @existing, $key;
    }
  }

  # Check already existing pubs to avoid sha1 clashes
  $self->exists_pub( $pubs );

  # If we insert to the user library we need to create new labels that
  # may be given in the labels_tmp field.
  my $label_map;
  my @pubs_with_labels;
  if ($user_library) {
    $label_map = $self->insert_labels( $pubs );
  }

  foreach my $pub (@$pubs) {
    $pub->created(Paperpile::Utils->gm_timestamp) if not $pub->created;

    if ( $pub->_imported ) {
      $pub->_insert_skipped(1);
      print STDERR $pub->sha1, " already exists. Skipped.\n";
      next;
    } elsif ($user_library) {
      # If it is the user library we mark all as imported
      $pub->_imported(1);
    }

    # Sanity check. Should not come to this point without sha1 but we
    # had an error like this and that could have prevented a corrupted
    # database
    next if ( !$pub->sha1 );

    # If we insert to the user library map temporary labels to new or
    # already existing labels in the database. If it is not the user
    # libary we save the labels_tmp field upon insert.
    if ( $user_library && $pub->labels_tmp ) {
      my @guids;
      my %seen; # Make sure that the same label does not occur twice in labels_tmp
      foreach my $label ( split( /\s*,\s*/, $pub->labels_tmp ) ) {
        if ( $label_map->{$label} && !$seen{$label} ) {
          push @guids, $label_map->{$label};
          $seen{$label} = 1;
        }
      }
      $pub->labels( join( ',', @guids ) );
      $pub->labels_tmp('');
      push @pubs_with_labels, $pub;
    }

    # If imported with attachments from another database the
    # attachments should be stored in _attachments_tmp and the guids
    # from the old temporary database are discarded
    $pub->attachments('');

    ## Insert main entry into Publications table
    my $tmp = $pub->as_hash();

    ( my $fields, my $values ) = $self->_hash2sql( $tmp );

    $dbh->do("INSERT INTO publications ($fields) VALUES ($values)");

    ## Insert searchable fields into fulltext table
    my $pub_rowid = $dbh->func('last_insert_rowid');
    $pub->_rowid($pub_rowid);

    $self->_update_fulltext_table( $pub, 1 );

    ## Attach PDFs either if it is downloaded already in the cache or
    ## it is given as absolute path in the _pdf_tmp field
    my $cached_file = catfile( Paperpile::Utils->get_tmp_dir, "download", $pub->guid . ".pdf" );

    if ( $user_library && -e $cached_file ) {
      $pub->_pdf_tmp($cached_file);
    }

    if ( $pub->_pdf_tmp ) {
      $self->attach_file( $pub->_pdf_tmp, 1, $pub, 0 );
    }

    # Attach other attachments if given in _attachments_tmp field
    if ( @{ $pub->_attachments_tmp } > 0 ) {
      foreach my $file ( @{ $pub->_attachments_tmp } ) {
        $self->attach_file( $file, 0, $pub, 0  );
      }
    }

    if ( $pub->_incomplete ) {
      $self->_flag_as_incomplete( $pub );
    }
  }

  $self->update_collections( \@pubs_with_labels, 'LABEL' );

  $self->commit_or_continue_tx($in_prev_tx);

}

# Delete a list of publication objects $pubs from the database.

sub delete_pubs {

  ( my $self, my $pubs ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  # Delete attachments
  foreach my $pub (@$pubs) {

    # PDF
    $self->delete_attachment( $pub->pdf, 1, $pub, 0  ) if $pub->pdf;

    # Other files
    foreach my $guid ( split( ',', $pub->attachments || '' ) ) {
      $self->delete_attachment( $guid, 0, $pub, 0 );
    }
  }

  # Then delete the entry in all relevant tables
  my $delete_main     = $dbh->prepare("DELETE FROM Publications WHERE rowid=?");
  my $delete_fulltext = $dbh->prepare("DELETE FROM Fulltext WHERE rowid=?");
  my $delete_collections =
    $dbh->prepare("DELETE FROM Collection_Publication WHERE publication_guid=?");

  foreach my $pub (@$pubs) {
    my $rowid = $pub->_rowid;
    $delete_main->execute($rowid);
    $delete_fulltext->execute($rowid);

    if ( $pub->labels or $pub->folders ) {
      my $guid = $pub->guid;
      $delete_collections->execute($guid);
    }

  }

  $self->commit_or_continue_tx($in_prev_tx);

}

# Update the trash status of $pubs. If $mode is TRASH they will be
# flagged as trashed and attachments are moved to Trash folder. If
# $mode is RESTORE they will be flagged as active and attachments are
# moved back to original place.

sub trash_pubs {

  ( my $self, my $pubs, my $mode ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my $paper_root = $self->get_setting( 'paper_root');

  # Flag trashed citation keys with trash_*. Mainly to avoid
  # that they are considered during disambiguation of keys
  if ( $mode eq 'TRASH' ) {
    foreach my $pub (@$pubs) {
      $pub->citekey( 'trash_' . $pub->citekey );
    }
  } else {

    # Remove trash_* flag again. Call generate_unique_key to make sure
    # it is still unique and update if necessary
    my @existing = ();
    foreach my $pub (@$pubs) {
      my $key = $pub->citekey;
      $key =~ s/^trash_//;
      $pub->citekey($key);
      $key = $self->generate_unique_key( $pub, \@existing );
      $pub->citekey($key);
      push @existing, $key;
    }
  }

  my @files = ();

  # currently no explicit error handling/rollback etc.

  foreach my $pub (@$pubs) {
    my $pub_guid = $pub->guid;

    my $status = 1;
    $status = 0 if $mode eq 'RESTORE';

    # The field 'created' is used to store time of import as well as time of
    # deletion, so we set it everytime we trash or restore something
    my $now = $dbh->quote(Paperpile::Utils->gm_timestamp);
    my $key = $dbh->quote( $pub->citekey );

    $dbh->do(
      "UPDATE Publications SET trashed=$status,created=$now, citekey=$key WHERE guid='$pub_guid'");
    $dbh->do("UPDATE Fulltext SET key=$key WHERE guid='$pub_guid'");

    # Move attachments
    my $select = $dbh->prepare(
      "SELECT guid, local_file, is_pdf FROM Attachments WHERE publication='$pub_guid';");

    my $attachment_guid;
    my $file_absolute;
    my $is_pdf;

    $select->bind_columns( \$attachment_guid, \$file_absolute, \$is_pdf );
    $select->execute;
    while ( $select->fetch ) {
      my $rel_path;
      my $abs_path;
      my $file_relative = abs2rel( $file_absolute, $paper_root );
      if ( $mode eq 'TRASH' ) {
        $rel_path = catfile( "Trash",     $file_relative );
        $abs_path = catfile( $paper_root, $rel_path );
      } else {
        $rel_path = $file_relative;
        $rel_path =~ s/Trash.//;
        $abs_path = catfile( $paper_root, $rel_path );
      }
      push @files, [ $file_absolute, $abs_path ];
      $abs_path = $dbh->quote($abs_path);
      $rel_path = $dbh->quote($rel_path);

      $dbh->do("UPDATE Attachments SET local_file=$abs_path WHERE guid='$attachment_guid';");

      if ($is_pdf) {
        $pub->pdf_name($rel_path);
        $dbh->do("UPDATE Publications SET pdf_name=$rel_path WHERE guid='$pub_guid';");
      }
    }
  }

  foreach my $pair (@files) {

    ( my $from, my $to ) = @$pair;

    my ( $volume, $dir, $file_name ) = splitpath($to);

    mkpath($dir);
    move( $from, $to );

    ( $volume, $dir, $file_name ) = splitpath($from);

    # Never remove the paper_root even if its empty;
    if ( canonpath($paper_root) ne canonpath($dir) ) {

      # Simply remove it; will not do any harm if it is not empty; Did
      # not find an easy way to check if dir is empty, but it does not
      # seem necessary anyway TODO: recursively remove empty
      # directories, currently only one level is deleted
      rmdir $dir;
    }
  }

  $self->commit_or_continue_tx($in_prev_tx);

}

# Updates the publication with $guid with the new data in hashref
# $new_data. Takes care to update citation keys and location of PDFs
# and attachments.

sub update_pub {

  ( my $self, my $guid, my $new_data ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my $settings = $self->settings;

  my $old_data = $dbh->selectrow_hashref(
    "SELECT *, rowid as _rowid, 1 as _imported FROM Publications WHERE guid='$guid'");

  my $data = {%$old_data};
  my $diff = {};

  # Figure out fields that have changed
  foreach my $field ( keys %{$new_data} ) {
    next if ( !$new_data->{$field} && !$data->{$field} );
    if ( !defined $data->{$field} || $new_data->{$field} ne $data->{$field} ) {
      $diff->{$field} = $new_data->{$field};
    }
    $data->{$field} = $new_data->{$field};
  }

  # Create pub object with updated data
  my $new_pub = Paperpile::Library::Publication->new($data);
  $new_pub->_db_connection( $self->file );

  # Also update sha1
  if ( $new_pub->sha1 ne $old_data->{sha1} ) {
    $diff->{sha1} = $new_pub->sha1;

    # If sha1 has changed we check if the new sha1 already exists in
    # the database to avoid duplicates
    $self->exists_pub( [$new_pub]);
    if ( $new_pub->_imported ) {
      DuplicateError->throw("Updates duplicate an existing reference in the database");
    } else {
      $new_pub->_imported(1);
    }
  }

  # Check if the citekey has changed.
  my $pattern = $self->get_setting( 'key_pattern');
  my $new_key = $new_pub->format_pattern($pattern);

  # Note: In case case a ref. Smith2000a is to be updated "$new_key"
  # will be Smith2000 and we will enter the block. The result might be
  # that Smith2000a is changed back to Smith2000 if the other
  # Smith2000 is no longer in the database. Also make sure that key is
  # generated if citekey is empty
  if ( ($new_key ne $old_data->{citekey}) || ((exists $diff->{citekey}) && ($diff->{citekey} eq '')) ) {
    $new_pub->citekey($new_key);

    # If we have a new citekey, make sure it doesn't conflict with other
    $self->generate_unique_key( $new_pub, []);
    $diff->{citekey} = $new_pub->citekey;
  }

  # If flagged with label 'Incomplete' remove this label during update
  # when at least authors/editors and title are given.
  if ( ( $new_pub->authors || $new_pub->editors ) && $new_pub->title ) {
    $self->_flag_as_complete( $new_pub );
  }

  # If we have attachments we need to check if their names have
  # changed because of the update and if so move them to the new place
  if ( $new_pub->{pdf} || $new_pub->{attachments} ) {
    my $sth = $dbh->prepare("SELECT * FROM Attachments WHERE publication='$guid';");
    $sth->execute;

    while ( my $row = $sth->fetchrow_hashref() ) {

      my $old_file = $row->{local_file};

      my $relative;

      if ( $row->{is_pdf} ) {
        $relative =
          $new_pub->format_pattern( $settings->{pdf_pattern}, { key => $new_pub->citekey } )
          . ".pdf";
        $diff->{pdf_name} = $relative;
        $new_pub->pdf_name($relative);
      } else {
        $relative =
          $new_pub->format_pattern( $settings->{attachment_pattern}, { key => $new_pub->citekey } );
        $relative = catfile( $relative, $row->{name} );
      }

      my $new_file = catfile( $settings->{paper_root}, $relative );

      if ( $new_file ne $old_file ) {
        my ( $volume, $dir, $file_name ) = splitpath($new_file);
        my $f               = $dbh->quote($new_file);
        my $ff              = $dbh->quote($file_name);
        my $attachment_guid = $row->{guid};
        $dbh->do("UPDATE Attachments SET local_file=$f, name=$ff WHERE guid='$attachment_guid';");

        if ( $row->{is_pdf} ) {
          $f = $dbh->quote( $new_pub->pdf_name );
          $dbh->do("UPDATE Publications SET pdf_name=$f WHERE guid='$guid';");
        }

        mkpath($dir);
        move( $old_file, $new_file );
        ( $volume, $dir, $file_name ) = splitpath($old_file);

        if ( canonpath( $settings->{paper_root} ) ne canonpath($dir) ) {
          rmdir $dir;
        }
      }
    }
  }

  my @update_list;

  foreach my $field ( keys %{$diff} ) {
    next if ( $field =~ m/_/ );
    push @update_list, "$field=" . $dbh->quote( $diff->{$field} );
  }
  my $sql = join( ',', @update_list );

  if ( scalar @update_list > 0 ) {
    $dbh->do("UPDATE Publications SET $sql WHERE guid='$guid';");
  }

  $self->_update_fulltext_table( $new_pub, 0 );

  $self->commit_or_continue_tx($in_prev_tx);

  return $new_pub;
}

sub update_note {

  ( my $self, my $guid, my $html ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my $value = $dbh->quote($html);

  $dbh->do("UPDATE Publications SET annote=$value WHERE guid='$guid'");

  my $tree      = HTML::TreeBuilder->new->parse_content($html);
  my $formatter = HTML::FormatText->new( leftmargin => 0, rightmargin => 72 );
  my $text      = $formatter->format($tree);

  $value = $dbh->quote($text);

  $dbh->do("UPDATE Fulltext SET notes=$value WHERE guid='$guid'");

  $self->commit_or_continue_tx($in_prev_tx);

}

sub update_citekeys {

  ( my $self, my $pattern ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my $data = $self->all('created');

  my %seen = ();

  eval {

    foreach my $pub (@$data) {
      my $key = $pub->format_pattern($pattern);

      if ( !exists $seen{$key} ) {
        $seen{$key} = 1;
      } else {
        $seen{$key}++;
      }

      if ( $seen{$key} > 1 ) {
        $key .= chr( ord('a') + $seen{$key} - 2 );
      }

      $key = $dbh->quote($key);

      $dbh->do( "UPDATE Publications SET citekey=$key WHERE rowid=" . $pub->_rowid );
    }

    my $_pattern = $dbh->quote($pattern);
    $dbh->do("UPDATE Settings SET value=$_pattern WHERE key='key_pattern'");

  };

  if ($@) {
    die("Failed to update citation keys ($@)");
    $self->rollback_transaction;
  }

  $self->commit_or_continue_tx($in_prev_tx);

}

sub inc_read_counter {

  my ( $self, $guid ) = @_;

  my $touched = Paperpile::Utils->gm_timestamp;

  my ( $dbh, $in_prev_tx ) = $self->begin_or_continue_tx;

  $dbh->do(
    "UPDATE Publications SET times_read=times_read+1,last_read='$touched' WHERE guid='$guid'");

  ( my $times_read ) =
    $dbh->selectrow_array("SELECT times_read FROM Publications WHERE guid='$guid'");

  $self->commit_or_continue_tx($in_prev_tx);

  return ($times_read, $touched);

}


# Find publication with PDF of a given md5. Returns publication object
# or undef if not found.

sub lookup_pdf {

  my ($self, $md5) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my $data = $dbh->selectrow_hashref(
    "SELECT Publications.rowid as rowid, Publications.guid as guid, * FROM Publications, Attachments WHERE Publications.guid=Attachments.publication AND md5='$md5' AND is_pdf;"
  );

  $self->commit_or_continue_tx($in_prev_tx);

  if ($data){
    my $pub = Paperpile::Library::Publication->new($data);
    $pub->_imported(1);
    return $pub;
  } else {
    return undef;
  }
}




# Creates a new collection with $guid and name $name. $type is either
# 'LABEL' or 'FOLDER'. $parent is the guid of the parent collection
# and $style is a number for the predefined style (only for labels at
# the moment).

sub new_collection {

  my ( $self, $guid, $name, $type, $parent, $style) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  if ( $parent =~ /ROOT/ ) {
    $parent = 'ROOT';
  }

  $guid   = $dbh->quote($guid);
  $name   = $dbh->quote($name);
  $type   = $dbh->quote($type);
  $parent = $dbh->quote($parent);
  $style  = $dbh->quote($style);
  my $hidden = $dbh->quote(0);

  ( my $sort_order ) = $dbh->selectrow_array(
    "SELECT max(sort_order) FROM Collections WHERE parent=$parent AND type=$type");

  if ( defined $sort_order ) {
    $sort_order++;
  } else {
    $sort_order = 0;
  }

  $dbh->do(
    "INSERT INTO Collections (guid, name, type, parent, sort_order, style, hidden) VALUES($guid, $name, $type, $parent, $sort_order, $style, $hidden)"
  );

  $self->commit_or_continue_tx($in_prev_tx);

}

# Delete the collection with $guid of $type (FOLDER or LABEL) and all
# sub-collections below.

sub delete_collection {
  ( my $self, my $guid, my $type ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my @list = $self->find_subcollections( $guid );

  #  Delete all assications in Collection_Publication table
  my $delete1 = $dbh->prepare("DELETE FROM Collection_Publication WHERE collection_guid=?");

  #  Delete folders from Folders table
  my $delete2 = $dbh->prepare("DELETE FROM Collections WHERE guid=?");

  #  Update flat fields in Publication table and Fulltext table
  my $field = $type eq 'FOLDER' ? 'folders' : 'labels';
  my $update1 = $dbh->prepare("UPDATE Publications SET $field=? WHERE rowid=?");

  $field = $type eq 'FOLDER' ? 'folderid' : 'labelid';
  my $update2 = $dbh->prepare("UPDATE Fulltext SET $field=? WHERE rowid=?");

  foreach $guid (@list) {

    my ( $list, $rowid );

    $field = $type eq 'FOLDER' ? 'folders' : 'labels';

    # Get the publications that are in the given folder
    my $select = $dbh->prepare(
      "SELECT publications.rowid as rowid, publications.$field as list FROM Publications JOIN fulltext
      ON publications.rowid=fulltext.rowid WHERE fulltext MATCH '$guid'"
    );

    $select->bind_columns( \$rowid, \$list );
    $select->execute;
    while ( $select->fetch ) {

      my $new_list = $self->_remove_from_flatlist( $list, $guid );

      $update1->execute( $new_list, $rowid );
      $update2->execute( $new_list, $rowid );
    }

    $delete1->execute($guid);
    $delete2->execute($guid);
  }

  $self->commit_or_continue_tx($in_prev_tx);
}

# Update collection <-> publication mappings throughout the database
# for all $pubs

sub update_collections {
  ( my $self, my $pubs, my $type) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my $what = $type eq 'FOLDER' ? 'folders' : 'labels';

  foreach my $pub (@$pubs) {

    my $rowid    = $pub->_rowid;
    my $pub_guid = $pub->guid;

    my $guid_list = $pub->$what;
    my @guids = split( /,/, $pub->$what );

    # First update flat field in Publication and Fulltext tables
    $guid_list = $dbh->quote($guid_list);

    $dbh->do("UPDATE Publications SET $what=$guid_list WHERE rowid=$rowid;");

    my $field = $type eq 'FOLDER' ? 'folderid' : 'labelid';

    $dbh->do("UPDATE Fulltext SET $field=$guid_list WHERE rowid=$rowid;");

    # Remove all connections from Collection_Publication table
    my $sth = $dbh->do(
      "DELETE FROM Collection_Publication WHERE collection_guid IN (SELECT guid FROM Collections WHERE Collections.type='$type') AND publication_guid='$pub_guid'"
    );

    # Then set new connections
    my $connection = $dbh->prepare(
      "INSERT INTO Collection_Publication (collection_guid, publication_guid) VALUES(?,?)");

    foreach my $collection_guid (@guids) {
      $connection->execute( $collection_guid, $pub_guid );
    }
  }

  $self->commit_or_continue_tx($in_prev_tx);

}

sub add_to_collection {
  my ( $self, $pubs, $guid) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  # Figure out the type from the GUID.
  my $sth = $dbh->prepare("SELECT * FROM Collections WHERE guid=?");
  $sth->execute($guid);
  my $type;
  while ( my $row = $sth->fetchrow_hashref ) {
    $type = $row->{type};
  }
  $sth->finish;

  foreach my $pub (@$pubs) {
    $pub->add_guid( $type, $guid );
  }
  $self->update_collections( $pubs, $type );

  $self->commit_or_continue_tx($in_prev_tx);
}

# Deletes all publication objects in list $data from collection with
# $collection_guid

sub remove_from_collection {
  my ( $self, $pubs, $guid) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  # Figure out the type from the GUID.
  my $sth = $dbh->prepare("SELECT * FROM Collections WHERE guid=?");
  $sth->execute($guid);
  my $type;
  while ( my $row = $sth->fetchrow_hashref ) {
    $type = $row->{type};
  }
  $sth->finish;

  my $what = $type eq 'FOLDER' ? 'folders' : 'labels';

  foreach my $pub (@$pubs) {
    my $old_list = $pub->$what;
    my $new_list = $self->_remove_from_flatlist( $old_list, $guid );
    $pub->$what($new_list);
  }

  $self->update_collections( $pubs, $type );

  $self->commit_or_continue_tx($in_prev_tx);

}

# Renames collection with $guid to $new_name
sub rename_collection {
  my ( $self, $guid, $new_name ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  $new_name = $dbh->quote($new_name);

  $dbh->do("UPDATE Collections SET name=$new_name WHERE guid='$guid'");

  $self->commit_or_continue_tx($in_prev_tx);

}

# Stupid utility function to get a collection's type from its GUID.
sub get_collection_type {
  my ( $self, $guid ) = @_;

  # Special cases for the root nodes.
  return 'FOLDER' if ( $guid =~ m/(FOLDER)/ );
  return 'LABEL'  if ( $guid =~ m/(LABELS)/ );

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my ($type) = $dbh->selectrow_array("SELECT type FROM Collections WHERE guid='$guid'");

  $self->commit_or_continue_tx($in_prev_tx);

  return $type;
}

# Moves a collection $drop_guid to a new place relative to collection
# $target_guid depending on $position (append -> new sub-collection,
# below or above -> new order in old sub-collection)

sub move_collection {
  my ( $self, $target_guid, $drop_guid, $position, $type ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my ( $new_parent, $sort_order );
  if ( $target_guid =~ m/ROOT/ ) {

    # Root nodes are not stored in the tables; rather, a node with a root parent
    # simply stores "ROOT" as its parent GUID.
    $new_parent = 'ROOT';
    $sort_order = 0;
    $target_guid =~ s/(FOLDER_|LABEL_)ROOT/ROOT/;
  } else {

    # Get parent and sort_order of target
    ( $new_parent, $sort_order ) = $dbh->selectrow_array(
      "SELECT parent, sort_order FROM Collections WHERE guid='$target_guid' AND TYPE='$type'");
  }

  # We move to a new sub-collection
  if ( $position eq 'append' ) {

    # Determine sort_order of last item
    ( my $max ) = $dbh->selectrow_array(
      "SELECT max(sort_order) FROM Collections WHERE parent='$target_guid' AND TYPE='$type'");

    if ( defined $max ) {
      $max++;
    } else {
      $max = 0;
    }

    # Append new item after the last item in the new sub-collection
    $dbh->do(
      "UPDATE Collections SET parent='$target_guid', sort_order=$max WHERE guid='$drop_guid' AND TYPE='$type'"
    );

    # We place above or below a new item within the same or another sub-collection
  } else {

    my $new_sort_order;

    if ( $position eq 'above' ) {
      $new_sort_order = $sort_order;
    } else {
      $new_sort_order = $sort_order + 1;
    }

    # Increase sort_order of all items below the new item
    $dbh->do(
      "UPDATE Collections SET sort_order=sort_order+1 WHERE parent='$new_parent' and sort_order >= $new_sort_order AND TYPE='$type'"
    );

    # Adjust parent and sort_order of new item
    $dbh->do(
      "UPDATE Collections SET sort_order=$new_sort_order, parent='$new_parent' WHERE guid='$drop_guid' AND TYPE='$type'"
    );

  }

  # We make sure that all sort_order values are normalized,
  # i.e. starting always with 0 and increasing always by 1. This is
  # mainly cosmetic

  my ($old_parent) = $dbh->selectrow_array(
    "SELECT parent FROM Collections WHERE guid='$drop_guid' AND TYPE='$type'");
  if ( defined $old_parent ) {
    $self->_normalize_sort_order( $old_parent, $type );
  }
  if ( defined $new_parent && $new_parent ne $old_parent ) {
    $self->_normalize_sort_order( $new_parent, $type );
  }

  $self->commit_or_continue_tx($in_prev_tx);

}

# Updates the fields of collection with $guid. New values are given in
# the hashref $data.
sub update_collection_fields {

  my ( $self, $guid, $data ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my @updates;

  foreach my $field (keys %$data){
    push @updates, "$field = ". $dbh->quote($data->{$field});
  }

  $dbh->do("UPDATE Collections SET " . join(',',@updates) . " WHERE guid='$guid';");

  $self->commit_or_continue_tx($in_prev_tx);

}

sub sort_labels {

  my ( $self, $field ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my @guids;

  if ( $field eq 'name' ) {
    my $sth =
      $dbh->prepare("SELECT guid FROM Collections WHERE type='LABEL' order by UPPER(name) ASC");
    $sth->execute;
    while ( my $row = $sth->fetchrow_hashref ) {
      push @guids, $row->{guid};
    }
  }

  if ( $field eq 'count' ) {
    my $hist = $self->histogram( 'labels', $dbh );
    @guids = reverse sort { $hist->{$a}->{count} <=> $hist->{$b}->{count} } keys %$hist;
  }

  my $sth = $dbh->prepare("UPDATE Collections SET sort_order = ? WHERE guid=?");

  my $i = 0;
  foreach my $guid (@guids) {
    $sth->execute( $i, $guid );
    $i++;
  }

  $self->commit_or_continue_tx($in_prev_tx);

}

# Initializes default labels in the user's library. We do this
# here (as opposed to shipping it in our default library) to make sure
# everybody has a unique guid for these labels.

sub set_default_collections {

  my ($self) = @_;

  my ( $dbh, $in_prev_tx ) = $self->begin_or_continue_tx;

  my $guid1 = Data::GUID->new->as_hex;
  $guid1 =~ s/^0x//;

  my $guid2 = Data::GUID->new->as_hex;
  $guid2 =~ s/^0x//;

  $dbh->do(
    "INSERT INTO Collections (guid,name,type,parent,sort_order,style,hidden) VALUES ('$guid1', 'Review','LABEL','ROOT',1,'22',0);"
  );
  $dbh->do(
    "INSERT INTO Collections (guid,name,type,parent,sort_order,style,hidden) VALUES ('$guid2', 'Incomplete','LABEL','ROOT',2,'0',0);"
  );

  $self->commit_or_continue_tx($in_prev_tx);

}

# Preprocess a query string for the fulltext search.

sub process_query_string {
  ( my $self, my $query ) = @_;

  # Remove trailing/leading whitespace
  $query =~ s/^\s+//;
  $query =~ s/\s+$//;

  # Normalize all whitespace to one blank
  $query =~ s/\s+/ /g;

  # remove whitespaces around colons
  $query =~ s/\s+:\s+/:/g;

  # Normalize all quotes to double quotes
  $query =~ tr/'/"/;

  # dashed words are indexed seperately so we can find x-chromosome by
  # converting the query to to "x chromosome"
  $query =~ s/(\S+)-(\S+)/"$1 $2"/;

  # Make sure quotes are balanced; if not silently remove all quotes
  my ($quote_count) = ( $query =~ tr/"/"/ );
  if ( $quote_count % 2 ) {
    $query =~ s/"//g;
  }

  # Parse fields respecting quotes
  my @chars      = split( //, $query );
  my $curr_field = '';
  my @fields     = ();
  my $in_quotes  = 0;
  foreach my $c (@chars) {
    if ( $c eq ' ' and !$in_quotes ) {
      push @fields, $curr_field;
      $curr_field = '';
      next;
    }
    if ( $c eq '"' ) {
      $in_quotes = $in_quotes ? 0 : 1;
      $curr_field .= $c;
      next;
    }
    $curr_field .= $c;
  }
  push @fields, $curr_field;

  my @new_fields = ();


  foreach my $field (@fields) {

    # Special keywords are converted to uppercase and taken verbatim
    if ( $field =~ /^(not|and|or)$/i ) {
      push @new_fields, uc($1);
      next;
    }

    # We have a key:value pair like author:chang
    if ( $field =~ /(.*):(.*)/ ) {

      my ( $key, $value ) = ( $1, $2 );

      my $known = 0;

      foreach my $supported (
        'text',    'abstract', 'notes',    'title', 'key', 'author',
        'labelid', 'keyword',  'folderid', 'year',  'journal'
        ) {
        if ( $1 eq $supported ) {
          $known = 1;
          last;
        }
      }

      # Silently ignore unknown fields
      next if not $known;

      # Unfortunately syntax like author:"hofacker il" is not
      # supported any more in the current fts3 code and yields an
      # error. So we rewrite it to:
      # "hofacker il" author:hofacker author:il

      if ( $value =~ /"(.*)"/ ) {
        my $inner = $1;
        push @new_fields, "\"$inner\"";
        foreach my $part ( split( /\s/, $inner ) ) {
          push @new_fields, "$key:$part";
        }
        next;
      }

      # Normal fields: author:chang
      push @new_fields, $field . '*';
      next;
    }

    # We have a quoted "query" and use this verbatim
    if ( $field =~ /".*"/ ) {
      push @new_fields, $field;
      next;
    }

    # We ignore one and two letter words not part of a quoted phrase
    if ( length($field) < 3 ) {
      next;
    }

    # For all other terms:
    $field .= "*";
    push @new_fields, $field;

  }

  my $output = $self->dbh->quote( join( " ", @new_fields ) );

  return $output;

}

sub fulltext_count {
  ( my $self, my $query, my $trash ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my ( $where, $select );
  if ($query) {
    $select =
      "select count(*) from Publications join Fulltext on publications.rowid=Fulltext.rowid ";
    $query = $self->process_query_string($query);
    $where = "WHERE Fulltext MATCH $query AND Publications.trashed=$trash ";
  } else {
    $select = "select count(*) from Publications ";
    $where  = "WHERE trashed=$trash ";
  }

  my $count = $dbh->selectrow_array("$select $where");

  $self->commit_or_continue_tx($in_prev_tx);

  return $count;
}

sub fulltext_search {

  ( my $self, my $_query, my $offset, my $limit, my $order, my $trash, my $do_order ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  if ($do_order) {

    # Custom rank function to distinguish hits in meta data and fulltext
    $dbh->sqlite_create_function(
      'rank', 1,
      sub {
        my $blob = $_[0];

        # blob contains matchinfo as 32bit integers, we convert them
        # into a normal array
        my @all = unpack( "V*", $blob );

        # The first two integers are the number of phrases and the
        # number of columns, resp.
        my ( $num_phrases, $num_columns ) = ( $all[0], $all[1] );

        # We are only interested in the number of matches for each of
        # the 11 columns in our fulltext table
        # text,abstract,notes,title,key,author,year,journal, keyword,folderid,labelid
        my @counts = ( 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 );

        foreach my $column ( 0 .. 11 ) {
          foreach my $phrase ( 0 .. $num_phrases - 1 ) {

            # The way the information is stored in the blob is different
            # from the latest documentation at
            # http://sqlite.org/fts3.html. In the SQLite version that is
            # used by the DBD package we can get the number of matches
            # like this:
            $counts[$column] +=
              $all[ 2 + 1 * $num_columns * $num_phrases + $num_columns * $phrase + $column ];
          }
        }

        my $score = 0;

        # If hit occured in title, key, author, year or journal we show them first
        my $sum = $counts[4] + $counts[5] + $counts[6] + $counts[7] + $counts[8];

        $score = $sum * 10;

        return $score;
      }
    );
  }

  my $select =
    'SELECT *, Publications.rowid as _rowid,  Publications.title as title, Publications.abstract as abstract';

  $order = "created DESC" if !$order;

  my ( $where, $query, $rank, $sth );

  if ($_query) {

    $select .=
      ",offsets(Fulltext) as offsets, rank(matchinfo(Fulltext)) as rank_score FROM Publications JOIN Fulltext ON Publications.rowid=Fulltext.rowid ";

    $query = $self->process_query_string($_query);

    $where = "WHERE Fulltext MATCH $query AND Publications.trashed=$trash";
    if ($do_order) {
      $rank = "ORDER BY rank(matchinfo(Fulltext)) DESC, $order";
    } else {
      $rank = "";
    }

    $sth = $dbh->prepare("$select $where $rank LIMIT $limit OFFSET $offset");

  } else {
    $select .= ' FROM Publications ';
    $order =~ s/author/authors/;
    $order =~ s/notes/annote/;
    $where = "WHERE Publications.trashed=$trash";

    $sth = $dbh->prepare("$select $where ORDER BY $order LIMIT $limit OFFSET $offset");
  }

  $sth->execute;

  my @page = ();

  while ( my $row = $sth->fetchrow_hashref() ) {

    my $data = {};

    foreach my $field ( keys %$row ) {

      if ( $field eq 'offsets' ) {
        $data->{_snippets} = $self->_snippets( $row, $_query );
        next;
      }

      # fields only in fulltext, named differently or absent in
      # Publications table
      next if $field ~~ [ 'author', 'text', 'notes', 'label', 'labelid', 'folder' ];
      my $value = $row->{$field};

      $field = 'citekey'  if $field eq 'key';       # citekey is called 'key'
                                                    # in ft-table for
                                                    # convenience
      $field = 'keywords' if $field eq 'keyword';

      if ( defined $value and $value ne '' ) {
        $data->{$field} = $value;
      }
    }

    my $pub = Paperpile::Library::Publication->new($data);

    $pub->_db_connection( $self->file );

    # Mark all imported here for efficiency reasons. If this is a
    # temporary db file we have to call _exists_pub somewhere on the
    # data after calling this function.
    $pub->_imported(1);

    push @page, $pub;
  }

  $self->commit_or_continue_tx($in_prev_tx);

  return [@page];
}

sub get_trashed_pubs {

  my ($self) = @_;

  return $self->all( 'created', 1 );
}

sub all {

  my ( $self, $order, $get_trashed_pubs ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my $query = "SELECT rowid as _rowid, * FROM Publications ";

  if ($get_trashed_pubs) {
    $query .= "WHERE trashed=1 ";
  }

  if ($order) {
    $query .= "ORDER BY $order";
  }

  my $sth = $self->dbh->prepare($query);

  $sth->execute;

  my @page = ();

  while ( my $row = $sth->fetchrow_hashref() ) {
    my $pub = Paperpile::Library::Publication->new( { _light => $self->light_objects } );
    $pub->_db_connection( $self->file );
    foreach my $field ( keys %$row ) {
      my $value = $row->{$field};
      if ($value) {
        $pub->$field($value);
      }
    }
    $pub->_imported(1);
    push @page, $pub;
  }

  $self->commit_or_continue_tx($in_prev_tx);

  return [@page];

}

# Gets all entries as simple hash. Is much faster than building
# Publication objects which is not necessary for some tasks such as
# finding duplicates

sub all_as_hash {

  my ( $self, $order ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my $query = "SELECT rowid as _rowid, * FROM Publications ";

  if ($order) {
    $query .= "ORDER BY $order";
  }

  my $sth = $self->dbh->prepare($query);

  $sth->execute;

  my @data = ();

  while ( my $row = $sth->fetchrow_hashref() ) {
    my $pub = {};
    foreach my $field ( keys %$row ) {
      my $value = $row->{$field};
      if ($value) {
        $pub->{$field} = $value;
      }
    }
    $pub->{_imported} = 1;
    push @data, $pub;
  }

  $self->commit_or_continue_tx($in_prev_tx);

  return [@data];

}

# Check if publication objects in $pubs are already in database. Sets
# _imported field accordingly.

sub exists_pub {
  ( my $self, my $pubs ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my $sth = $dbh->prepare("SELECT rowid, * FROM publications WHERE sha1=?");

  foreach my $pub (@$pubs) {

    next unless defined($pub);
    $sth->execute( $pub->sha1 );

    my $exists = 0;

    while ( my $row = $sth->fetchrow_hashref() ) {
      $exists = 1;
      foreach my $field ( keys %$row ) {
        my $value = $row->{$field};

        if ( $field eq 'rowid' ) {
          $pub->_rowid($value);
        }

        if ( $field eq 'guid' ) {
          $pub->_old_guid($pub->guid) if ($pub->guid);
          $pub->guid($value);
        }

        if ( $field eq 'citekey' ) {
          $pub->citekey($value);
        }

        if ( $field eq 'trashed' ) {
          $pub->trashed($value);
        }

        if ( $field eq 'created' ) {
          $pub->created($value);
        }


        #else {
        #  if ($value) {
        # I don't think we should be updating the publication object during
        # the exists_pub call... removing this line cleared up a bunch of
        # problems with the grid not updating after editing metadata. (Greg
        # 2010-06-20)

        # I only set 'citekey' and 'trashed' now to make the frontend work
        # e.g. for BibTeX files. I hope this does not cause the problems you
        # were refering to. 2010-08-17 Stefan

        #$pub->$field($value);
        #  }
        #}

      }
    }

    $pub->_imported($exists);

  }

  $self->commit_or_continue_tx($in_prev_tx);

}

# Creates new entries for all labels stored in labels_tmp fields in a
# list of pubs. Returns hash that maps the temporary label to the guids
# of the newly created labels (or of already existing labels if a
# label with the same name is already in the database)

sub insert_labels {
  ( my $self, my $pubs) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my %map;

  # Collect all label names
  my @labels;
  foreach my $pub (@$pubs) {
    push @labels, split( /\s*,\s*/, $pub->labels_tmp );
  }

  # Create guid for each of them and make sure that the list is
  # non-redundant
  foreach my $label (@labels) {
    my $guid = Data::GUID->new->as_hex;
    $guid =~ s/^0x//;

    if ( !exists( $map{$label} ) ) {
      $map{$label} = $guid;
    }
  }

  # Go through all labels and either create a new collection in the
  # database or get guid of already existing label
  foreach my $label ( keys %map ) {

    my $name = $dbh->quote($label);
    ( my $guid ) =
      $dbh->selectrow_array("SELECT guid FROM Collections WHERE name=$name AND type='LABEL';");

    if ($guid) {
      $map{$label} = $guid;
    } else {
      $self->new_collection( $map{$label}, $label, 'LABEL', 'ROOT', 0);

      # Do something here to auto-hide tmp collections.
      ( my $count ) = $dbh->selectrow_array(
        "SELECT count(*) FROM Collections WHERE type='LABEL' and hidden == 0;");
      if ( $count > 5 ) {
        $self->update_collection_fields( $map{$label}, {'hidden' => 1} );
      }
    }
  }

  $self->commit_or_continue_tx($in_prev_tx);

  return \%map;
}

# Small helper function that converts hash to sql syntax (including
# quotes).
sub _hash2sql {

  ( my $self, my $hash) = @_;

  my @fields = ();
  my @values = ();

  foreach my $key ( keys %{$hash} ) {

    my $value = $hash->{$key};

    # ignore fields starting with underscore
    # They are not stored to the database by convention
    next if $key =~ /^_/;

    next if not defined $value;

    push @fields, $key;

    if ( $value eq '' ) {
      push @values, "''";
    } else {
      push @values, $self->dbh->quote($value);
    }
  }

  my @output = ( join( ',', @fields ), join( ',', @values ) );

  return @output;
}

# Attach $file to the publication $pub. If $is_pdf is set it is *the*
# PDF otherwise it is treated as attachment. If $old_guid is set the
# new file gets this guid (to avoid changing of the guid when using
# the undo function).

sub attach_file {

  my ( $self, $file, $is_pdf, $pub, $old_guid) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my $settings = $self->settings;
  my $source   = Paperpile::Utils->adjust_root($file);

  my $pub_guid = $pub->guid;

  my $file_guid;

  if ($old_guid) {
    $file_guid = $old_guid;
  } else {
    $file_guid = Data::GUID->new->as_hex;
    $file_guid =~ s/^0x//;
  }

  my $file_size = stat($file)->size;

  my $md5 = Paperpile::Utils->calculate_md5($file);

  my ( $relative_dest, $absolute_dest );

  if ( $settings->{paper_root} ) {

    if ($is_pdf) {

      # File name relative to [paper_root] is [pdf_pattern].pdf
      $relative_dest =
        $pub->format_pattern( $settings->{pdf_pattern}, { key => $pub->citekey } ) . ".pdf";

    } else {
      my ( $volume, $dirs, $base_name ) = splitpath($source);

      # Path relative to [paper_root] is [attachment_pattern]/$file_name
      $relative_dest =
        $pub->format_pattern( $settings->{attachment_pattern}, { key => $pub->citekey } );
      $relative_dest = catfile( $relative_dest, $base_name );
    }

    $absolute_dest = catfile( $settings->{paper_root}, $relative_dest );

    # Copy file, file name can be changed if it was not unique
    $absolute_dest = Paperpile::Utils->copy_file( $source, $absolute_dest );
  } else {
    $absolute_dest = $file;
  }

  my ( $volume, $dirs, $base_name ) = splitpath($absolute_dest);

  my $name       = $dbh->quote($base_name);
  my $local_file = $dbh->quote($absolute_dest);

  $dbh->do( "INSERT INTO Attachments (guid, publication, is_pdf, name, local_file, size, md5)"
      . "                     VALUES ('$file_guid', '$pub_guid', $is_pdf, $name, $local_file, $file_size, '$md5');"
  );

  if ($is_pdf) {
    my $pdf_name = $absolute_dest;
    if ( $settings->{paper_root} ) {
      $self->index_pdf( $pub_guid, $absolute_dest);
      $pdf_name = abs2rel( $absolute_dest, $settings->{paper_root} );
    }
    $pub->pdf($file_guid);
    $pub->pdf_name($pdf_name);

    $pdf_name = $dbh->quote($pdf_name);

    $dbh->do(
      "UPDATE Publications SET pdf='$file_guid', pdf_name=$pdf_name, times_read=0, last_read='' WHERE guid='$pub_guid';"
    );

  } else {
    ( my $old_attachments ) =
      $dbh->selectrow_array("SELECT attachments FROM Publications WHERE guid='$pub_guid' ");

    my @list = split( ',', $old_attachments || '' );

    push @list, $file_guid;

    my $new_attachments = join( ',', @list );

    $dbh->do("UPDATE Publications SET attachments='$new_attachments' WHERE guid='$pub_guid';");

    $pub->attachments($new_attachments);
    $pub->refresh_attachments($self);

  }

  $self->commit_or_continue_tx($in_prev_tx);

  return $file_guid;

}

# Delete PDF or other supplementary file with GUID $guid that is
# attached to $pub. If $with_undo is given the function only moves the
# file and returns the temporary path were it is stored for undo
# operations.

sub delete_attachment {

  my ( $self, $guid, $is_pdf, $pub, $with_undo) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my $paper_root = $self->get_setting('paper_root');

  my $undo_dir = catfile( Paperpile::Utils->get_tmp_dir(), "trash" );
  mkpath($undo_dir);

  my $rowid = $pub->_rowid;

  ( my $path ) = $dbh->selectrow_array("SELECT local_file FROM Attachments WHERE guid='$guid';");

  $dbh->do("DELETE FROM Attachments WHERE guid='$guid'");

  if ($is_pdf) {
    $dbh->do("UPDATE Fulltext SET text='' WHERE rowid=$rowid");
    $dbh->do(
      "UPDATE Publications SET pdf='', pdf_name='', times_read=0, last_read='' WHERE rowid=$rowid");
    $pub->pdf('');
    $pub->pdf_name('');

  } else {

    ( my $attachments ) =
      $dbh->selectrow_array("SELECT attachments FROM Publications WHERE rowid=$rowid");

    my @old_attachments = split( /,/, $attachments || '' );

    my @new_attachments = ();

    foreach my $g (@old_attachments) {
      next if ( $g eq $guid );
      push @new_attachments, $g;
    }

    my $new = join( ',', @new_attachments );

    $dbh->do("UPDATE Publications SET attachments='$new' WHERE rowid=$rowid");

    $pub->attachments($new);
    $pub->refresh_attachments($self);
  }

  move( $path, $undo_dir ) if $with_undo;
  unlink($path);

  ## Remove directory if empty

  if ($path) {
    my ( $volume, $dir, $file_name ) = splitpath($path);

    # Never remove the paper_root even if its empty;
    if ( canonpath($paper_root) ne canonpath($dir) ) {

      # Simply remove it; will not do any harm if it is not empty; Did not
      # find an easy way to check if dir is empty, but it does not seem
      # necessary anyway
      rmdir $dir;
    }
  }

  $self->commit_or_continue_tx($in_prev_tx);

  if ($with_undo) {
    my ( $volume, $dir, $file_name ) = splitpath($path);
    return catfile( $undo_dir, $file_name );
  }

}

sub change_paper_root {

  my ( $self, $new_root ) = @_;

  # If new folder already exists make sure it is empty.
  if (-e $new_root){
    if (scalar glob("$new_root/*")){
      PaperRootNotEmptyError->throw("New PDF folder must be empty.");
    }
  }

  my $old_root = $self->get_setting( 'paper_root');

  # When starting from scratch the old_root might not exist. In that
  # case, we don't have to move anything and just try to create the
  # new directory.
  if (!-e $old_root){

    eval {
      mkpath($new_root);
    };

    if ($@ || (!(-w $new_root))) {
      my $msg = $@ || "Unknown error";
      FileError->throw("Cannot set $new_root as PDF folder ($msg).");
    } else {
      $self->set_setting( 'paper_root', $new_root);
      return;
    }
  }

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  eval {

    my $find     = $dbh->prepare('SELECT guid,local_file from Attachments;');
    my $replace  = $dbh->prepare('UPDATE Attachments SET local_file=? WHERE guid=?;');

    my ( $guid, $old_file );
    $find->bind_columns( \$guid, \$old_file );
    $find->execute;

    while ( $find->fetch ) {
      my $relative = abs2rel( $old_file, $old_root );
      my $new_file = catfile( $new_root, $relative );
      $replace->execute( $new_file, $guid );

    }

    if ( dirmove( $old_root, $new_root ) ) {
      $self->set_setting( 'paper_root', $new_root);
    } else {
      FileError->throw("$!");
    }
  };

  if ($@) {
    $self->rollback_transaction;
    my $msg = $@;
    $msg = $@->error if $@->isa('PaperpileError');
    FileError->throw("Could not move PDF directory to new location ($msg)");
  }

  $self->commit_or_continue_tx($in_prev_tx);

}

# Renames and moves PDFs/attachments according to $pdf_pattern and
# $attachment_pattern. Also sets settings pdf_pattern and
# attachment_pattern after an succesful update of the tree structure.

sub rename_files {

  my ( $self, $pdf_pattern, $attachment_pattern ) = @_;

  my ( $dbh, $in_prev_tx ) = $self->begin_or_continue_tx;

  my $paper_root = $self->get_setting('paper_root');

  # If paper_root is not created or does not exist for some other
  # reason, we can stop because there are no files for us to update
  if ( !-e $paper_root ) {
    $self->commit_or_continue_tx($in_prev_tx);
    return;
  }

  my $tmp_root = "$paper_root\_tmp";

  eval {

    my $select =
      $dbh->prepare("SELECT guid, publication, local_file, name, is_pdf FROM Attachments;");

    my ( $file_guid, $pub_guid, $file, $file_name, $is_pdf );

    $select->execute;

    $select->bind_columns( \$file_guid, \$pub_guid, \$file, \$file_name, \$is_pdf );
    $select->execute;

    while ( $select->fetch ) {

      my $data = $dbh->selectrow_hashref("SELECT * FROM Publications WHERE guid='$pub_guid';");

      if ( !$data ) {
        print STDERR
          "Warning: $file attached to Publication ($pub_guid) that does not exist any more.";
        next;
      }

      my $pub = Paperpile::Library::Publication->new($data);

      my $relative_dest;

      if ($is_pdf) {
        $relative_dest = $pub->format_pattern( $pdf_pattern, { key => $pub->citekey } ) . '.pdf';
      } else {
        $relative_dest = $pub->format_pattern( $attachment_pattern, { key => $pub->citekey } );
        $relative_dest = File::Spec->catfile( $relative_dest, $file_name );
      }

      my $absolute_dest = File::Spec->catfile( $tmp_root, $relative_dest );

      if ( $data->{trashed} ) {
        $absolute_dest = File::Spec->catfile( $tmp_root, "Trash", $relative_dest );
      }

      $absolute_dest = Paperpile::Utils->copy_file( $file, $absolute_dest );

      $relative_dest = File::Spec->abs2rel( $absolute_dest, $tmp_root );
      my ( $volume, $dirs, $base_name ) = splitpath($absolute_dest);

      my $new_file = $dbh->quote( File::Spec->catfile( $paper_root, $relative_dest ) );
      my $name = $dbh->quote($base_name);

      $dbh->do("UPDATE ATTACHMENTS SET local_file=$new_file, name=$name WHERE guid='$file_guid';");

      if ($is_pdf) {
        $name = $dbh->quote($relative_dest);
        $dbh->do("UPDATE Publications SET pdf_name=$name WHERE guid='$pub_guid';");
      }
    }
  };

  if ($@) {
    $self->rollback_transaction;
    my $msg = $@;
    $msg = $@->error if $@->isa('PaperpileError');
    FileError->throw("Could not apply changes ($msg)");
  }

  if ( not move( $paper_root, "$paper_root\_backup" ) ) {
    $self->rollback_transaction;
    FileError->throw(
      "Could not apply changes (Error creating backup copy $paper_root\_backup -- $!)");
  }

  if ( not move( $tmp_root, $paper_root ) ) {
    $self->rollback_transaction;
    move( "$paper_root\_backup", $paper_root )
      or FileError->throw(
      'Could not apply changes and your library is broken now. This should never happen, contact support@paperpile.org if it has happened to you.'
      );
    FileError->throw(
      "Could not apply changes (Error creating new copy of directory tree in $paper_root -- $!).");
  }

  $self->commit_or_continue_tx($in_prev_tx);
  rmtree("$paper_root\_backup");
}

sub index_pdf {

  my ( $self, $guid, $pdf_file) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my $bin = Paperpile::Utils->get_binary('extpdf');

  my %extpdf;

  $extpdf{command} = 'TEXT';
  $extpdf{inFile}  = $pdf_file;

  my $xml = XMLout( \%extpdf, RootName => 'extpdf', XMLDecl => 1, NoAttr => 1 );

  my ( $fh, $filename ) = File::Temp::tempfile();
  print $fh $xml;
  close($fh);

  my @text = `$bin $filename`;

  my $text = '';

  $text .= $_ foreach (@text);

  $text = $dbh->quote($text);

  $dbh->do(
    "UPDATE Fulltext SET text=$text WHERE rowid=(SELECT rowid FROM PUBLICATIONS WHERE guid='$guid')"
  );

  $self->commit_or_continue_tx($in_prev_tx);

}

sub histogram {

  my ( $self, $field ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my %hist = ();

  if ( $field eq 'authors' ) {

    my $sth = $dbh->prepare('SELECT authors from Publications WHERE trashed=0;');

    my ($author_list);
    $sth->bind_columns( \$author_list );
    $sth->execute;
    while ( $sth->fetch ) {
      my @authors = split( ' and ', $author_list );
      foreach my $author_disp (@authors) {
        my $tmp = Paperpile::Library::Author->_split_full($author_disp);
        $tmp->{initials} = Paperpile::Library::Author->_parse_initials( $tmp->{first} );
        my $author = Paperpile::Library::Author->_nice($tmp);

        if ( exists $hist{$author} ) {
          $hist{$author}->{count}++;
        } else {
          $hist{$author}->{count} = 1;

          # Parse out the author's name.
          my ( $surname, $initials ) = split( ', ', $author );
          $hist{$author}->{name} = $surname;
          $hist{$author}->{id}   = $author;
        }
      }
    }
  }

  if ( $field eq 'labels' ) {

    my ( $guid, $label, $style );

    # Select all labels and initialize the histogram counts.
    my $sth = $dbh->prepare(qq^SELECT guid,name,style FROM Collections WHERE type='LABEL';^);
    $sth->bind_columns( \$guid, \$label, \$style );
    $sth->execute;
    while ( $sth->fetch ) {
      $style = $style || 'default';
      $hist{$guid}->{count} = 0;
      $hist{$guid}->{name}  = $label;
      $hist{$guid}->{id}    = $guid;
      $hist{$guid}->{style} = $style;
    }

    # Select label-publication links and count them up.
    $sth = $dbh->prepare(
      qq^SELECT collection_guid FROM Collection_Publication, Publications WHERE publication_guid = Publications.guid
         AND Publications.trashed=0 ^
    );
    $sth->bind_columns( \$guid );
    $sth->execute;

    while ( $sth->fetch ) {
      if ( exists $hist{$guid} ) {
        $hist{$guid}->{count}++;
      }
    }

  }

  if ( $field eq 'journals' or $field eq 'pubtype' ) {

    $field = 'journal' if ( $field eq 'journals' );

    my $sth = $dbh->prepare("SELECT $field FROM Publications WHERE trashed=0;");
    my ($value);
    $sth->bind_columns( \$value );
    $sth->execute;

    while ( $sth->fetch ) {
      if ($value) {
        $value =~ s/\.//g;
        if ( exists $hist{$value} ) {
          $hist{$value}->{count}++;
        } else {
          $hist{$value}->{count} = 1;
          $hist{$value}->{id}    = $value;
          $hist{$value}->{name}  = $value;
        }
      }
    }
  }

  $self->commit_or_continue_tx($in_prev_tx);

  return {%hist};

}

sub dashboard_stats {

  my $self = shift;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  ( my $num_items ) = $dbh->selectrow_array("SELECT count(*) FROM Publications WHERE trashed=0;");

  ( my $num_pdfs ) =
    $dbh->selectrow_array("SELECT count(*) FROM Publications WHERE PDF !='' AND trashed=0;");

  ( my $num_attachments ) =
    $dbh->selectrow_array("SELECT count(*) FROM Attachments,Publications WHERE Attachments.publication==Publications.guid AND is_pdf=0 AND trashed=0;");

  ( my $last_imported ) =
    $dbh->selectrow_array("SELECT created FROM Publications WHERE trashed=0 ORDER BY created DESC limit 1;");

  $self->commit_or_continue_tx($in_prev_tx);

  return {
    num_items       => $num_items,
    num_pdfs        => $num_pdfs,
    num_attachments => $num_attachments,
    last_imported   => $last_imported || "Nothing imported yet"
  };

}

sub _flag_as_incomplete {

  ( my $self, my $pub ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  # Check if we have a label 'Incomplete'
  ( my $guid ) = $dbh->selectrow_array(
    "SELECT guid FROM Collections WHERE parent='ROOT' AND type='LABEL' AND name='Incomplete'");

  # If not create it
  if ( !$guid ) {
    $guid = Data::GUID->new;
    $guid = $guid->as_hex;
    $guid =~ s/^0x//;
    $self->new_collection( $guid, 'Incomplete', 'LABEL', 'ROOT', 0);
  }

  # Assign the label to the publication
  $pub->add_label($guid);
  $self->update_collections( [$pub], 'LABEL');

  $self->commit_or_continue_tx($in_prev_tx);

}

sub _flag_as_complete {

  ( my $self, my $pub ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  ( my $guid ) = $dbh->selectrow_array(
    "SELECT guid FROM Collections WHERE parent='ROOT' AND type='LABEL' AND name='Incomplete'");

  return if not $guid;
  return if ( not $pub->labels =~ /$guid/ );

  $pub->remove_label($guid);
  $self->update_collections( [$pub], 'LABEL', $dbh );

  $self->commit_or_continue_tx($in_prev_tx);

}

# Generates a unique citation key for $pub taking into account already
# existing keys in the database and additional keys in the list
# $existing.

sub generate_unique_key {

  my ( $self, $pub, $existing) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  # If a citekey is already set we check if it is unique. If it is
  # unique we return it directly. This is used to ensure that trashed
  # items get their original citekey back if it is still unique.

  my $guid = $pub->guid;

  my $unique       = 1;
  my $original_key = $pub->citekey;
  if ($original_key) {
    foreach my $existing_key (@$existing) {
      if ( $existing_key eq $original_key ) {
        $unique = 0;
        last;
      }
    }

    if ($unique) {
      my $_key = $dbh->quote($original_key);
      ( my $guid ) = $dbh->selectrow_array(
        "SELECT guid FROM Publications WHERE citekey=$_key AND guid !='$guid'");
      if ( !$guid ) {
        $pub->citekey($original_key);
        return $original_key;
      }
    }
  }
  
  # If not citekey is set we generate one and make sure it is not ambiguous

  my $pattern = $self->get_setting( 'key_pattern');
  my $key = $pub->format_pattern($pattern);

  # First we search for similar keys already in the database. We use
  # the fulltext search for efficiency

  my $quoted = $dbh->quote("key:$key*");
  my $sth =
    $dbh->prepare(qq^SELECT key FROM fulltext WHERE fulltext MATCH $quoted AND guid !='$guid'^);
  my $existing_key;
  $sth->bind_columns( \$existing_key );
  $sth->execute;

  my @suffix = ();
  $unique = 1;

  while ( $sth->fetch ) {
    next if ( $existing_key =~ /^trash_/ );
    if ( $existing_key =~ /$key\_?([a-z]{0,3})/ ) {
      push @suffix, $1 if $1;
      $unique = 0;
    }
  }

  # We also search keys in the $existing array to allow generating
  # unique keys also during batch imports
  foreach $existing_key (@$existing) {
    next if ( $existing_key =~ /^trash_/ );
    if ( $existing_key =~ /$key\_?([a-z]{0,3})/ ) {
      push @suffix, $1 if $1;
      $unique = 0;
    }
  }

  # We need to disambiguate by adding suffixes
  if ( !$unique ) {

    # Precompute list of all possible suffixes a,b,c,...,ab,ac,...zzx,zzy,zzz; should be more
    # than enough

    my @all_suffixes;
    my ( $start, $stop ) = ( ord('a'), ord('z') );

    foreach my $i ( $start .. $stop ) {
      foreach my $j ( $start .. $stop ) {
        foreach my $k ( $start .. $stop ) {
          my $suffix = chr($i);
          $suffix .= chr($j) if ( $j > $start );
          $suffix .= chr($k) if ( $k > $start );
          push @all_suffixes, $suffix;
        }
      }
    }
    @all_suffixes = sort { length($a) <=> length($b) || $a cmp $b } @all_suffixes;

    my %map;
    foreach my $i ( 0 .. $#all_suffixes ) {
      $map{ $all_suffixes[$i] } = $i;
    }

    # Now find the correct suffix for the ambiguous key
    my $bare_key   = $key;
    my $new_suffix = '';

    # These are the collected suffixes that already exist
    if (@suffix) {

      # we sort them to make sure to get the 'highest' suffix and count one up
      @suffix = sort { length($a) <=> length($b) || $a cmp $b } @suffix;
      my $pos = $map{ pop(@suffix) } + 1;
      $new_suffix = $all_suffixes[$pos];
    }

    # It is the second item so start with suffix 'a'
    else {
      $new_suffix = 'a';
    }

    # We add suffixes directly to number (Stadler2000a) but use an
    # underscore if key ends in a non-number
    # (Stadler_2000_Bioinformatics_a)
    if ( $key =~ /\d$/ ) {
      $key .= $new_suffix;
    } else {
      $key .= "_" . $new_suffix;
    }
  }

  $pub->citekey($key);

  $self->commit_or_continue_tx($in_prev_tx);

  return $key;

}

# Updates the fields in the fulltext table for $pub. If $new is true a
# new row is inserted.

sub _update_fulltext_table {

  ( my $self, my $pub, my $new ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  if ( ( not $pub->_authors_display ) and ( $pub->authors ) ) {
    my @authors = split( /\band\b/, $pub->authors );
    my @display = ();
    foreach my $a (@authors) {
      my $tmp = Paperpile::Library::Author->_split_full($a);
      $tmp->{initials} = Paperpile::Library::Author->_parse_initials( $tmp->{first} );
      push @display, Paperpile::Library::Author->_nice($tmp);
    }
    $pub->_auto_refresh(0);
    $pub->_authors_display( join( ", ", @display ) );
  }

  my $hash = {
    rowid    => $pub->_rowid,
    guid     => $pub->guid,
    key      => $pub->citekey,
    year     => $pub->year,
    journal  => $pub->journal,
    title    => $pub->title,
    abstract => $pub->abstract,
    notes    => $pub->annote,
    author   => $pub->_authors_display,
    labelid  => $pub->labels,
    folderid => $pub->folders,
    keyword  => $pub->keywords,
  };

  if ($new) {
    my ( $fields, $values ) = $self->_hash2sql( $hash );
    $fields .= ",text";
    $values .= ",''";
    $dbh->do("INSERT INTO fulltext ($fields) VALUES ($values)");
  } else {
    my @list;
    foreach my $field ( keys %$hash ) {
      push @list, "$field=" . $dbh->quote( $hash->{$field} );
    }
    my $sql = join( ',', @list );
    my $rowid = $pub->_rowid;
    $dbh->do("UPDATE Fulltext SET $sql WHERE rowid=$rowid;");
  }

  $self->commit_or_continue_tx($in_prev_tx);

}

# Remove the item from the comma separated list

sub _remove_from_flatlist {

  my ( $self, $list, $item ) = @_;

  my @parts = split( /,/, $list );

  # Only one item
  if ( not @parts ) {
    $list =~ s/$item//;
    return $list;
  }

  my @newParts = ();
  foreach my $part (@parts) {
    next if $part eq $item;
    push @newParts, $part;
  }

  return join( ',', @newParts );

}

# Returns list of guids for all sub-collection below $guid (the list
# includes the parent guid $guid).

sub find_subcollections {

  my ( $self, $guid ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my @list = ($guid);

  my $sth = $dbh->prepare("SELECT * FROM Collections;");
  $sth->execute;
  my @all = ();
  while ( my $row = $sth->fetchrow_hashref() ) {
    push @all, $row;
  }

  $self->_find_subcollections( $guid, \@all, \@list );

  $self->commit_or_continue_tx($in_prev_tx);

  return @list;

}

# Recursive helper function for find_subcollections
# $all is a list of all collections and $list is
# the final list with all guids of the desired sub-collections
sub _find_subcollections {

  my ( $self, $guid, $all, $list ) = @_;

  foreach my $collection (@$all) {
    if ( $collection->{parent} eq $guid ) {
      push @$list, $collection->{guid};
      $self->_find_subcollections( $collection->{guid}, $all, $list );
    }
  }
}

sub find_collection_parents {

  my ( $self, $guid ) = @_;

  # Ignore if guid is ROOT (or 'FOLDER_ROOT' which is the collection
  # root id in the frontend)
  if ( $guid =~ /ROOT/ ) {
    return ();
  }

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my $sth = $dbh->prepare("SELECT * FROM Collections;");
  $sth->execute;

  my %map;
  while ( my $row = $sth->fetchrow_hashref() ) {
    $map{ $row->{guid} } = $row->{parent};
  }

  my @parents        = ();
  my $current_parent = $map{$guid};

  while ( $current_parent ne 'ROOT' ) {
    push @parents, $current_parent;
    $current_parent = $map{$current_parent};
  }


  $self->commit_or_continue_tx($in_prev_tx);

  return @parents;

}

# We make sure that all sort_order values for collections below
# $parent are normalized and consistent (starting 0 and increasing by
# 1).

sub _normalize_sort_order {
  my ( $self, $parent, $type ) = @_;

  my ($dbh, $in_prev_tx) = $self->begin_or_continue_tx;

  my $select = $dbh->prepare(
    "SELECT guid FROM Collections WHERE parent='$parent' AND type='$type' ORDER BY sort_order");

  my $update = $dbh->prepare("UPDATE Collections SET sort_order=? WHERE guid=?");

  my $guid;

  $select->bind_columns( \$guid );
  $select->execute;

  my $counter = 0;
  while ( $select->fetch ) {
    $update->execute( $counter, $guid );
    $counter++;
  }

  $self->commit_or_continue_tx($in_prev_tx);

}

# Generates snippets for a database row $row that was found via a
# query $query

sub _snippets {

  my ( $self, $row, $query ) = @_;

  # Trivial case
  if ( not $query ) {
    return ('');
  }

  # Track if we explicitly searched for a specific field
  my %searchExplicit;
  foreach my $field ( 'text', 'abstract', 'notes' ) {
    $row->{$field} = encode( 'utf8', $row->{$field} );
    $searchExplicit{$field} = 1 if $query =~ /$field\s*:\s*/i;
  }

  # If we don't explicitly search fulltext or abstract and we have a
  # hit in title, journal, authors..., we don't show snippets
  if (  !$searchExplicit{text}
    and !$searchExplicit{abstract}
    and $row->{rank_score} > 0 ) {
    return '';
  }

  # Clean up query
  $query =~ s/^\s+//;
  $query =~ s/\s+$//;
  $query =~ s/"//g;
  $query =~ s/\S+://g;
  $query =~ s/\s+and\s+//gi;
  $query =~ s/\s+or\s+//gi;
  $query =~ s/\s+not\s+//gi;
  $query =~ s/\s+/ /g;

  my @terms = split( /\s+/, $query );

  @terms = ($query) if ( not @terms );

  # Offset format is 4 integers separated by blank

  # 1. The index of the column containing the match. Columns are
  #    numbered starting from 0.

  # 2. The term in the query expression which was matched. Terms are
  #    numbered starting from 0.

  # 3. The byte offset of the first character of the matching phrase,
  #    measured from the beginning of the column's text.

  # 4. Number of bytes in the match.

  my $offsets = $row->{offsets};

  # This is the order of our fields in the fulltext table
  my @fields = ( 'guid', 'text', 'abstract', 'notes' );

  my %snippets = ( text => [], abstract => [], notes => [] );


  while ( $offsets =~ /(\d+) (\d+) (\d+) (\d+)/g ) {

    my ( $column, $term, $start, $length ) = ( $1, $2, $3, $4 );

    # We only generate snippets for text, abstract and notes
    next if ( $column > 3 );

    my $field = $fields[$column];

    my $snippet;
    my $match = substr( $row->{$field}, $start, $length );

    my $context = 100;

    # Get part of snippet before match
    my $before;
    if ( $start < $context ) {
      $before = substr( $row->{$field}, 0, $start );
    } else {
      $before = substr( $row->{$field}, $start - $context, $context );
    }

    # Get part of snippet after match
    my $after = substr( $row->{$field}, $start + $length, $context );

    $before = decode( 'utf8', $before );
    $after  = decode( 'utf8', $after );

    # Cut snippets at sentence boundaries.
    if ( $before =~ /(^|[.?!]\s+)([A-Z].*)/ ) {
      $before = $2;
    }

    if ( $after =~ /(.*[.?!])\s+($|[A-Z])/ ) {
      $after = $1;
    }

    # Take at most 50 characters and cut at word boundaries
    if ( length($after) > 50 ) {
      $after = substr( $after, 0, 50 );
    }

    if ( length($before) > 50 ) {
      $before = substr( $before, length($before) - 50, 50 );
    }

    if ( $after =~ /\s/ ) {
      $after =~ s/\s\w+$//;
    }

    if ( $before =~ /\s/ ) {
      $before =~ s/\w+\s//;
    }

    # Put back together
    $snippet = "$before $match $after";

    # Assign score depending on how many of the keywords occur in the snippet
    my $score = 0;
    foreach my $term (@terms) {
      while ( $snippet =~ /$term/g ) {
        $score += 1;
      }
      push @{ $snippets{$field} }, { snippet => $snippet, score => $score };
    }
  }

  my @what;

  # If specific fields are searched we only show snippets for them
  if ( $searchExplicit{notes} or $searchExplicit{text} or $searchExplicit{abstract} ) {
    @what = ();
    push @what, 'notes'    if $searchExplicit{notes};
    push @what, 'abstract' if $searchExplicit{abstract};
    push @what, 'text'     if $searchExplicit{text};
  } else {
    @what = ( 'notes', 'abstract', 'text' );
  }

  my %shownSnippets = ();
  foreach my $what (@what) {
    $snippets{$what} = [ sort { $b->{score} <=> $a->{score} } @{ $snippets{$what} } ];
    $shownSnippets{$what} = [];
  }

  my $count_lines  = 1;
  my @already_seen = ();

  # We collect at most 5 snippets to show
  while ( $count_lines < 5 ) {

    # Take the first from each category until we have enough snippets
    foreach my $what (@what) {
      my $s = pop @{ $snippets{$what} };
      if ($s) {
        my $overlaps = 0;
        foreach my $prev (@already_seen) {
          if ( $self->_check_string_overlap( $s->{snippet}, $prev->{snippet} ) ) {
            $overlaps = 1;
            last;
          }
        }

        next if $overlaps;

        push @already_seen, $s;

        foreach my $term (@terms) {
          $s->{snippet} =~ s/($term)/<span class="highlight">$1<\/span>/gi;
        }

        push @{ $shownSnippets{$what} }, $s->{snippet};
        $count_lines++;
      }
    }

    # Stop if nothing is left
    last if ( !@{ $snippets{notes} } and !@{ $snippets{text} } and !@{ $snippets{abstract} } );
  }

  # Finally format the snippets for display

  my $output = '';
  foreach my $what (@what) {
    next if not @{ $shownSnippets{$what} };
    my $type;
    $type = 'Abstract' if $what eq 'abstract';
    $type = 'PDF'      if $what eq 'text';
    $type = 'Notes'    if $what eq 'notes';

    $output .= "<span class=\"heading\">$type: </span>";
    $output .= " \x{2026} ";
    $output .= join( " \x{2026} ", reverse @{ $shownSnippets{$what} } );
    $output .= " \x{2026} ";
  }


  return ($output);

}

# Checks what fraction of words overlap between $string_a and
# $string_b. Returns true if overlap is higher than 0.3.

sub _check_string_overlap {

  my ( $self, $string_a, $string_b ) = @_;

  my @words_a = split( /\s+/, $string_a );
  my @words_b = split( /\s+/, $string_b );

  my %hash = ();

  my $total_count   = 0;
  my $overlap_count = 1;

  foreach my $s (@words_a) {
    $hash{$s} = 1;
    $total_count++;
  }

  foreach my $s (@words_b) {
    $overlap_count++ if $hash{$s};
  }

  return ( $overlap_count / $total_count > 0.3 );
}

1;
