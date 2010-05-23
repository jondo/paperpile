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
use MooseX::Timestamp;
use Encode qw(encode decode);
use File::Temp qw/ tempfile tempdir /;
use Data::GUID;

use Paperpile::Library::Publication;
use Paperpile::Library::Author;
use Paperpile::Model::App;
use Paperpile::Utils;

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

    if (!$pub->guid){
      my $_guid=Data::GUID->new;
      $_guid=$_guid->as_hex;
      $_guid=~s/^0x//;
      $pub->guid($_guid);
    }

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
      labelid  => $pub->tags,
      folderid => $pub->folders,
      keyword  => $pub->keywords,
    };

    ( $fields, $values ) = $self->_hash2sql( $hash, $dbh );

    $fields .= ",text";
    $values .= ",''";
    $dbh->do("INSERT INTO fulltext ($fields) VALUES ($values)");

    # GJ 2010-01-10 I *think* this should be here, but not sure...
    $pub->_imported(1);



    # If there is a downloaded PDF in the cache folder and
    # "paper_root" is defined (i.e. this is our main DB and not a
    # temporary DB for e.g. RSS or BibTeX) we consider this for
    # import.

    my $cached_file =
      File::Spec->catfile( Paperpile::Utils->get_tmp_dir, "download", $pub->sha1 . ".pdf" );

    my $paper_root = $self->get_setting('paper_root');

    if ( defined $paper_root && -e $cached_file) {
      $pub->_pdf_tmp($cached_file);
    }

    if ($pub->_pdf_tmp) {
      $self->attach_file( $pub->_pdf_tmp, 1, $pub );
    }
  }

  $dbh->commit;

}

sub delete_pubs {

  ( my $self, my $pubs ) = @_;

  my $dbh = $self->dbh;

  $dbh->begin_work;

  # Delete attachments
  foreach my $pub (@$pubs) {

    # PDF
    $self->delete_attachment($pub->pdf, 1,$pub) if $pub->pdf;

    # Other files
    foreach my $guid (split(',', $pub->attachments || '')) {
      $self->delete_attachment( $guid, 0, $pub );
    }
  }

  # Then delete the entry in all relevant tables
  my $delete_main         = $dbh->prepare("DELETE FROM publications WHERE rowid=?");
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

  my $paper_root = $self->get_setting('paper_root');

  $dbh->begin_work;

  my @files = ();

  # currently no explicit error handling/rollback etc.

  foreach my $pub (@$pubs) {
    my $pub_guid = $pub->guid;

    my $status = 1;
    $status = 0 if $mode eq 'RESTORE';

    # The field 'created' is used to store time of import as well as time of
    # deletion, so we set it everytime we trash or restore something
    my $now = $dbh->quote( timestamp gmtime );
    $dbh->do("UPDATE Publications SET trashed=$status,created=$now WHERE guid='$pub_guid'");


    # Move attachments
    my $select =
      $dbh->prepare("SELECT guid, local_file FROM Attachments WHERE publication='$pub_guid';");

    my $attachment_guid;
    my $file_absolute;

    $select->bind_columns( \$attachment_guid, \$file_absolute );
    $select->execute;
    while ( $select->fetch ) {
      my $move_to;
      my $file_relative = File::Spec->abs2rel($file_absolute, $paper_root);
      if ( $mode eq 'TRASH' ) {
        $move_to = File::Spec->catfile( $paper_root, "Trash", $file_relative );
      } else {
        $move_to = $file_relative;
        $move_to =~ s/Trash.//;
        $move_to = File::Spec->catfile( $paper_root, $move_to );
      }
      push @files, [ $file_absolute, $move_to ];
      $move_to = $dbh->quote($move_to);

      $dbh->do("UPDATE Attachments SET local_file=$move_to WHERE guid='$attachment_guid';");

    }
  }

  foreach my $pair (@files) {

    ( my $from, my $to ) = @$pair;

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
  my $diff = {};
  my $settings = $self->settings;

  # Figure out fields that have changed
  foreach my $field ( keys %{$new_data} ) {
    if ($new_data->{$field} ne $data->{$field}){
      $diff->{$field} = $new_data->{$field};
    }
    $data->{$field} = $new_data->{$field};
  }

  # Create pub object with updated data
  my $new_pub = Paperpile::Library::Publication->new($data);

  # Also update sha1 if it has changed
  if ($new_pub->sha1 ne $old_pub->sha1){
    $diff->{sha1} = $new_pub->sha1;
  }

  my $dbh = $self->dbh;

  my @list;

  foreach my $field (keys %{$diff}){
    push @list, "$field=".$dbh->quote($diff->{$field});
  }

  my $sql = join(',',@list);
  my $guid=$new_pub->guid;

  $dbh->do("UPDATE Publications SET $sql WHERE guid='$guid';");

  if ($new_pub->{pdf} || $new_pub->{attachments}){

    #my $new_name;

    #if ($row->{is_pdf}){
    #  $new_name = 
    #}

    #my $file_relative = File::Spec->abs2rel($file_absolute, $paper_root);

    #$relative_dest =
    #  $pub->format_pattern( $settings->{attachment_pattern}, { key => $pub->citekey } );
    #$relative_dest = File::Spec->catfile( $relative_dest, $base_name );


    my $sth = $dbh->prepare("SELECT * FROM Attachments WHERE publication='$guid';");
    $sth->execute;
    while ( my $row = $sth->fetchrow_hashref() ) {
      print STDERR $row->{is_pdf}, $row->{name}, $row->{local_file}, "\n";
    }
  }

  return $new_pub;

  # Save attachments in temporary dir
  #my $tmp_dir = tempdir( CLEANUP => 1 );

  #my @attachments = ();

  #foreach my $file ( $self->get_attachments( $new_pub->_rowid ) ) {
  #  my ( $volume, $dirs, $base_name ) = File::Spec->splitpath($file);
  #  my $tmp_file = File::Spec->catfile( $tmp_dir, $base_name );
  #  copy( $file, $tmp_dir );
  #  push @attachments, $tmp_file;
  #}

  #my $pdf_file = '';

  # if ( $new_pub->pdf ) {
  #   my $paper_root = $self->get_setting('paper_root');
  #   my $file = File::Spec->catfile( $paper_root, $new_pub->pdf );
  #   my ( $volume, $dirs, $base_name ) = File::Spec->splitpath($file);
  #   copy( $file, $tmp_dir );
  #   $pdf_file = File::Spec->catfile( $tmp_dir, $base_name );
  #   $new_pub->pdf('');    # unset to avoid that create_pub tries to
  #                         # attach the file which gives an error
  # }

  # # Delete and then re-create
  # $self->delete_pubs( [$new_pub] );
  # $self->create_pubs( [$new_pub] );

  # # Attach files again afterwards. Is not the most efficient way but
  # # currently the easiest and most robust solution.
  # foreach my $file (@attachments) {
  #   $self->attach_file( $file, 0, $new_pub->_rowid, $new_pub );
  # }
  # if ($pdf_file) {
  #   $self->attach_file( $pdf_file, 1, $new_pub->_rowid, $new_pub );
  # }

  # $new_pub->_imported(1);
  # $new_pub->attachments( scalar @attachments );

  # return $new_pub;
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


sub new_collection {

  my ( $self, $guid, $name, $type, $parent, $style ) = @_;

  my $dbh = $self->dbh;

  if ( $parent =~ /ROOT/ ) {
    $parent = 'ROOT';
  }

  $guid   = $dbh->quote($guid);
  $name   = $dbh->quote($name);
  $type   = $dbh->quote($type);
  $parent = $dbh->quote($parent);
  $style  = $dbh->quote($style);

  ( my $sort_order ) =
    $dbh->selectrow_array("SELECT max(sort_order) FROM Collections WHERE parent=$parent AND type=$type");

  if ( defined $sort_order ) {
    $sort_order++;
  } else {
    $sort_order = 0;
  }

  $self->dbh->do(
    "INSERT INTO Collections (guid, name, type, parent, sort_order, style) VALUES($guid, $name, $type, $parent, $sort_order, $style)"
  );

  #print STDERR Dumper(\@_);

}

sub update_collections {
  ( my $self, my $pub, my $type ) = @_;

  my $what = $type eq 'FOLDER' ? 'folders' : 'tags';

  my $rowid    = $pub->_rowid;
  my $pub_guid = $pub->guid;

  my $dbh = $self->dbh;

  my $guid_list = $pub->$what;
  my @guids = split( /,/, $pub->$what );

  # First update flat field in Publication and Fulltext tables
  $guid_list = $dbh->quote($guid_list);

  $dbh->do("UPDATE Publications SET $what=$guid_list WHERE rowid=$rowid;");

  my $field = $type eq 'FOLDER' ? 'folderid' : 'labelid';

  $dbh->do("UPDATE Fulltext SET $field=$guid_list WHERE rowid=$rowid;");

  # Remove all connections from Collection_Publication table
  my $sth = $dbh->do("DELETE FROM Collection_Publication WHERE collection_guid IN (SELECT guid FROM Collections WHERE Collections.type='$type') AND publication_guid='$pub_guid'");

  # Then set new connections
  my $connection = $dbh->prepare(
    "INSERT INTO Collection_Publication (collection_guid, publication_guid) VALUES(?,?)");

  foreach my $collection_guid (@guids) {
    $connection->execute( $collection_guid, $pub_guid );
  }
}

sub remove_from_collection {

  my ( $self, $data, $collection_guid, $type ) = @_;

  my $what = $type eq 'FOLDER' ? 'folders' : 'tags';

  my $dbh = $self->dbh;

  $dbh->begin_work;

  foreach my $pub (@$data) {

    my $pub_rowid = $pub->_rowid;
    my $pub_guid  = $pub->guid;

    ( my $old_list ) =
      $dbh->selectrow_array("SELECT $what FROM Publications WHERE rowid=$pub_rowid");

    my $new_list = $self->_remove_from_flatlist( $old_list, $collection_guid );

    $dbh->do("UPDATE Publications SET $what='$new_list' WHERE rowid=$pub_rowid");

    my $field = $type eq 'FOLDER' ? 'folderid' : 'labelid';

    $dbh->do("UPDATE fulltext SET $field='$new_list' WHERE rowid=$pub_rowid");
    $dbh->do(
             "DELETE FROM Collection_Publication WHERE collection_guid='$collection_guid' AND publication_guid='$pub_guid'"
    );

    $pub->$what($new_list);
  }

  $dbh->commit;

}


sub delete_collection {
  ( my $self, my $guid, my $type ) = @_;

  # We delete the given guid and all sub-collections
  my @list = ($guid);

  my $sth = $self->dbh->prepare("SELECT * FROM Collections;");
  $sth->execute;
  my @all = ();
  while ( my $row = $sth->fetchrow_hashref() ) {
    push @all, $row;
  }
  $self->_find_subcollections( $guid, \@all, \@list );

  #  Delete all assications in Collection_Publication table
  my $delete1 = $self->dbh->prepare("DELETE FROM Collection_Publication WHERE collection_guid=?");

  #  Delete folders from Folders table
  my $delete2 = $self->dbh->prepare("DELETE FROM Collections WHERE guid=?");

  #  Update flat fields in Publication table and Fulltext table
  my $field = $type eq 'FOLDER' ? 'folders' : 'tags';
  my $update1 = $self->dbh->prepare("UPDATE Publications SET $field=? WHERE rowid=?");

  $field = $type eq 'FOLDER' ? 'folderid' : 'labelid';
  my $update2 = $self->dbh->prepare("UPDATE Fulltext SET $field=? WHERE rowid=?");

  foreach $guid (@list) {

    my ( $list, $rowid );

    $field = $type eq 'FOLDER' ? 'folders' : 'tags';

    # Get the publications that are in the given folder
    my $select = $self->dbh->prepare(
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

}


# Recursive helper function to get list of all sub-collections below
# $guid. $all is a list of all collections and $list is the final list
# with all guids of the desired sub-collections
sub _find_subcollections{

  my ($self, $guid, $all, $list) = @_;

  foreach my $collection (@$all){
    if ($collection->{parent} eq $guid){
      push @$list, $collection->{guid};
      $self->_find_subcollections($collection->{guid}, $all, $list);
    }
  }
}

sub rename_collection {
  my ( $self, $guid, $new_name ) = @_;

  my $dbh = $self->dbh;

  $new_name=$dbh->quote($new_name);

  $dbh->do("UPDATE Collections SET name=$new_name WHERE guid='$guid'");

}

sub move_collection {
  my ( $self, $target_guid, $drop_guid, $position, $type ) = @_;

  my $dbh = $self->dbh;

  $dbh->begin_work;

  # Get parent and sort_order of target
  my ( $new_parent, $sort_order ) = $dbh->selectrow_array(
    "SELECT parent, sort_order FROM Collections WHERE guid='$target_guid' AND TYPE='$type'");

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

  ( my $old_parent ) = $dbh->selectrow_array(
    "SELECT parent FROM Collections WHERE guid='$drop_guid' AND TYPE='$type'");

  $self->_normalize_sort_order( $dbh, $old_parent, $type );

  if ( $new_parent ne $old_parent ) {
    $self->_normalize_sort_order( $dbh, $new_parent, $type );
  }

  $dbh->commit;

}

sub _normalize_sort_order {
  my ( $self, $dbh, $parent, $type ) = @_;

  my $select =
    $dbh->prepare("SELECT guid FROM Collections WHERE parent='$parent' ORDER BY sort_order");

  my $update = $dbh->prepare("UPDATE Collections SET sort_order=? WHERE guid=?");

  my $guid;

  $select->bind_columns( \$guid );
  $select->execute;

  my $counter = 0;
  while ( $select->fetch ) {
    $update->execute( $counter, $guid );
    $counter++;
  }
}


sub set_collection_style {

  my ( $self, $guid, $style ) = @_;

  $self->dbh->do("UPDATE COLLECTIONS SET style='$style' WHERE guid='$guid';");

}

sub set_default_collections {

  my ($self) =@_;

  my $guid1=Data::GUID->new->as_hex;
  $guid1=~s/^0x//;

  my $guid2=Data::GUID->new->as_hex;
  $guid2=~s/^0x//;

  $self->dbh->do("INSERT INTO Collections (guid,name,type,parent,sort_order,style) VALUES ('$guid1', 'Important','LABEL','ROOT',0,'11');");
  $self->dbh->do("INSERT INTO Collections (guid,name,type,parent,sort_order,style) VALUES ('$guid2', 'Review','LABEL','ROOT',1,'22');");

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
        # the 11 columns in our fulltext table
        # text,abstract,notes,title,key,author,year,journal, keyword,folderid,labelid
        my @counts = ( 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 );

        foreach my $column ( 0 .. 10 ) {
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
        my $sum = $counts[3] + $counts[4] + $counts[5] + $counts[6] + $counts[7];

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

    $sth = $self->dbh->prepare("$select $where $rank LIMIT $limit OFFSET $offset");

  } else {
    $select .= ' FROM Publications ';
    $order =~ s/author/authors/;
    $order =~ s/notes/annote/;
    $where = "WHERE Publications.trashed=$trash";

    $sth = $self->dbh->prepare("$select $where ORDER BY $order LIMIT $limit OFFSET $offset");
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
# quotes). Also passed the database handle to avoid calling $self->dbh
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

# Attach $file to the publication $pub. If $is_pdf is set it is *the*
# PDF otherwise it is treated as attachment. If $old_guid is set the
# new file gets this guid (to avoid changing of the guid when using
# the undo function)

sub attach_file {

  my ( $self, $file, $is_pdf, $pub, $old_guid ) = @_;

  my $settings = $self->settings;
  my $dbh      = $self->dbh;
  my $source   = Paperpile::Utils->adjust_root($file);

  my $pub_guid = $pub->guid;

  my $file_guid;

  if ($old_guid){
    $file_guid = $old_guid;
  } else {
    $file_guid = Data::GUID->new->as_hex;
    $file_guid =~ s/^0x//;
  }

  my $file_size = stat($file)->size;

  my $md5 = Paperpile::Utils->calculate_md5($file);

  my $relative_dest;

  if ($is_pdf) {

    # File name relative to [paper_root] is [pdf_pattern].pdf
    $relative_dest =
      $pub->format_pattern( $settings->{pdf_pattern}, { key => $pub->citekey } ) . ".pdf";

  } else {

    my ( $volume, $dirs, $base_name ) = File::Spec->splitpath($source);

    # Path relative to [paper_root] is [attachment_pattern]/$file_name
    $relative_dest =
      $pub->format_pattern( $settings->{attachment_pattern}, { key => $pub->citekey } );
    $relative_dest = File::Spec->catfile( $relative_dest, $base_name );
  }

  my $absolute_dest = File::Spec->catfile( $settings->{paper_root}, $relative_dest );

  # Copy file, file name can be changed if it was not unique
  $absolute_dest = Paperpile::Utils->copy_file( $source, $absolute_dest );

  my ( $volume, $dirs, $base_name ) = File::Spec->splitpath($absolute_dest);

  my $name       = $dbh->quote($base_name);
  my $local_file = $dbh->quote($absolute_dest);

  $dbh->do( "INSERT INTO Attachments (guid, publication, is_pdf, name, local_file, size, md5)"
      . "                     VALUES ('$file_guid', '$pub_guid', $is_pdf, $name, $local_file, $file_size, '$md5');"
  );

  if ($is_pdf) {
    $self->index_pdf( $pub_guid, $absolute_dest );
    my $pdf_name = File::Spec->abs2rel($absolute_dest, $self->get_setting('paper_root'));
    $pub->pdf($file_guid);
    $pub->pdf_name($pdf_name);

    $pdf_name = $dbh->quote($pdf_name);

    $dbh->do(
      "UPDATE Publications SET pdf='$file_guid', pdf_name=$pdf_name, times_read=0, last_read='' WHERE guid='$pub_guid';"
    );
    return $file_guid;
  } else {

    ( my $old_attachments ) = $dbh->selectrow_array("SELECT attachments FROM Publications WHERE guid='$pub_guid' ");

    my @list = split(',',$old_attachments || '');

    push @list, $file_guid;

    my $new_attachments = join(',',@list);

    $dbh->do("UPDATE Publications SET attachments='$new_attachments' WHERE guid='$pub_guid';");

    $pub->attachments($new_attachments);
    $pub->refresh_attachments;


  }
}

# Delete PDF or other supplementary file with GUID $guid that is
# attached to $pub. If $with_undo is given the function only moves the
# file and returns the temporary path were it is stored for undo
# operations.

sub delete_attachment {

  my ( $self, $guid, $is_pdf, $pub, $with_undo ) = @_;

  my $paper_root = $self->get_setting('paper_root');

  my $dbh = $self->dbh;

  my $undo_dir = File::Spec->catfile( Paperpile::Utils->get_tmp_dir(), "trash" );
  mkpath($undo_dir);

  my $rowid= $pub->_rowid;

  (my $path ) = $self->dbh->selectrow_array("SELECT local_file FROM Attachments WHERE guid='$guid';");

  $dbh->do("DELETE FROM Attachments WHERE guid='$guid'");

  if ($is_pdf) {
    $dbh->do("UPDATE Fulltext SET text='' WHERE rowid=$rowid");
    $dbh->do("UPDATE Publications SET pdf='', pdf_name='', times_read=0, last_read='' WHERE rowid=$rowid");
    $pub->pdf('');
    $pub->pdf_name('');

  } else {

    ( my $attachments ) = $self->dbh->selectrow_array("SELECT attachments FROM Publications WHERE rowid=$rowid");

    my @old_attachments = split(/,/, $attachments ||'');

    my @new_attachments = ();

    foreach my $g (@old_attachments){
      next if ($g eq $guid);
      push @new_attachments, $g;
    }

    my $new = join(',',@new_attachments);

    $dbh->do("UPDATE Publications SET attachments='$new' WHERE rowid=$rowid");

    $pub->attachments($new);
    $pub->refresh_attachments;
  }

  move( $path, $undo_dir ) if $with_undo;
  unlink($path);

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

  my ( $self, $guid, $pdf_file ) = @_;

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

  $self->dbh->do("UPDATE Fulltext SET text=$text WHERE rowid=(SELECT rowid FROM PUBLICATIONS WHERE guid='$guid')");

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

    my ( $guid, $tag, $style );

    # Select all tags and initialize the histogram counts.
    my $sth = $self->dbh->prepare(qq^SELECT guid,name,style FROM Collections WHERE type='LABEL';^);
    $sth->bind_columns( \$guid, \$tag, \$style );
    $sth->execute;
    while ( $sth->fetch ) {
      $style = $style || 'default';
      $hist{$guid}->{count} = 0;
      $hist{$guid}->{name}  = $tag;
      $hist{$guid}->{id}    = $guid;
      $hist{$guid}->{style} = $style;
    }

    # Select tag-publication links and count them up.
    $sth = $self->dbh->prepare(
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
  my @fields = ( 'text', 'abstract', 'notes' );

  my %snippets = ( text => [], abstract => [], notes => [] );

  while ( $offsets =~ /(\d+) (\d+) (\d+) (\d+)/g ) {

    my ( $column, $term, $start, $length ) = ( $1, $2, $3, $4 );

    # We only generate snippets for text, abstract and notes
    next if ( $column > 2 );

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
          if ( $self->check_string_overlap( $s->{snippet}, $prev->{snippet} ) ) {
            $overlaps = 1;
            last;
          }
        }

        next if $overlaps;

        push @already_seen, $s;

        foreach my $term (@terms) {
          print STDERR "Subsituting $term\n";
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


sub check_string_overlap {

  my ($self, $string_a, $string_b) = @_;

  my @words_a = split(/\s+/, $string_a);
  my @words_b = split(/\s+/, $string_b);

  my %hash=();

  my $total_count=0;
  my $overlap_count=1;

  foreach my $s (@words_a){
    $hash{$s}=1;
    $total_count++;
  }

  foreach my $s (@words_b){
    $overlap_count++ if $hash{$s};
  }

  return ($overlap_count/$total_count > 0.3);
}


1;
