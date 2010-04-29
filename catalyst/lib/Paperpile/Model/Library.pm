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

package Paperpile::Model::Library;

use strict;
use Carp;
use base 'Paperpile::Model::DBIbase';
use Data::Dumper;
use Tree::Simple;
use XML::Simple;
use FreezeThaw qw/freeze thaw/;
use File::Path;
use File::Spec;
use File::Copy;
use File::stat;
use Moose;
use Paperpile::Model::App;
use Paperpile::Utils;
use MooseX::Timestamp;
use Encode qw(encode decode);
use File::Temp qw/ tempfile tempdir /;

use Paperpile::Library::Publication;
use Paperpile::Library::Author;

with 'Catalyst::Component::InstancePerContext';

has 'light_objects' => ( is => 'rw', isa => 'Int', default => 0 );

sub build_per_context_instance {
  my ( $self, $c ) = @_;
  my $file  = $c->session->{library_db};
  my $model = Paperpile::Model::Library->new();
  $model->set_dsn("dbi:SQLite:$file");
  return $model;
}

# Function: create_pubs
#
# Adds a list of publication entries to the local library. It first
# generates a unique citation-key and then adds the entries to the
# database via the insert_pubs function. Note that this function
# updates the entries in the $pubs array in place by adding the
# citekey field.

sub create_pubs {

  ( my $self, my $pubs ) = @_;

  my %to_be_inserted = ();

  my $dbh = $self->dbh;

  foreach my $pub (@$pubs) {
    eval {

      # Initialize some fields

      $pub->created( timestamp gmtime ) if not $pub->created;
      $pub->times_read(0);
      $pub->last_read('');
      $pub->_imported(1);

      # Generate citation key
      my $pattern = $self->get_setting('key_pattern');

      $pattern = '[firstauthor][YYYY]';

      my $key = $pub->format_pattern($pattern);

      # Check if key already exists

      # First we check in the database
      my $quoted = $dbh->quote("key:$key*");
      my $sth = $dbh->prepare(qq^SELECT key FROM fulltext WHERE fulltext MATCH $quoted^);
      my $existing_key;
      $sth->bind_columns( \$existing_key );
      $sth->execute;

      my @suffix = ();
      my $unique = 1;

      while ( $sth->fetch ) {
        $unique = 0;    # if we found something in the DB it is not unique

        # We collect the suffixes a,b,c... that already exist
        if ( $existing_key =~ /$key([a-z])/ ) {    #
          push @suffix, $1;
        }
      }

      # Then in the current list that have been already processed in this loop
      foreach my $existing_key ( @{ $to_be_inserted{$key} } ) {
        if ( $existing_key =~ /^$key([a-z])?/ ) {
          $unique = 0;
          push @suffix, $1 if $1;
        }
      }

      my $bare_key = $key;

      if ( not $unique ) {
        my $new_suffix = 'a';
        if (@suffix) {

          # we sort them to make sure to get the 'highest' suffix and count one up
          @suffix = sort { $a cmp $b } @suffix;
          $new_suffix = chr( ord( pop(@suffix) ) + 1 );
        }
        $key .= $new_suffix;
      }

      if ( not $to_be_inserted{$bare_key} ) {
        $to_be_inserted{$bare_key} = [$key];
      } else {
        push @{ $to_be_inserted{$bare_key} }, $key;
      }

      $pub->citekey($key);
    };
    warn $@ if $@;
  }

  $self->insert_pubs($pubs);

}

# Function: insert_pubs
#
# Inserts a list of publications into the database

sub insert_pubs {

  ( my $self, my $pubs ) = @_;

  my $dbh = $self->dbh;

  # to avoid sha1 constraint violation seems to be only very minor
  # performance overhead and any other attempts with OR IGNOR or eval {}
  # did not work.
  $self->exists_pub($pubs);

  $dbh->begin_work;

  my $counter = 0;

  foreach my $pub (@$pubs) {

    if ($pub->_imported){
      print STDERR $pub->sha1, " already exists. Skipped.\n";
      next;
    }

    # Sanity check. Should not come to this point without sha1 but we
    # had an error like this and that could have prevented a corrupted
    # database
    next if (!$pub->sha1);

    ## Insert main entry into Publications table
    my $tmp = $pub->as_hash();

    ( my $fields, my $values ) = $self->_hash2sql( $tmp, $dbh );

    $dbh->do("INSERT INTO publications ($fields) VALUES ($values)");

    ## Insert searchable fields into fulltext table
    my $pub_rowid = $dbh->func('last_insert_rowid');

    $pub->_rowid($pub_rowid);

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
      rowid    => $pub_rowid,
      key      => $pub->citekey,
      year     => $pub->year,
      journal  => $pub->journal,
      title    => $pub->title,
      abstract => $pub->abstract,
      notes    => $pub->annote,
      author   => $pub->_authors_display,
      label    => $pub->tags,
      labelid  => Paperpile::Utils->encode_tags( $pub->tags ),
      keyword  => $pub->keywords,
      folder   => $pub->folders,
    };

    ( $fields, $values ) = $self->_hash2sql( $hash, $dbh );

    $fields .= ",text";
    $values .= ",''";
    $dbh->do("INSERT INTO fulltext ($fields) VALUES ($values)");

    # GJ 2010-01-10 I *think* this should be here, but not sure...
    $pub->_imported(1);

    # Check if we can find a pdf (either directly given as pub->pdf or
    # in download cache folder) and attach it

    my $pdf_file = undef;

    my $cached_file =
      File::Spec->catfile( Paperpile::Utils->get_tmp_dir, "download", $pub->sha1 . ".pdf" );

    if ( $pub->pdf ) {
      $pdf_file = $pub->pdf;
    } elsif ( -e $cached_file ) {
      $pdf_file = $cached_file;
    }

    if ($pdf_file) {

      # First check if paper_root is set. In temporary databases
      # eg. for opening bibtex or RSS feeds it is not set and we don't
      # attach PDFs there
      my $paper_root = $self->get_setting('paper_root');

      if ( defined $paper_root ) {
        my $attached_file = $self->attach_file( $pdf_file, 1, $pub_rowid, $pub );
        unlink($pdf_file) if -e ($cached_file);
        $pub->pdf($attached_file);
      }
    }
  }

  $dbh->commit;

}

sub delete_pubs {

  ( my $self, my $pubs ) = @_;

  my $dbh = $self->dbh;

  $dbh->begin_work;

  # check if entry has any attachments an delete those
  foreach my $pub (@$pubs) {

    my $rowid = $pub->_rowid;

    # First delete attachments from Attachments table
    my $select = $dbh->prepare("SELECT rowid FROM Attachments WHERE publication_id=$rowid;");
    my $attachment_rowid;
    $select->bind_columns( \$attachment_rowid );
    $select->execute;
    while ( $select->fetch ) {
      $self->delete_attachment( $attachment_rowid, 0 );
    }

    # Then delete the PDF
    $self->delete_attachment( $rowid, 1 );
  }

  # Then delete the entry in all relevant tables
  my $delete_main              = $dbh->prepare("DELETE FROM publications WHERE rowid=?");
  my $delete_fulltext     = $dbh->prepare("DELETE FROM fulltext WHERE rowid=?");

  foreach my $pub (@$pubs) {
    my $rowid = $pub->_rowid;
    $delete_main->execute($rowid);
    $delete_fulltext->execute($rowid);
  }

  $dbh->commit;

  return 1;

}

sub trash_pubs {

  ( my $self, my $pubs, my $mode ) = @_;

  my $dbh = $self->dbh;

  $dbh->begin_work;

  my @files = ();

  # currently no explicit error handling/rollback etc.

  foreach my $pub (@$pubs) {
    my $rowid = $pub->_rowid;

    my $status = 1;
    $status = 0 if $mode eq 'RESTORE';

    $dbh->do("UPDATE Publications SET trashed=$status WHERE rowid=$rowid");

    # Created is used to store time of import as well as time of
    # deletion, so we set it everytime we trash or restore something
    my $now = $self->dbh->quote( timestamp gmtime );
    $dbh->do("UPDATE Publications SET created=$now WHERE rowid=$rowid;");

    # Move attachments
    my $select =
      $dbh->prepare("SELECT rowid, file_name FROM Attachments WHERE publication_id=$rowid;");

    my $attachment_rowid;
    my $file_name;

    $select->bind_columns( \$attachment_rowid, \$file_name );
    $select->execute;
    while ( $select->fetch ) {
      my $move_to;

      if ( $mode eq 'TRASH' ) {
        $move_to = File::Spec->catfile( "Trash", $file_name );
      } else {
        $move_to = $file_name;
        $move_to =~ s/Trash.//;
      }
      push @files, [ $file_name, $move_to ];
      $move_to = $dbh->quote($move_to);

      $dbh->do("UPDATE Attachments SET file_name=$move_to WHERE rowid=$attachment_rowid; ");

    }

    ( my $pdf ) = $self->dbh->selectrow_array("SELECT pdf FROM Publications WHERE rowid=$rowid ");

    if ($pdf) {
      my $move_to;

      if ( $mode eq 'TRASH' ) {
        $move_to = File::Spec->catfile( "Trash", $pdf );
      } else {
        $move_to = $pdf;
        $move_to =~ s/Trash.//;
      }
      push @files, [ $pdf, $move_to ];

      $move_to = $self->dbh->quote($move_to);

      $dbh->do("UPDATE Publications SET pdf=$move_to WHERE rowid=$rowid;");

    }

  }

  my $paper_root = $self->get_setting('paper_root');

  foreach my $pair (@files) {

    ( my $from, my $to ) = @$pair;

    $from = File::Spec->catfile( $paper_root, $from );
    $to   = File::Spec->catfile( $paper_root, $to );

    my ( $volume, $dir, $file_name ) = File::Spec->splitpath($to);

    mkpath($dir);
    move( $from, $to );

    ( $volume, $dir, $file_name ) = File::Spec->splitpath($from);

    # Never remove the paper_root even if its empty;
    if ( File::Spec->canonpath($paper_root) ne File::Spec->canonpath($dir) ) {

      # Simply remove it; will not do any harm if it is not empty; Did
      # not find an easy way to check if dir is empty, but it does not
      # seem necessary anyway TODO: recursively remove empty
      # directories, currently only one level is deleted
      rmdir $dir;
    }
  }

  $dbh->commit;

  return 1;

}

sub update_pub {

  ( my $self, my $old_pub, my $new_data ) = @_;

  my $data = $old_pub->as_hash;

  # add new fields to old entry
  foreach my $field ( keys %{$new_data} ) {
    $data->{$field} = $new_data->{$field};
  }

  my $new_pub = Paperpile::Library::Publication->new($data);

  # Save attachments in temporary dir
  my $tmp_dir = tempdir( CLEANUP => 1 );

  my @attachments = ();

  foreach my $file ( $self->get_attachments( $new_pub->_rowid ) ) {
    my ( $volume, $dirs, $base_name ) = File::Spec->splitpath($file);
    my $tmp_file = File::Spec->catfile( $tmp_dir, $base_name );
    copy( $file, $tmp_dir );
    push @attachments, $tmp_file;
  }

  my $pdf_file = '';

  if ( $new_pub->pdf ) {
    my $paper_root = $self->get_setting('paper_root');
    my $file = File::Spec->catfile( $paper_root, $new_pub->pdf );
    my ( $volume, $dirs, $base_name ) = File::Spec->splitpath($file);
    copy( $file, $tmp_dir );
    $pdf_file = File::Spec->catfile( $tmp_dir, $base_name );
    $new_pub->pdf('');    # unset to avoid that create_pub tries to
                          # attach the file which gives an error
  }

  # Delete and then re-create
  $self->delete_pubs( [$new_pub] );
  $self->create_pubs( [$new_pub] );

  # Attach files again afterwards. Is not the most efficient way but
  # currently the easiest and most robust solution.
  foreach my $file (@attachments) {
    $self->attach_file( $file, 0, $new_pub->_rowid, $new_pub );
  }
  if ($pdf_file) {
    $self->attach_file( $pdf_file, 1, $new_pub->_rowid, $new_pub );
  }

  $new_pub->_imported(1);
  $new_pub->attachments( scalar @attachments );

  return $new_pub;
}

sub get_attachments {

  my ( $self, $rowid ) = @_;

  my $sth =
    $self->dbh->prepare("SELECT rowid, file_name FROM Attachments WHERE publication_id=$rowid;");
  my ( $attachment_rowid, $file_name );
  $sth->bind_columns( \$attachment_rowid, \$file_name );
  $sth->execute;
  my $paper_root = $self->get_setting('paper_root');

  my @files = ();

  while ( $sth->fetch ) {
    push @files, File::Spec->catfile( $paper_root, $file_name );
  }

  return @files;
}

sub update_field {
  ( my $self, my $table, my $rowid, my $field, my $value ) = @_;

  $value = $self->dbh->quote($value);
  $self->dbh->do("UPDATE $table SET $field=$value WHERE rowid=$rowid");

}

sub update_citekeys {

  ( my $self, my $pattern ) = @_;

  my $data = $self->all('created');

  my %seen = ();

  $self->dbh->begin_work;

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

      $key = $self->dbh->quote($key);

      $self->dbh->do( "UPDATE Publications SET citekey=$key WHERE rowid=" . $pub->_rowid );
    }

    my $_pattern = $self->dbh->quote($pattern);
    $self->dbh->do("UPDATE Settings SET value=$_pattern WHERE key='key_pattern'");
    $self->dbh->commit;

  };

  if ($@) {
    die("Failed to update citation keys ($@)");

    # DBI driver seems to rollback do this automatically when the eval statement dies
    $self->dbh->rollback;
  }

}

# Update tag flat fields in Publication and Fulltext tables

sub _update_tags {

  ( my $self, my $pub_rowid, my $tags ) = @_;

  my $dbh = $self->dbh;

  my $encoded_tags = Paperpile::Utils->encode_tags($tags);

  $tags         = $dbh->quote($tags);
  $encoded_tags = $dbh->quote($encoded_tags);

  $dbh->do("UPDATE Publications SET tags=$tags WHERE rowid=$pub_rowid;");
  $dbh->do("UPDATE Fulltext SET label=$tags WHERE rowid=$pub_rowid;");

  $dbh->do("UPDATE Fulltext SET labelid=$encoded_tags WHERE rowid=$pub_rowid;");

}

sub update_tags {
  ( my $self, my $pub_rowid, my $tags ) = @_;

  my $dbh = $self->dbh;
  my @tags = split( /,/, $tags );

  $self->_update_tags( $pub_rowid, $tags );

  # Remove all connections form Tag_Publication table
  my $sth = $dbh->do("DELETE FROM Tag_Publication WHERE publication_id=$pub_rowid");

  # Then insert tags into Tag table (if not already exists) and set
  # new connections in Tag_Publication table

  my $count = $dbh->prepare("SELECT max(sort_order) FROM Tags;");
  my $max_sort;
  $count->bind_columns( \$max_sort );

  my $select = $dbh->prepare("SELECT rowid FROM Tags WHERE tag=?");
  my $insert = $dbh->prepare("INSERT INTO Tags (tag, style, sort_order) VALUES(?,?,?)");
  my $connection =
    $dbh->prepare("INSERT INTO Tag_Publication (tag_id, publication_id) VALUES(?,?)");

  foreach my $tag (@tags) {
    my $tag_rowid = undef;

    $select->bind_columns( \$tag_rowid );
    $select->execute($tag);
    $select->fetch;
    if ( not defined $tag_rowid ) {
      $count->execute();
      $count->fetch;
      $insert->execute( $tag, 'default', $max_sort+1 );
      $tag_rowid = $self->dbh->func('last_insert_rowid');
    }

    $connection->execute( $tag_rowid, $pub_rowid );
  }
}

sub new_tag {
  ( my $self, my $tag, my $style, my $sort_order ) = @_;

  # Update tags with higher sort_order values and increment by 1.
  #$self->dbh->do("UPDATE Tags SET sort_order=sort_order+1 WHERE sort_order >= $sort_order;");

  my $max_sort = 0;
  my $sth = $self->dbh->prepare("SELECT max(sort_order) FROM Tags;");
  $sth->bind_columns(\$max_sort);
  $sth->execute;
  $sth->fetch;

  $tag   = $self->dbh->quote($tag);
  $style = $self->dbh->quote($style);
  $self->dbh->do("INSERT INTO Tags (tag,style,sort_order) VALUES($tag, $style, $max_sort)");

}

sub delete_tag {
  ( my $self, my $tag ) = @_;

  my $dbh = $self->dbh;

  $dbh->begin_work;

  my $_tag = $dbh->quote($tag);

  # Select all publications with this tag
  ( my $tag_id ) = $dbh->selectrow_array("SELECT rowid FROM Tags WHERE tag=$_tag");
  my $select = $dbh->prepare(
    "SELECT tags, publication_id FROM Publications, Tag_Publication WHERE Publications.rowid=publication_id AND tag_id=$tag_id"
  );

  my ( $publication_id, $tags );
  $select->bind_columns( \$tags, \$publication_id );
  $select->execute;

  while ( $select->fetch ) {

    # Delete tag from flat string in Publications/Fulltext table

    my $new_tags = $tags;
    $new_tags =~ s/^\Q$tag\E$//;
    $new_tags =~ s/^\Q$tag\E,//;
    $new_tags =~ s/,\Q$tag\E,/,/;
    $new_tags =~ s/,\Q$tag\E$//;

    $self->_update_tags( $publication_id, $new_tags );

  }

  # Delete tag from Tags table and link table
  $dbh->do("DELETE FROM Tags WHERE rowid=$tag_id");
  $dbh->do("DELETE FROM Tag_Publication WHERE tag_id=$tag_id");

  $dbh->commit;

}

sub rename_tag {
  my ( $self, $old_tag, $new_tag ) = @_;

  my $dbh = $self->dbh;

  $dbh->begin_work;

  my $_old_tag = $dbh->quote($old_tag);

  ( my $old_tag_id ) = $dbh->selectrow_array("SELECT rowid FROM Tags WHERE tag=$_old_tag");
  my $select = $self->dbh->prepare(
    "SELECT tags, publication_id FROM Publications, Tag_Publication WHERE Publications.rowid=publication_id AND tag_id=$old_tag_id"
  );

  my ( $publication_id, $old_tags );
  $select->bind_columns( \$old_tags, \$publication_id );
  $select->execute;

  while ( $select->fetch ) {

    my $new_tags = $old_tags;

    $new_tags =~ s/^\Q$old_tag\E$/$new_tag/;
    $new_tags =~ s/^\Q$old_tag\E,/$new_tag,/;
    $new_tags =~ s/,\Q$old_tag\E,/,$new_tag,/;
    $new_tags =~ s/,\Q$old_tag\E$/,$new_tag/;

    $self->_update_tags( $publication_id, $new_tags );
  }

  $new_tag = $dbh->quote($new_tag);

  $dbh->do("UPDATE Tags SET tag=$new_tag WHERE rowid=$old_tag_id;");

  $dbh->commit;

}


sub new_collection {

  my ( $self, $guid, $name, $type, $parent, $style, $data ) = @_;

  my $dbh = $self->dbh;

  $data = freeze($data);

  if ( $parent =~ /ROOT/ ) {
    $parent = 'ROOT';
  }

  $guid   = $dbh->quote($guid);
  $name   = $dbh->quote($name);
  $type   = $dbh->quote($type);
  $parent = $dbh->quote($parent);
  $style  = $dbh->quote($style);
  $data   = $dbh->quote($data);

  ( my $sort_order ) =
    $dbh->selectrow_array("SELECT max(sort_order) FROM Collections WHERE parent=$parent");

  if (defined $sort_order){
    $sort_order++;
  } else {
    $sort_order = 0;
  }

  $self->dbh->do(
    "INSERT INTO Collections (guid, name, type, parent, sort_order, style, data) VALUES($guid, $name, $type, $parent, $sort_order, $style, $data)"
  );

  #print STDERR Dumper(\@_);

}



sub insert_folder {
  ( my $self, my $folder_id ) = @_;

  my $select = $self->dbh->prepare("SELECT rowid FROM Folders WHERE folder_id=?");
  my $insert = $self->dbh->prepare("INSERT INTO Folders (folder_id) VALUES(?)");

  my $folder_rowid = undef;

  $select->bind_columns( \$folder_rowid );
  $select->execute($folder_id);
  $select->fetch;
  if ( not defined $folder_rowid ) {
    $insert->execute($folder_id);
    $folder_rowid = $self->dbh->func('last_insert_rowid');
  }

  return $folder_rowid;

}

sub update_folders {
  ( my $self, my $pub_rowid, my $folders ) = @_;

  my $dbh = $self->dbh;

  my @folders = split( /,/, $folders );

  # First update flat field in Publication and Fulltext tables
  $folders = $dbh->quote($folders);

  $dbh->do("UPDATE Publications SET folders=$folders WHERE rowid=$pub_rowid;");
  $dbh->do("UPDATE Fulltext SET folder=$folders WHERE rowid=$pub_rowid;");

  # Remove all connections from Folder_Publication table
  my $sth = $dbh->do("DELETE FROM Folder_Publication WHERE publication_id=$pub_rowid");

  # Then insert folders into Folder table (if not already exists) and set
  # new connections in Folder_Publication table

  my $select = $dbh->prepare("SELECT rowid FROM Folders WHERE folder_id=?");
  my $connection =
    $dbh->prepare("INSERT INTO Folder_Publication (folder_id, publication_id) VALUES(?,?)");

  foreach my $folder (@folders) {
    my $folder_rowid = undef;

    $select->bind_columns( \$folder_rowid );
    $select->execute($folder);
    $select->fetch;
    if ( not defined $folder_rowid ) {
      croak('Folder does not exists');
    }

    $connection->execute( $folder_rowid, $pub_rowid );
  }
}

sub delete_folder {
  ( my $self, my $folder_ids ) = @_;

  #  Delete all assications in Folder_Publication table
  my $delete1 = $self->dbh->prepare(
    "DELETE FROM Folder_Publication WHERE folder_id IN (SELECT rowid from Folders WHERE Folders.folder_id=?)"
  );

  #  Delete folders from Folders table
  my $delete2 = $self->dbh->prepare("DELETE FROM Folders WHERE folder_id=?");

  #  Update flat fields in Publication table and Fulltext table
  my $update1 = $self->dbh->prepare("UPDATE Publications SET folders=? WHERE rowid=?");
  my $update2 = $self->dbh->prepare("UPDATE Fulltext SET folder=? WHERE rowid=?");

  foreach my $id (@$folder_ids) {

    my ( $folders, $rowid );

    # Get the publications that are in the given folder
    my $select = $self->dbh->prepare(
      "SELECT publications.rowid as rowid, publications.folders as folders FROM Publications JOIN fulltext
     ON publications.rowid=fulltext.rowid WHERE fulltext MATCH 'folder:$id'"
    );

    $select->bind_columns( \$rowid, \$folders );
    $select->execute;
    while ( $select->fetch ) {

      my $newFolders = $self->_remove_from_flatlist( $folders, $id );

      $update1->execute( $newFolders, $rowid );
      $update2->execute( $newFolders, $rowid );
    }

    $delete1->execute($id);
    $delete2->execute($id);

  }
}

sub get_tags {
  ( my $self ) = @_;

  my $sth = $self->dbh->prepare("SELECT tag,style,sort_order from Tags;");

  my ( $tag, $style, $sort_order );
  $sth->bind_columns( \$tag, \$style, \$sort_order );

  $sth->execute;

  my @out = ();

  while ( $sth->fetch ) {
    push @out, { tag => $tag, style => $style, sort_order => $sort_order || 0 };
  }

  return [@out];
}

sub set_tag_position {

  my ( $self, $tag, $position ) = @_;

  $tag = $self->dbh->quote($tag);
  $self->dbh->do("UPDATE TAGS SET sort_order=$position WHERE tag=$tag;");
}

sub set_tag_style {

  my ( $self, $tag, $style ) = @_;

  $tag   = $self->dbh->quote($tag);
  $style = $self->dbh->quote($style);

  $self->dbh->do("UPDATE TAGS SET style=$style WHERE tag=$tag;");

}

sub get_folders {
  ( my $self ) = @_;

  my $sth = $self->dbh->prepare("SELECT folder_id from Folders;");

  $sth->execute();
  my @out = ();

  foreach my $folder ( @{ $sth->fetchall_arrayref } ) {
    push @out, $folder->[0];
  }
  return [@out];
}

## Return true or false, depending whether a row with unique value
## $value in column $column exists in table $table

sub has_unique_entry {

  ( my $self, my $table, my $column, my $value ) = @_;
  $value = $self->dbh->quote($value);

  my $sth = $self->dbh->prepare("SELECT $column FROM $table WHERE $column=$value");

  $sth->execute();

  if ( $sth->fetchrow_arrayref ) {
    return 1;
  } else {
    return 0;
  }
}

sub reset_db {

  ( my $self ) = @_;

  for my $table (
    qw/publications authors journals folders tags fulltext
    author_publication tag_publication folder_publication/
    ) {
    $self->dbh->do("DELETE FROM $table");
  }

  return 1;
}

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
        'text',  'abstract', 'notes',   'title',  'key',  'author',
        'label', 'labelid',  'keyword', 'folder', 'year', 'journal'
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
      push @new_fields, $field;
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

  my ( $where, $select );
  if ($query) {
    $select =
      "select count(*) from Publications join Fulltext on publications.rowid=Fulltext.rowid ";
    $query = $self->process_query_string($query);
    $where = "WHERE Fulltext MATCH $query AND Publications.trashed=$trash ";
  } else {
    $select = "select count(*) from Publications ";
    $where = "WHERE trashed=$trash ";
  }

  #print STDERR "===> Count query: $select $where\n";

  my $count = $self->dbh->selectrow_array("$select $where");

  return $count;
}

sub fulltext_search {

  ( my $self, my $_query, my $offset, my $limit, my $order, my $trash, my $do_order ) = @_;

  if ($do_order) {

    # Custom rank function to distinguish hits in meta data and fulltext
    $self->dbh->sqlite_create_function(
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
        # the 12 columns in our fulltext table
        # Order: text abstract notes title key author label labelid keyword folder year journal
        my @counts = ( 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 );

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

        my $weights = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

        # If hit occured in title, key, author, year or journal we show them first
        my $sum = $counts[3] + $counts[4] + $counts[5] + $counts[10] + $counts[11];

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
      ",offsets(Fulltext) as offsets FROM Publications JOIN Fulltext ON Publications.rowid=Fulltext.rowid ";

    $query = $self->process_query_string($_query);

    $where = "WHERE Fulltext MATCH $query AND Publications.trashed=$trash";
    if ($do_order) {
      $rank = "ORDER BY rank(matchinfo(Fulltext)) DESC, $order";
    } else {
      $rank = "";
    }

    $sth = $self->dbh->prepare("$select $where $rank LIMIT $limit OFFSET $offset");
    #print STDERR "$select $where $rank LIMIT $limit OFFSET $offset\n";

  } else {
    $select .= ' FROM Publications ';
    $order =~ s/author/authors/;
    $order =~ s/notes/annote/;
    $where = "WHERE Publications.trashed=$trash";

    $sth   = $self->dbh->prepare("$select $where ORDER BY $order LIMIT $limit OFFSET $offset");
    #print STDERR "$select $where ORDER BY $order LIMIT $limit OFFSET $offset\n";
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

    $pub->_imported(1);

    push @page, $pub;
  }

  return [@page];
}

sub standard_count {
  ( my $self, my $query ) = @_;

  my $count = $self->dbh->selectrow_array("SELECT COUNT(*) FROM Publications WHERE $query;");

  return $count;

}

sub standard_search {
  ( my $self, my $query, my $offset, my $limit ) = @_;

  my $sth = $self->dbh->prepare("SELECT rowid as _rowid, * FROM Publications WHERE $query;");

  #  print STDERR "SELECT rowid as _rowid, * FROM Publications WHERE $query\n";

  $sth->execute;

  my @page = ();

  while ( my $row = $sth->fetchrow_hashref() ) {
    my $pub = Paperpile::Library::Publication->new( { _light => $self->light_objects } );
    foreach my $field ( keys %$row ) {
      my $value = $row->{$field};
      if ($value) {
        $pub->$field($value);
      }
    }
    $pub->_imported(1);
    push @page, $pub;
  }

  return [@page];
}

sub all {

  my ( $self, $order ) = @_;

  my $query = "SELECT rowid as _rowid, * FROM Publications ";

  if ($order) {
    $query .= "ORDER BY $order";
  }

  my $sth = $self->dbh->prepare($query);

  $sth->execute;

  my @page = ();

  while ( my $row = $sth->fetchrow_hashref() ) {
    my $pub = Paperpile::Library::Publication->new( { _light => $self->light_objects } );
    foreach my $field ( keys %$row ) {
      my $value = $row->{$field};
      if ($value) {
        $pub->$field($value);
      }
    }
    $pub->_imported(1);
    push @page, $pub;
  }

  return [@page];

}

# Gets all entries as simple hash. Is much faster than building
# Publication objects which is not necessary for some tasks such as
# finding duplicates

sub all_as_hash {

  my ( $self, $order ) = @_;

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

  return [@data];

}

sub exists_pub {
  ( my $self, my $pubs ) = @_;

  my $sth = $self->dbh->prepare("SELECT rowid, * FROM publications WHERE sha1=?");

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
        } else {
          if ($value) {
            $pub->$field($value);
          }
        }
      }
    }

    $pub->_imported($exists);

  }
}

# Small helper function that converts hash to sql syntax (including
# quotes). Also passed the database handel to avoid calling $self->dbh
# all the time which turned out to be a bottle neck
sub _hash2sql {

  ( my $self, my $hash, my $dbh ) = @_;

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
      push @values, $dbh->quote($value);
    }
  }

  my @output = ( join( ',', @fields ), join( ',', @values ) );

  return @output;
}

sub save_tree {

  ( my $self, my $tree ) = @_;

  # serialize the complete object
  my $string = freeze($tree);

  # simply save it as user setting
  $self->set_setting( '_tree', $string );

}

sub restore_tree {
  ( my $self ) = @_;

  my $string = $self->get_setting('_tree');

  if ( not $string ) {
    return undef;
  }

  ( my $tree ) = thaw($string);

  return $tree;

}

sub delete_from_folder {
  ( my $self, my $data, my $folder_id ) = @_;

  my $dbh = $self->dbh;

  $dbh->begin_work;

  foreach my $pub (@$data) {

    my $row_id = $pub->_rowid;

    ( my $folders ) = $dbh->selectrow_array("SELECT folders FROM Publications WHERE rowid=$row_id");

    my $newFolders = $self->_remove_from_flatlist( $folders, $folder_id );

    my $quotedFolders = $dbh->quote($newFolders);

    $dbh->do("UPDATE Publications SET folders=$quotedFolders WHERE rowid=$row_id");
    $dbh->do("UPDATE fulltextl SET folder=$quotedFolders WHERE rowid=$row_id");
    $dbh->do(
             "DELETE FROM Folder_Publication WHERE (folder_id IN (SELECT rowid FROM Folders WHERE folder_id=$folder_id) AND publication_id=$row_id)"
    );

    $pub->folders($newFolders);
  }

  $dbh->commit;

}

sub attach_file {

  my ( $self, $file, $is_pdf, $rowid, $pub ) = @_;

  my $settings = $self->settings;

  my $source = Paperpile::Utils->adjust_root($file);

  if ($is_pdf) {

    # File name relative to [paper_root] is [pdf_pattern].pdf
    my $relative_dest =
      $pub->format_pattern( $settings->{pdf_pattern}, { key => $pub->citekey } ) . ".pdf";

    # Absolute  path is [paper_root]/[pdf_pattern].pdf
    my $absolute_dest = File::Spec->catfile( $settings->{paper_root}, $relative_dest );

    # Copy file, file name can be changed if it was not unique
    $absolute_dest = Paperpile::Utils->copy_file( $source, $absolute_dest );

    # Add text of PDF to fulltext table
    $self->index_pdf( $rowid, $absolute_dest );

    $relative_dest = File::Spec->abs2rel( $absolute_dest, $settings->{paper_root} );

    $self->update_field( 'Publications', $rowid, 'pdf',        $relative_dest );
    $self->update_field( 'Publications', $rowid, 'pdf_size',   stat($file)->size );
    $self->update_field( 'Publications', $rowid, 'times_read', 0 );
    $self->update_field( 'Publications', $rowid, 'last_read',  '' );

    $pub->pdf($relative_dest);

    return $relative_dest;

  } else {

    # Get file_name without dir
    my ( $volume, $dirs, $file_name ) = File::Spec->splitpath($source);

    # Path relative to [paper_root] is [attachment_pattern]/$file_name
    my $relative_dest =
      $pub->format_pattern( $settings->{attachment_pattern}, { key => $pub->citekey } );
    $relative_dest = File::Spec->catfile( $relative_dest, $file_name );

    # Absolute  path is [paper_root]/[attachment_pattern]/$file_name
    my $absolute_dest = File::Spec->catfile( $settings->{paper_root}, $relative_dest );

    # Copy file, file name can be changed if it was not unique
    $absolute_dest = Paperpile::Utils->copy_file( $source, $absolute_dest );
    $relative_dest = File::Spec->abs2rel( $absolute_dest, $settings->{paper_root} );

    $self->dbh->do("UPDATE Publications SET attachments=attachments+1 WHERE rowid=$rowid");
    my $file = $self->dbh->quote($relative_dest);
    $self->dbh->do("INSERT INTO Attachments (file_name,publication_id) VALUES ($file, $rowid)");

    return $relative_dest;

  }

}

# Delete PDF or other supplementary files that are attached to an entry
# if $is_pdf is true, the PDF file given in table 'Publications' at rowid is to be deleted
# if $is_pdf is false, the attached file in table 'Attachments' at rowid is to be deleted

sub delete_attachment {

  my ( $self, $rowid, $is_pdf, $with_undo ) = @_;

  my $paper_root = $self->get_setting('paper_root');

  my $path;

  my $undo_dir = File::Spec->catfile( Paperpile::Utils->get_tmp_dir(), "trash" );
  mkpath($undo_dir);

  if ($is_pdf) {
    ( my $pdf ) = $self->dbh->selectrow_array("SELECT pdf FROM Publications WHERE rowid=$rowid ");

    if ($pdf) {
      $path = File::Spec->catfile( $paper_root, $pdf );
      $self->dbh->do("UPDATE Fulltext SET text='' WHERE rowid=$rowid");
      move( $path, $undo_dir ) if $with_undo;
      unlink($path);
    }

    $self->update_field( 'Publications', $rowid, 'pdf',        '' );
    $self->update_field( 'Publications', $rowid, 'times_read', 0 );
    $self->update_field( 'Publications', $rowid, 'last_read',  '' );

  } else {

    ( my $file, my $pub_rowid ) = $self->dbh->selectrow_array(
      "SELECT file_name, publication_id FROM Attachments WHERE rowid=$rowid");

    $path = File::Spec->catfile( $paper_root, $file );

    move( $path, $undo_dir ) if $with_undo;
    unlink($path);

    $self->dbh->do("DELETE FROM Attachments WHERE rowid=$rowid");
    $self->dbh->do("UPDATE Publications SET attachments=attachments-1 WHERE rowid=$pub_rowid");

  }

  ## Remove directory if empty

  if ($path) {
    my ( $volume, $dir, $file_name ) = File::Spec->splitpath($path);

    # Never remove the paper_root even if its empty;
    if ( File::Spec->canonpath($paper_root) ne File::Spec->canonpath($dir) ) {

      # Simply remove it; will not do any harm if it is not empty; Did not
      # find an easy way to check if dir is empty, but it does not seem
      # necessary anyway
      rmdir $dir;
    }
  }

  if ($with_undo) {
    my ( $volume, $dir, $file_name ) = File::Spec->splitpath($path);
    return File::Spec->catfile( $undo_dir, $file_name );
  }

}

sub index_pdf {

  my ( $self, $rowid, $pdf_file ) = @_;

  my $app_model = Paperpile::Model::App->new();
  my $app_db    = Paperpile::Utils->path_to('db/app.db');
  $app_model->set_dsn("dbi:SQLite:$app_db");

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

  $text = $self->dbh->quote($text);

  $self->dbh->do("UPDATE Fulltext SET text=$text WHERE rowid=$rowid");

}

sub histogram {

  my ( $self, $field ) = @_;

  my %hist = ();

  if ( $field eq 'authors' ) {

    my $sth = $self->dbh->prepare('SELECT authors from Publications WHERE trashed=0;');

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

  if ( $field eq 'tags' ) {

    my ( $tag_id, $tag, $style );

    # Select all tags and initialize the histogram counts.
    my $sth = $self->dbh->prepare(qq^SELECT rowid,tag,style FROM Tags;^);
    $sth->bind_columns( \$tag_id, \$tag, \$style );
    $sth->execute;
    while ( $sth->fetch ) {
      $style = $style || 'default';
      $hist{$tag_id}->{count} = 0;
      $hist{$tag_id}->{name}  = $tag;
      $hist{$tag_id}->{id}    = $tag_id;
      $hist{$tag_id}->{style} = $style;
    }

    # Select tag-publication links and count them up.
    $sth = $self->dbh->prepare(
      qq^SELECT tag_id,tag,style FROM Tags, Tag_Publication, Publications WHERE Tag_Publication.tag_id == Tags.rowid 
          AND Publications.rowid == Tag_Publication.publication_id AND Publications.trashed==0 ^
    );
    $sth->bind_columns( \$tag_id, \$tag, \$style );
    $sth->execute;

    while ( $sth->fetch ) {
      if ( exists $hist{$tag_id} ) {
        $hist{$tag_id}->{count}++;
      }
    }

  }

  if ( $field eq 'journals' or $field eq 'pubtype' ) {

    $field = 'journal' if ( $field eq 'journals' );

    my $sth = $self->dbh->prepare("SELECT $field FROM Publications WHERE trashed=0;");
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

  return {%hist};

}

sub dashboard_stats {

  my $self = shift;

  ( my $num_items ) = $self->dbh->selectrow_array("SELECT count(*) FROM Publications;");

  ( my $num_pdfs ) =
    $self->dbh->selectrow_array("SELECT count(*) FROM Publications WHERE PDF !='';");

  ( my $num_attachments ) = $self->dbh->selectrow_array("SELECT count(*) FROM Attachments;");

  ( my $last_imported ) =
    $self->dbh->selectrow_array("SELECT created FROM Publications ORDER BY created DESC limit 1;");

  return {
    num_items       => $num_items,
    num_pdfs        => $num_pdfs,
    num_attachments => $num_attachments,
    last_imported   => $last_imported
  };

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

sub _snippets {

  my ( $self, $row, $query ) = @_;

  if ( not $query ) {
    return ('');
  }

  my %data;

  $data{text}     = encode( 'UTF-8', $row->{text} );
  $data{abstract} = encode( 'UTF-8', $row->{abstract} );
  $data{notes}    = encode( 'UTF-8', $row->{notes} );

  my $offsets = $row->{offsets};

  $query =~ s/^\s+//;
  $query =~ s/\s+$//;
  $query =~ s/"//g;
  $query =~ s/\S+://g;
  $query =~ s/and//gi;
  $query =~ s/or//gi;
  $query =~ s/not//gi;
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

  # This is the order of our fields in the fulltext table
  my @fields = ( 'text', 'abstract', 'notes' );

  my %snippets = ( text => [], abstract => [], notes => [] );

  while ( $offsets =~ /(\d+) (\d+) (\d+) (\d+)/g ) {

    my ( $column, $term, $start, $length ) = ( $1, $2, $3, $4 );

    # We only generate snippets for text, abstract and notes
    next if ( $column > 2 );

    my $field = $fields[$column];

    if ( scalar @{ $snippets{$field} } < 5 ) {

      my $snippet;
      my $match = substr( $data{$field}, $start, $length );

      my $context = 100;

      my $before;

      if ( $start < $context ) {
        $before = substr( $data{$field}, 0, $start );
      } else {
        $before = substr( $data{$field}, $start - $context, $context );
      }

      my $after = substr( $data{$field}, $start + $length, $context );

      #$before = decode( 'UTF-8', $before );
      #$after = decode( 'UTF-8', $before );

      if ( $before =~ /(^|[.?!]\s+)([A-Z].*)/ ) {
        $before = $2;
      }

      if ( $after =~ /(.*[.?!])\s+($|[A-Z])/ ) {
        $after = $1;
      }

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

      my $score = 0;

      $snippet = "$before $match $after";

      foreach my $term (@terms) {
        while ( $snippet =~ /$term/g ) {
          $score += 1;
        }
      }

      #$snippet = "\x{2026}" . $snippet . "\x{2026}";

      push @{ $snippets{$field} }, { snippet => $snippet, score => $score };
    }
  }

  my $output = '<br>';

  foreach my $what ( 'text', 'abstract', 'notes' ) {

    $snippets{$what} = [ sort { $a->{score} <=> $b->{score} } @{ $snippets{$what} } ];

    foreach my $s ( @{ $snippets{$what} } ) {
      $output .= $s->{snippet} . "(" . $s->{score} . ")" . "<br>";
    }
    $output .= "<br>";
  }

  return ($output);

}

sub _lcss {
  my ( $self, $needle, $haystack ) = @_;
  ( $needle, $haystack ) = ( $haystack, $needle )
    if length $$needle > length $$haystack;

  my ( $longest_c, $longest ) = 0;
  for my $start ( 0 .. length $$needle ) {
    for my $len ( reverse $start + 1 .. length $$needle ) {
      my $substr = substr( $$needle, $start, $len );
      length $1 > $longest_c and ( $longest_c, $longest ) = ( length $1, $1 )
        while $$haystack =~ m[($substr)]g;
    }
  }
  return $longest;
}



1;
