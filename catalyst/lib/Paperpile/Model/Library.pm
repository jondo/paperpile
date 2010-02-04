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

has 'light_objects' => (is =>'rw', isa =>'Int', default =>0);

sub build_per_context_instance {
  my ($self, $c) = @_;
  my $file=$c->session->{library_db};
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

  my $dbh=$self->dbh;

  foreach my $pub (@$pubs) {
    eval {

      # Initialize some fields

      $pub->created( timestamp gmtime ) if not $pub->created;
      $pub->times_read(0);
      $pub->last_read('');
      $pub->_imported(1);

      # Generate citation key
      my $pattern = $self->get_setting('key_pattern');

      $pattern ='[firstauthor][YYYY]';

      my $key     = $pub->format_pattern($pattern);

      # Check if key already exists

      # First we check in the database
      my $quoted = $dbh->quote("key:$key*");
      my $sth =
        $dbh->prepare(qq^SELECT key FROM fulltext_full WHERE fulltext_full MATCH $quoted^);
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
      foreach my $existing_key (@{$to_be_inserted{$key}}) {
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

      if (not $to_be_inserted{$bare_key}){
        $to_be_inserted{$bare_key} = [$key];
      } else {
        push @{$to_be_inserted{$bare_key}}, $key;
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

    next if $pub->_imported;

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

    $dbh->do("INSERT INTO fulltext_citation ($fields) VALUES ($values)");

    $fields .= ",text";
    $values .= ",''";
    $dbh->do("INSERT INTO fulltext_full ($fields) VALUES ($values)");

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
      my $attached_file = $self->attach_file( $pdf_file, 1, $pub_rowid, $pub );
      unlink($pdf_file) if -e ($cached_file);
      $pub->pdf($attached_file);
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

    my $rowid=$pub->_rowid;

    # First delete attachments from Attachments table
    my $select=$dbh->prepare("SELECT rowid FROM Attachments WHERE publication_id=$rowid;");
    my $attachment_rowid;
    $select->bind_columns( \$attachment_rowid );
    $select->execute;
    while ( $select->fetch ) {
      $self->delete_attachment($attachment_rowid,0);
    }
    # Then delete the PDF
    $self->delete_attachment($rowid,1);
  }

  # Then delete the entry in all relevant tables
  my $delete_main     = $dbh->prepare( "DELETE FROM publications WHERE rowid=?" );
  my $delete_fulltext_citation = $dbh->prepare("DELETE FROM fulltext_citation WHERE rowid=?");
  my $delete_fulltext_full = $dbh->prepare("DELETE FROM fulltext_full WHERE rowid=?");

  foreach my $pub (@$pubs) {
    my $rowid = $pub->_rowid;
    $delete_main->execute($rowid);
    $delete_fulltext_citation->execute($rowid);
    $delete_fulltext_full->execute($rowid);
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

    my $status=1;
    $status=0 if $mode eq 'RESTORE';

    $dbh->do("UPDATE Publications SET trashed=$status WHERE rowid=$rowid");

    # Created is used to store time of import as well as time of
    # deletion, so we set it everytime we trash or restore something
    my $now = $self->dbh->quote(timestamp gmtime);
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

      if ($mode eq 'TRASH'){
        $move_to = File::Spec->catfile( "Trash", $file_name );
      } else {
        $move_to=$file_name;
        $move_to=~s/Trash.//;
      }
      push @files, [ $file_name, $move_to ];
      $move_to = $dbh->quote($move_to);

      $dbh->do("UPDATE Attachments SET file_name=$move_to WHERE rowid=$attachment_rowid; ");

    }

    ( my $pdf ) = $self->dbh->selectrow_array("SELECT pdf FROM Publications WHERE rowid=$rowid ");

    if ($pdf) {
      my $move_to;

      if ($mode eq 'TRASH'){
        $move_to = File::Spec->catfile( "Trash", $pdf );
      } else {
        $move_to=$pdf;
        $move_to=~s/Trash.//;
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

    my ($volume,$dir,$file_name) = File::Spec->splitpath( $to );

    mkpath($dir);
    move($from, $to);

    ($volume,$dir,$file_name) = File::Spec->splitpath( $from );

    # Never remove the paper_root even if its empty;
    if (File::Spec->canonpath( $paper_root ) ne File::Spec->canonpath( $dir )){
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

  my ($self, $rowid) = @_;

  my $sth = $self->dbh->prepare("SELECT rowid, file_name FROM Attachments WHERE publication_id=$rowid;");
  my ( $attachment_rowid, $file_name );
  $sth->bind_columns( \$attachment_rowid, \$file_name );
  $sth->execute;
  my $paper_root=$self->get_setting('paper_root');

  my @files=();

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

  ( my $self, my $pattern) = @_;

  my $data=$self->all('created');

  my %seen=();

  $self->dbh->begin_work;

  eval {

    foreach my $pub (@$data){
      my $key = $pub->format_pattern($pattern);

      if (!exists $seen{$key}){
        $seen{$key}=1;
      } else {
        $seen{$key}++;
      }

      if ($seen{$key}>1){
        $key.=chr(ord('a')+$seen{$key}-2);
      }

      $key=$self->dbh->quote($key);

      $self->dbh->do("UPDATE Publications SET citekey=$key WHERE rowid=".$pub->_rowid);
    }

    my $_pattern=$self->dbh->quote($pattern);
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

  ( my $self, my $pub_rowid, my $tags) = @_;

  my $dbh = $self->dbh;

  my $encoded_tags= Paperpile::Utils->encode_tags($tags);

  $tags = $dbh->quote($tags);
  $encoded_tags = $dbh->quote($encoded_tags);

  $dbh->do("UPDATE Publications SET tags=$tags WHERE rowid=$pub_rowid;");
  $dbh->do("UPDATE Fulltext_full SET label=$tags WHERE rowid=$pub_rowid;");
  $dbh->do("UPDATE Fulltext_citation SET label=$tags WHERE rowid=$pub_rowid;");

  $dbh->do("UPDATE Fulltext_full SET labelid=$encoded_tags WHERE rowid=$pub_rowid;");
  $dbh->do("UPDATE Fulltext_citation SET labelid=$encoded_tags WHERE rowid=$pub_rowid;");

}

sub update_tags {
  ( my $self, my $pub_rowid, my $tags) = @_;

  my $dbh = $self->dbh;
  my @tags=split(/,/,$tags);

  $self->_update_tags($pub_rowid, $tags);

  # Remove all connections form Tag_Publication table
  my $sth=$dbh->do("DELETE FROM Tag_Publication WHERE publication_id=$pub_rowid");

  # Then insert tags into Tag table (if not already exists) and set
  # new connections in Tag_Publication table

  my $select=$dbh->prepare("SELECT rowid FROM Tags WHERE tag=?");
  my $insert=$dbh->prepare("INSERT INTO Tags (tag, style) VALUES(?,?)");
  my $connection=$dbh->prepare("INSERT INTO Tag_Publication (tag_id, publication_id) VALUES(?,?)");

  foreach my $tag (@tags){
    my $tag_rowid=undef;

    $select->bind_columns(\$tag_rowid);
    $select->execute($tag);
    $select->fetch;
    if (not defined $tag_rowid){
      $insert->execute($tag,'0');
      $tag_rowid = $self->dbh->func('last_insert_rowid');
    }

    $connection->execute($tag_rowid,$pub_rowid);
  }
}

sub new_tag {
  ( my $self, my $tag, my $style) = @_;

  $tag=$self->dbh->quote($tag);
  $style=$self->dbh->quote($style);

  $self->dbh->do("INSERT INTO Tags (tag,style) VALUES($tag, $style)");

}


sub delete_tag {
  ( my $self, my $tag) = @_;

  my $dbh = $self->dbh;

  $dbh->begin_work;

  my $_tag=$dbh->quote($tag);

  # Select all publications with this tag
  ( my $tag_id ) =
    $dbh->selectrow_array("SELECT rowid FROM Tags WHERE tag=$_tag");
  my $select=$dbh->prepare("SELECT tags, publication_id FROM Publications, Tag_Publication WHERE Publications.rowid=publication_id AND tag_id=$tag_id");

  my ($publication_id, $tags);
  $select->bind_columns(\$tags, \$publication_id);
  $select->execute;

  while ( $select->fetch ) {

    # Delete tag from flat string in Publications/Fulltext table

    my $new_tags=$tags;
    $new_tags =~s/^$tag$//;
    $new_tags =~s/^$tag,//;
    $new_tags =~s/,$tag,/,/;
    $new_tags =~s/,$tag$//;

    $self->_update_tags($publication_id, $new_tags);

  }

  # Delete tag from Tags table and link table
  $dbh->do("DELETE FROM Tags WHERE rowid=$tag_id");
  $dbh->do("DELETE FROM Tag_Publication WHERE tag_id=$tag_id");

  $dbh->commit;

}


sub rename_tag {
  my ( $self, $old_tag, $new_tag) = @_;

  my $dbh = $self->dbh;

  $dbh->begin_work;

  my $_old_tag=$dbh->quote($old_tag);

  ( my $old_tag_id ) =
    $dbh->selectrow_array("SELECT rowid FROM Tags WHERE tag=$_old_tag");
  my $select=$self->dbh->prepare("SELECT tags, publication_id FROM Publications, Tag_Publication WHERE Publications.rowid=publication_id AND tag_id=$old_tag_id");

  my ($publication_id, $old_tags);
  $select->bind_columns(\$old_tags, \$publication_id);
  $select->execute;

  while ( $select->fetch ) {

    my $new_tags=$old_tags;

    $new_tags =~s/^$old_tag$/$new_tag/;
    $new_tags =~s/^$old_tag,/$new_tag,/;
    $new_tags =~s/,$old_tag,/,$new_tag,/;
    $new_tags =~s/,$old_tag$/,$new_tag/;

    $self->_update_tags($publication_id, $new_tags);
  }

  $new_tag = $dbh->quote($new_tag);

  $dbh->do("UPDATE Tags SET tag=$new_tag WHERE rowid=$old_tag_id;");

  $dbh->commit;

}


sub insert_folder {
  ( my $self, my $folder_id) = @_;

  my $select=$self->dbh->prepare("SELECT rowid FROM Folders WHERE folder_id=?");
  my $insert=$self->dbh->prepare("INSERT INTO Folders (folder_id) VALUES(?)");

  my $folder_rowid=undef;

  $select->bind_columns(\$folder_rowid);
  $select->execute($folder_id);
  $select->fetch;
  if (not defined $folder_rowid){
    $insert->execute($folder_id);
    $folder_rowid = $self->dbh->func('last_insert_rowid');
  }

  return $folder_rowid;

}

sub update_folders {
  ( my $self, my $pub_rowid, my $folders) = @_;

  my $dbh = $self->dbh;

  my @folders=split(/,/,$folders);

  # First update flat field in Publication and Fulltext tables
  $folders = $dbh->quote($folders);

  $dbh->do("UPDATE Publications SET folders=$folders WHERE rowid=$pub_rowid;");
  $dbh->do("UPDATE Fulltext_full SET folder=$folders WHERE rowid=$pub_rowid;");
  $dbh->do("UPDATE Fulltext_citation SET folder=$folders WHERE rowid=$pub_rowid;");

  # Remove all connections from Folder_Publication table
  my $sth=$dbh->do("DELETE FROM Folder_Publication WHERE publication_id=$pub_rowid");

  # Then insert folders into Folder table (if not already exists) and set
  # new connections in Folder_Publication table

  my $select=$dbh->prepare("SELECT rowid FROM Folders WHERE folder_id=?");
  my $connection=$dbh->prepare("INSERT INTO Folder_Publication (folder_id, publication_id) VALUES(?,?)");

  foreach my $folder (@folders){
    my $folder_rowid=undef;

    $select->bind_columns(\$folder_rowid);
    $select->execute($folder);
    $select->fetch;
    if (not defined $folder_rowid){
      croak('Folder does not exists');
    }

    $connection->execute($folder_rowid,$pub_rowid);
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
  my $update2 = $self->dbh->prepare("UPDATE Fulltext_full SET folder=? WHERE rowid=?");
  my $update3 = $self->dbh->prepare("UPDATE Fulltext_citation SET folder=? WHERE rowid=?");

  foreach my $id (@$folder_ids) {

    my ( $folders, $rowid );

    # Get the publications that are in the given folder
    my $select = $self->dbh->prepare(
      "SELECT publications.rowid as rowid, publications.folders as folders FROM Publications JOIN fulltext_citation
     ON publications.rowid=fulltext_citation.rowid WHERE fulltext_citation MATCH 'folder:$id'"
    );

    $select->bind_columns( \$rowid, \$folders );
    $select->execute;
    while ( $select->fetch ) {

      my $newFolders = $self->_remove_from_flatlist($folders,$id);

      $update1->execute( $newFolders, $rowid );
      $update2->execute( $newFolders, $rowid );
      $update3->execute( $newFolders, $rowid );
    }

    $delete1->execute($id);
    $delete2->execute($id);

  }
}


sub get_tags {
  ( my $self) = @_;

  my $sth=$self->dbh->prepare("SELECT tag,style from Tags;");

  my ( $tag, $style );
  $sth->bind_columns( \$tag, \$style );

  $sth->execute;

  my @out=();

  while ( $sth->fetch ) {
    push @out, {tag => $tag, style => $style};
  }

  return [@out];

}

sub set_tag_style {

  my ($self, $tag, $style) = @_;

  $tag=$self->dbh->quote($tag);
  $style=$self->dbh->quote($style);

  $self->dbh->do("UPDATE TAGS SET style=$style WHERE tag=$tag;");

}

sub get_folders {
  ( my $self) = @_;

  my $sth=$self->dbh->prepare("SELECT folder_id from Folders;");

  $sth->execute();
  my @out=();

  foreach my $folder (@{$sth->fetchall_arrayref}){
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

sub fulltext_count {
  ( my $self, my $query, my $search_pdf, my $trash ) = @_;

  my $table='Fulltext_citation';

  if ($search_pdf){
    $table='Fulltext_Full';
  }

  if ($trash){
    $trash=1;
  } else {
    $trash=0;
  }

  my $where;
  if ($query) {
    $query = $self->dbh->quote("$query*");
    $where = "WHERE $table MATCH $query AND Publications.trashed=$trash";
  }
  else {
    $where = "WHERE Publications.trashed=$trash";    #Return everything if query empty
  }

  my $count = $self->dbh->selectrow_array(
    qq{select count(*) from Publications join $table on 
    publications.rowid=$table.rowid $where}
  );

  return $count;
}

sub fulltext_search {
  ( my $self, my $_query, my $offset, my $limit, my $order, my $search_pdf, my $trash ) = @_;

  my $table='Fulltext_citation';

  if ($search_pdf){
    $table='Fulltext_Full';
  }

  if (!$order){
    $order="created DESC";
  }

  if ($trash){
    $trash=1;
  } else {
    $trash=0;
  }

  my ($where, $query);

  if ($_query) {
    $query = $self->dbh->quote("$_query*");
    $where = "WHERE $table MATCH $query AND Publications.trashed=$trash";
  } else {
    $where = "WHERE Publications.trashed=$trash";    #Return everything if query empty
  }

  # explicitely select rowid since it is not included by '*'. Make
  # sure the selected fields are all named like the fields in the
  # Publication class
  my $sth = $self->dbh->prepare(
    "SELECT *,
     offsets($table) as offsets,
     publications.rowid as _rowid,
     publications.title as title,
     publications.abstract as abstract
     FROM Publications JOIN $table
     ON publications.rowid=$table.rowid $where ORDER BY $order LIMIT $limit OFFSET $offset"
  );

  $sth->execute;

  my @page = ();

  my @citation_hits=();
  my @fulltext_hits=();

  while ( my $row = $sth->fetchrow_hashref() ) {

    my $data={};

    foreach my $field ( keys %$row ) {

      if ( $field eq 'offsets' ) {
        my ( $snippets_text, $snippets_abstract, $snippets_notes ) =
          $self->_snippets( $row->{_rowid}, $row->{offsets}, $_query, $search_pdf );
        $data->{_snippets_text}=$snippets_text;
        $data->{_snippets_abstract}=$snippets_abstract;
        $data->{_snippets_notes}=$snippets_notes;
        next;
      }

      # fields only in fulltext, named differently or absent in
      # Publications table
      next if $field ~~ [ 'author', 'text', 'notes', 'label', 'labelid', 'folder'];
      my $value = $row->{$field};

      $field = 'citekey' if $field eq 'key';     # citekey is called 'key'
                                                 # in ft-table for
                                                 # convenience
      $field = 'keywords' if $field eq 'keyword';

      if (defined $value and $value ne '') {
        $data->{$field}=$value;
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
  ( my $self, my $query, my $offset, my $limit) = @_;

  my $sth = $self->dbh->prepare( "SELECT rowid as _rowid, * FROM Publications WHERE $query;" );

#  print STDERR "SELECT rowid as _rowid, * FROM Publications WHERE $query\n";

  $sth->execute;

  my @page = ();


  while ( my $row = $sth->fetchrow_hashref() ) {
    my $pub = Paperpile::Library::Publication->new({_light=>$self->light_objects});
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

  my ($self, $order) = @_;

  my $query="SELECT rowid as _rowid, * FROM Publications ";

  if ($order){
    $query.="ORDER BY $order";
  }

  my $sth = $self->dbh->prepare( $query );

  $sth->execute;

  my @page = ();

  while ( my $row = $sth->fetchrow_hashref() ) {
    my $pub = Paperpile::Library::Publication->new({_light=>$self->light_objects});
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

  my ($self, $order) = @_;

  my $query="SELECT rowid as _rowid, * FROM Publications ";

  if ($order){
    $query.="ORDER BY $order";
  }

  my $sth = $self->dbh->prepare( $query );

  $sth->execute;

  my @data = ();

  while ( my $row = $sth->fetchrow_hashref() ) {
    my $pub={};
    foreach my $field ( keys %$row ) {
      my $value = $row->{$field};
      if ($value) {
        $pub->{$field}=$value;
      }
    }
    $pub->{_imported}=1;
    push @data, $pub;
  }

  return [@data];

}


sub exists_pub {
  ( my $self, my $pubs ) = @_;

  my $sth = $self->dbh->prepare("SELECT rowid, * FROM publications WHERE sha1=?");

  foreach my $pub (@$pubs) {
      next unless defined ($pub);
    $sth->execute( $pub->sha1 );

    my $exists=0;

    while ( my $row = $sth->fetchrow_hashref() ) {
      $exists=1;
      foreach my $field ( keys %$row ) {
        my $value = $row->{$field};
        if ($field eq 'rowid'){
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

    if ($value eq ''){
      push @values, "''";
    } else {
      push @values, $dbh->quote( $value );
    }
  }

  my @output = ( join( ',', @fields ), join( ',', @values ) );

  return @output;
}

sub save_tree {

  ( my $self, my $tree ) = @_;

  # serialize the complete object
  my $string=freeze($tree);

  # simply save it as user setting
  $self->set_setting('_tree',$string);

}

sub restore_tree{
 ( my $self ) = @_;

 my $string=$self->get_setting('_tree');

 if (not $string){
   return undef;
 }

 (my $tree)=thaw($string);

 return $tree;

}

sub delete_from_folder {
  ( my $self, my $data,  my $folder_id ) = @_;

  my $dbh = $self->dbh;

  $dbh->begin_work;

  foreach my $pub (@$data) {

    my $row_id=$pub->_rowid;

    ( my $folders ) =
      $dbh->selectrow_array("SELECT folders FROM Publications WHERE rowid=$row_id");

    my $newFolders = $self->_remove_from_flatlist($folders, $folder_id);

    my $quotedFolders = $dbh->quote($newFolders);

    $dbh->do("UPDATE Publications SET folders=$quotedFolders WHERE rowid=$row_id");
    $dbh->do("UPDATE fulltext_full SET folder=$quotedFolders WHERE rowid=$row_id");
    $dbh->do("UPDATE fulltext_citation SET folder=$quotedFolders WHERE rowid=$row_id");
    $dbh->do("DELETE FROM Folder_Publication WHERE (folder_id IN (SELECT rowid FROM Folders WHERE folder_id=$folder_id) AND publication_id=$row_id)");

    $pub->folders($newFolders);
  }

  $dbh->commit;

}


sub attach_file {

  my ( $self, $file,  $is_pdf, $rowid, $pub) = @_;

  my $settings = $self->settings;

  my $source = Paperpile::Utils->adjust_root($file);

  if ($is_pdf){

    # File name relative to [paper_root] is [pdf_pattern].pdf
    my $relative_dest = $pub->format_pattern( $settings->{pdf_pattern}, { key => $pub->citekey } ) . ".pdf";

    # Absolute  path is [paper_root]/[pdf_pattern].pdf
    my $absolute_dest = File::Spec->catfile( $settings->{paper_root}, $relative_dest );

    # Copy file, file name can be changed if it was not unique
    $absolute_dest=Paperpile::Utils->copy_file($source, $absolute_dest);

    # Add text of PDF to fulltext table
    $self->index_pdf($rowid, $absolute_dest);

    $relative_dest = File::Spec->abs2rel( $absolute_dest, $settings->{paper_root} ) ;

    $self->update_field('Publications', $rowid, 'pdf', $relative_dest);
    $self->update_field('Publications', $rowid, 'pdf_size', stat($file)->size);
    $self->update_field('Publications', $rowid, 'times_read', 0);
    $self->update_field('Publications', $rowid, 'last_read', '');

    $pub->pdf($relative_dest);

    return $relative_dest;

  } else {

    # Get file_name without dir
    my ($volume,$dirs,$file_name) = File::Spec->splitpath( $source );

    # Path relative to [paper_root] is [attachment_pattern]/$file_name
    my $relative_dest = $pub->format_pattern( $settings->{attachment_pattern}, { key => $pub->citekey } );
    $relative_dest = File::Spec->catfile( $relative_dest, $file_name);

    # Absolute  path is [paper_root]/[attachment_pattern]/$file_name
    my $absolute_dest = File::Spec->catfile( $settings->{paper_root}, $relative_dest );

    # Copy file, file name can be changed if it was not unique
    $absolute_dest=Paperpile::Utils->copy_file($source, $absolute_dest);
    $relative_dest = File::Spec->abs2rel( $absolute_dest, $settings->{paper_root} ) ;



    $self->dbh->do("UPDATE Publications SET attachments=attachments+1 WHERE rowid=$rowid");
    my $file=$self->dbh->quote($relative_dest);
    $self->dbh->do("INSERT INTO Attachments (file_name,publication_id) VALUES ($file, $rowid)");

    return $relative_dest;

  }

}


# Delete PDF or other supplementary files that are attached to an entry
# if $is_pdf is true, the PDF file given in table 'Publications' at rowid is to be deleted
# if $is_pdf is false, the attached file in table 'Attachments' at rowid is to be deleted

sub delete_attachment{


  my ( $self, $rowid, $is_pdf, $with_undo ) = @_;

  my $paper_root = $self->get_setting('paper_root');

  my $path;

  my $undo_dir = File::Spec->catfile(Paperpile::Utils->get_tmp_dir(),"trash");
  mkpath($undo_dir);

  if ($is_pdf){
    ( my $pdf ) =
      $self->dbh->selectrow_array("SELECT pdf FROM Publications WHERE rowid=$rowid ");


    if ($pdf){
      $path = File::Spec->catfile( $paper_root, $pdf );
      $self->dbh->do("UPDATE Fulltext_full SET text='' WHERE rowid=$rowid");
      move($path, $undo_dir) if $with_undo;
      unlink($path);
    }

    $self->update_field('Publications', $rowid, 'pdf','');
    $self->update_field('Publications', $rowid, 'times_read', 0);
    $self->update_field('Publications', $rowid, 'last_read', '');

  } else {

    ( my $file, my $pub_rowid ) =
      $self->dbh->selectrow_array("SELECT file_name, publication_id FROM Attachments WHERE rowid=$rowid");

    $path = File::Spec->catfile( $paper_root, $file);

    move($path, $undo_dir) if $with_undo;
    unlink($path);

    $self->dbh->do("DELETE FROM Attachments WHERE rowid=$rowid");
    $self->dbh->do("UPDATE Publications SET attachments=attachments-1 WHERE rowid=$pub_rowid");

  }

  ## Remove directory if empty

  if ($path){
    my ($volume,$dir,$file_name) = File::Spec->splitpath( $path );
    # Never remove the paper_root even if its empty;
    if (File::Spec->canonpath( $paper_root ) ne File::Spec->canonpath( $dir )){
      # Simply remove it; will not do any harm if it is not empty; Did not
      # find an easy way to check if dir is empty, but it does not seem
      # necessary anyway
      rmdir $dir;
    }
  }

  if ($with_undo){
    my ($volume,$dir,$file_name) = File::Spec->splitpath( $path );
    return File::Spec->catfile($undo_dir,$file_name);
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

  $self->dbh->do("UPDATE Fulltext_full SET text=$text WHERE rowid=$rowid");

}

sub histogram {

  my ( $self, $field ) = @_;

  my %hist = ();

  if ( $field eq 'authors' ) {

    my $sth = $self->dbh->prepare(
      'SELECT authors from Publications WHERE trashed=0;'
    );

    my ($author_list);
    $sth->bind_columns( \$author_list );
    $sth->execute;
    while ( $sth->fetch ) {
      my @authors = split(' and ',$author_list);
      foreach my $author (@authors) {
	if ( exists $hist{$author} ) {
	  $hist{$author}->{count}++;
	} else {
	  $hist{$author}->{count} = 1;
	  # Parse out the author's name.
	  my ($surname,$initials) = split(', ',$author);
	  $hist{$author}->{name}  = $surname;
	  $hist{$author}->{id}    = $author;
	}
      }
    }
  }

  if ( $field eq 'tags' ) {

    my $sth = $self->dbh->prepare(
      qq^SELECT tag_id,tag,style FROM Tags, Tag_Publication, Publications WHERE Tag_Publication.tag_id == Tags.rowid 
          AND Publications.rowid == Tag_Publication.publication_id AND Publications.trashed==0 ^
    );
    my ( $tag_id, $tag, $style );
    $sth->bind_columns( \$tag_id, \$tag, \$style );
    $sth->execute;

    while ( $sth->fetch ) {

      my $tag_name = $tag;
      my $style = $style || 'default';

      if ( exists $hist{$tag_id} ) {
        $hist{$tag_id}->{count}++;
      } else {
        $hist{$tag_id}->{count} = 1;
        $hist{$tag_id}->{name}  = $tag_name;
        $hist{$tag_id}->{id}  = $tag_name;
        $hist{$tag_id}->{style} = $style;
      }
    }

  }

  if ( $field eq 'journals' or $field eq 'pubtype' ) {

    $field = 'journal' if ($field eq 'journals');

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

  my $self=shift;

  ( my $num_items ) =
    $self->dbh->selectrow_array("SELECT count(*) FROM Publications;");

  ( my $num_pdfs ) =
    $self->dbh->selectrow_array("SELECT count(*) FROM Publications WHERE PDF !='';");

  ( my $num_attachments ) =
    $self->dbh->selectrow_array("SELECT count(*) FROM Attachments;");

  ( my $last_imported ) =
    $self->dbh->selectrow_array("SELECT created FROM Publications ORDER BY created DESC limit 1;");

  return {num_items => $num_items,
          num_pdfs => $num_pdfs,
          num_attachments => $num_attachments,
          last_imported => $last_imported
         };


}



# Remove the item from the comma separated list

sub _remove_from_flatlist {

  my ( $self, $list, $item ) = @_;

  my @parts = split( /,/, $list );

  # Only one item 
  if (not @parts){
    $list=~s/$item//;
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

  my ( $self, $rowid, $offsets, $query, $search_pdf ) = @_;

  my $table='Fulltext_citation';

  if ($search_pdf){
    $table='Fulltext_Full';
  }

  if (not $query){
    return ('','','');
  }

  my @terms=split(/\s+/,$query);
  @terms=($query) if (not @terms);

  foreach my $field (qw/key year journal title abstract notes author label labelid keyword folder text/){
    $query=~s/$field://g;
  }

  # Offset format is 4 integers separated by blank

  # 1. The index of the column containing the match. Columns are
  #    numbered starting from 0.

  # 2. The term in the query expression which was matched. Terms are
  #    numbered starting from 0.

  # 3. The byte offset of the first character of the matching phrase,
  #    measured from the beginning of the column's text.

  # 4. Number of bytes in the match.


  # This is the order of our fields in the fulltext table
  my @fields = ('text','abstract','notes');

  # We don't have the 'text' field in the Fulltext_citation table
  if (!$search_pdf){
    @fields =('abstract', 'notes');
  }

  my %snippets = ( text => '', abstract => '', notes => '' );

  my $context=45; # Characters of context

  while ( $offsets =~ /(\d+) (\d+) (\d+) (\d+)/g ) {

    # We only generate snippets for text, abstract and notes
    # (or abstract and notes if pdfs are not searched)
    next if ( $1 > 2 and $search_pdf);
    next if ( $1 > 1 and !$search_pdf);

    my $field = $fields[$1];

    # We currently take only the first occurence
    if ( $snippets{$field} eq '' ) {
      ( my $text ) = $self->dbh->selectrow_array("SELECT $field FROM $table WHERE rowid=$rowid ");

      # Convert to bytes to get offsets exactly
      $text = encode('UTF-8', $text);

      my $from=$3-$context;
      $from=0 if $from<0;

      my $snippet = substr( $text, $from, $4+2*$context );

      # Convert back to unicode
      $snippet = decode('UTF-8', $snippet);

      # Remove word fragments at beginning and start
      $snippet=~s/\w+\b//;
      $snippet=~s/\b\w+$//;

      $snippet="\x{2026}".$snippet."\x{2026}";

      foreach my $term (@terms){
        $snippet=~s/($query)/<span class="highlight">$1<\/span>/ig;
      }

      $snippets{$field} = $snippet ;
    }
  }

  return ($snippets{text}, $snippets{abstract}, $snippets{notes});

}



1;
