package Paperpile::Model::User;

use strict;
use Carp;
use base 'Paperpile::Model::DBIbase';
use Data::Dumper;
use Tree::Simple;
use XML::Simple;
use FreezeThaw qw/freeze thaw/;
use Moose;
use Paperpile::Model::App;

with 'Catalyst::Component::InstancePerContext';

sub build_per_context_instance {
  my ($self, $c) = @_;
  my $file=$c->session->{user_db};
  my $model = Paperpile::Model::User->new();
  $model->set_dsn("dbi:SQLite:$file");
  return $model;
}

# Function: init_db(fields: HashRef)

# Initializes database. Gets list with fields and adds these
# to table 'fields' and adds the columns to 'publications'.
# Creates fulltext table.

sub init_db {

  my ( $self, $fields, $settings ) = @_;

  # Publication and Fields tables

  $self->dbh->do('DROP TABLE IF EXISTS Publications');

  # Insert built in fields
  $self->dbh->do(
    "CREATE TABLE publications(
    sha1               TEXT UNIQUE,
    pdf                TEXT,
    pdftext            TEXT,
    created            TIMESTAMP,
    last_read          TIMESTAMP,
    times_read         INTEGER,
    attachments        INTEGER)"
  );

  # Read other fields from config file, write it to the Fields table and
  # add it to the Publications table
  $self->dbh->do("DELETE FROM fields");
  foreach my $field ( keys %$fields ) {
    my $text = $fields->{$field};
    $self->dbh->do("INSERT INTO fields (field,text) VALUES ('$field','$text')")
      or croak("Could not insert $field into table 'fields' ($!).");
    eval {
      no warnings 'all';
      $self->dbh->do("ALTER TABLE Publications ADD COLUMN $field TEXT");
    };
  }

  # Full text search table
  $self->dbh->do('DROP TABLE IF EXISTS Fulltext');
  $self->dbh->do(
    "CREATE VIRTUAL TABLE Fulltext using fts3(text,abstract,notes,title,key,author,tags,folders,year,journal);");

  if (defined $settings){
    # Create user settings table
    $self->dbh->do('DROP TABLE IF EXISTS Settings');
    $self->dbh->do("CREATE TABLE Settings (key TEXT, value TEXT)");

    foreach my $key ( keys %$settings ) {
      my $value = $settings->{$key};
      $self->dbh->do("INSERT INTO Settings (key,value) VALUES ('$key','$value')");
    }
  }
}

sub get_setting {

  ( my $self, my $key ) = @_;

  $key = $self->dbh->quote($key);

  ( my $value ) =
    $self->dbh->selectrow_array("SELECT value FROM Settings WHERE key=$key ");

  return $value;

}

sub set_setting {

  ( my $self, my $key, my $value ) = @_;
  $value = $self->dbh->quote($value);
  $key = $self->dbh->quote($key);
  $self->dbh->do("UPDATE Settings SET value=$value WHERE key=$key ");

  return $value;
}


sub settings {

  ( my $self ) = @_;

  my $sth = $self->dbh->prepare("SELECT key,value FROM Settings;");
  my ( $key, $value );
  $sth->bind_columns( \$key, \$value );

  $sth->execute;

  my %output;

  while ( $sth->fetch ) {
    $output{$key} = $value;
  }

  return {%output};

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

  foreach my $pub (@$pubs) {

    # First generate citation key
    my $pattern = $self->get_setting('key_pattern');
    my $key     = $pub->format_pattern($pattern);

    # Check if key already exists
    my $sth = $self->dbh->prepare("SELECT key FROM fulltext WHERE fulltext MATCH 'key:$key*'");
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

    if ( not $unique ) {
      my $new_suffix = 'a';
      if (@suffix) {

        # we sort them to make sure to get the 'highest' suffix and count one up
        @suffix = sort { $a <=> $b } @suffix;
        $new_suffix = chr( ord( pop(@suffix) ) + 1 );
      }
      $key .= $new_suffix;
    }

    $pub->citekey($key);

  }

  $self->insert_pubs($pubs);

}

# Function: insert_pubs
#
# Inserts a list of publications into the database

sub insert_pubs {

  ( my $self, my $pubs ) = @_;

  $self->dbh->begin_work;

  foreach my $pub (@$pubs) {

    ## Insert main entry into Publications table
    ( my $fields, my $values ) = $self->_hash2sql( $pub->as_hash() );
    $self->dbh->do("INSERT INTO publications ($fields) VALUES ($values)");

    ## Insert searchable fields into fulltext table
    my $pub_rowid = $self->dbh->func('last_insert_rowid');

    $pub->_rowid($pub_rowid);

    ( $fields, $values ) = $self->_hash2sql( {
        rowid    => $pub_rowid,
        key      => $pub->citekey,
        year     => $pub->year,
        journal  => $pub->journal,
        title    => $pub->title,
        abstract => $pub->abstract,
        notes    => $pub->notes,
        author   => $pub->_authors_display,
        tags     => $pub->tags,
        folders  => $pub->folders,
        text     => '',
      }
    );

    $self->dbh->do("INSERT INTO fulltext ($fields) VALUES ($values)");

    ## Insert authors

    my $insert =
      $self->dbh->prepare("INSERT INTO authors (key,first,last,von,jr) VALUES(?,?,?,?,?)");
    my $search = $self->dbh->prepare("SELECT rowid FROM authors WHERE key = ?");

    # 'OR IGNORE' for rare cases where one paper has two or more
    # authors that are not distinguished by their id (e.g. ENCODE paper with 316 authors)
    my $insert_join =
      $self->dbh->prepare("INSERT OR IGNORE INTO author_publication (author_id,publication_id) VALUES(?,?)");

    foreach my $author ( @{ $pub->get_authors } ) {
      my $author_rowid;
      $search->execute( $author->key );
      $author_rowid = $search->fetchrow_array;

      if ( not $author_rowid ) {
        my @values = ( $author->key, $author->first, $author->last, $author->von, $author->jr );
        $insert->execute(@values);
        $author_rowid = $self->dbh->func('last_insert_rowid');
      }

      $insert_join->execute( $author_rowid, $pub_rowid );
    }
  }

  eval {
    $self->dbh->commit;
  };

  if ($@) {

    die("Could not insert data into database $@");

    # TODO: best practise is to eval rollback as well...
    $self->dbh->rollback;

  }

}


sub delete_pubs {

  ( my $self, my $rowids ) = @_;

  # check if entry has any attachments an delete those
  foreach my $rowid (@$rowids) {

    # First delete attachments from Attachments table
    my $select=$self->dbh->prepare("SELECT rowid FROM Attachments WHERE publication_id=$rowid;");
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
  my $delete_main     = $self->dbh->prepare( "DELETE FROM publications WHERE rowid=?" );
  my $delete_fulltext = $self->dbh->prepare("DELETE FROM fulltext WHERE rowid=?");
  my $delete_author_join =
    $self->dbh->prepare( "DELETE FROM author_publication WHERE publication_id=?" );
  my $delete_authors = $self->dbh->prepare(
    "DELETE From authors where rowid not in (SELECT author_id FROM author_publication)" );

  foreach my $rowid (@$rowids) {
    $delete_main->execute($rowid);
    $delete_fulltext->execute($rowid);
    $delete_author_join->execute($rowid);
    $delete_authors->execute;
  }

  return 1;

}

sub update_pub {

  ( my $self, my $pub ) = @_;
  $self->delete_pubs( [ $pub->_rowid ] );
  my $rowid = $self->create_pub($pub);
  return $rowid;
}

sub update_field {
  ( my $self, my $table, my $rowid, my $field, my $value ) = @_;

  $value = $self->dbh->quote($value);
  $self->dbh->do("UPDATE $table SET $field=$value WHERE rowid=$rowid");

}

sub update_tags {
  ( my $self, my $pub_rowid, my $tags) = @_;

  $DB::single=1;

  my @tags=split(/,/,$tags);

  # First update flat field in Publication and Fulltext tables
  $self->update_field('Publications',$pub_rowid,'tags',$tags);
  $self->update_field('Fulltext',$pub_rowid,'tags',$tags);

  # Remove all connections form Tag_Publication table
  my $sth=$self->dbh->do("DELETE FROM Tag_Publication WHERE publication_id=$pub_rowid");

  # Then insert tags into Tag table (if not already exists) and set
  # new connections in Tag_Publication table

  my $select=$self->dbh->prepare("SELECT rowid FROM Tags WHERE tag=?");
  my $insert=$self->dbh->prepare("INSERT INTO Tags (tag) VALUES(?)");
  my $connection=$self->dbh->prepare("INSERT INTO Tag_Publication (tag_id, publication_id) VALUES(?,?)");

  foreach my $tag (@tags){
    my $tag_rowid=undef;

    $select->bind_columns(\$tag_rowid);
    $select->execute($tag);
    $select->fetch;
    if (not defined $tag_rowid){
      $insert->execute($tag);
      $tag_rowid = $self->dbh->func('last_insert_rowid');
    }

    $connection->execute($tag_rowid,$pub_rowid);
  }

  # Delete tags that have no connectin any longer
  $self->dbh->do("DELETE From Tags where rowid not in (SELECT tag_id FROM Tag_Publication)");
}


sub delete_tag {
  ( my $self, my $tag) = @_;

  my $_tag=$self->dbh->quote($tag);

  # Select all publications with this tag
  ( my $tag_id ) =
    $self->dbh->selectrow_array("SELECT rowid FROM Tags WHERE tag=$_tag");
  my $select=$self->dbh->prepare("SELECT tags, publication_id FROM Publications, Tag_Publication WHERE Publications.rowid=publication_id AND tag_id=$tag_id");

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

    $self->update_field('Publications',$publication_id,'tags',$new_tags);
    $self->update_field('Fulltext',$publication_id,'tags',$new_tags);

  }

  # Delete tag from Tags table and link table
  $self->dbh->do("DELETE FROM Tags WHERE rowid=$tag_id");
  $self->dbh->do("DELETE FROM Tag_Publication WHERE tag_id=$tag_id");

}


sub rename_tag {
  my ( $self, $old_tag, $new_tag) = @_;

  my $_old_tag=$self->dbh->quote($old_tag);

  ( my $old_tag_id ) =
    $self->dbh->selectrow_array("SELECT rowid FROM Tags WHERE tag=$_old_tag");
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

    print STDERR "$old_tags, $new_tags\n";

    $self->update_field('Publications',$publication_id,'tags',$new_tags);
    $self->update_field('Fulltext',$publication_id,'tags',$new_tags);

  }

  $self->update_field('Tags',$old_tag_id,'tag', $new_tag);

  #$self->dbh->do("DELETE FROM Tags WHERE rowid=$tag_id");

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

  $DB::single=1;

  my @folders=split(/,/,$folders);

  # First update flat field in Publication and Fulltext tables
  $self->update_field('Publications',$pub_rowid,'folders',$folders);
  $self->update_field('Fulltext',$pub_rowid,'folders',$folders);

  # Remove all connections from Folder_Publication table
  my $sth=$self->dbh->do("DELETE FROM Folder_Publication WHERE publication_id=$pub_rowid");

  # Then insert folders into Folder table (if not already exists) and set
  # new connections in Folder_Publication table

  my $select=$self->dbh->prepare("SELECT rowid FROM Folders WHERE folder_id=?");
  #my $insert=$self->dbh->prepare("INSERT INTO Folders (folder) VALUES(?)");
  my $connection=$self->dbh->prepare("INSERT INTO Folder_Publication (folder_id, publication_id) VALUES(?,?)");

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

  # Delete folders that have no connection any longer
  #$self->dbh->do("DELETE From Folders where rowid not in (SELECT folder_id FROM Folder_Publication)");

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
  my $update2 = $self->dbh->prepare("UPDATE Fulltext SET folders=? WHERE rowid=?");

  foreach my $id (@$folder_ids) {

    my ( $folders, $rowid );

    # Get the publications that are in the given folder
    my $select = $self->dbh->prepare(
      "SELECT publications.rowid as rowid, publications.folders as folders FROM Publications JOIN fulltext
     ON publications.rowid=fulltext.rowid WHERE fulltext MATCH 'folders:$id'"
    );

    $select->bind_columns( \$rowid, \$folders );
    $select->execute;
    while ( $select->fetch ) {

      # Remove the entry from the comma separated list
      #my @parts = split( /,/, $folders );
      #my @newParts = ();
      #foreach my $part (@parts) {
      #  next if $part eq $id;
      #  push @newParts, $part;
      #}
      #my $newFolders = join( ',', @newParts );

      my $newFolders = $self->_remove_from_flatlist($folders,$id);

      $update1->execute( $newFolders, $rowid );
      $update2->execute( $newFolders, $rowid );
    }

    $delete1->execute($id);
    $delete2->execute($id);

  }
}


sub get_tags {
  ( my $self) = @_;

  my $sth=$self->dbh->prepare("SELECT tag from Tags;");

  $sth->execute();


  my @out=();

  foreach my $tag (@{$sth->fetchall_arrayref}){
    push @out, $tag->[0];
  }

  return [@out];

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
  ( my $self, my $query ) = @_;

  my $where;
  if ($query) {
    $query = $self->dbh->quote("$query*");
    $where = "WHERE fulltext MATCH $query";
  }
  else {
    $where = '';    #Return everything if query empty
  }

  my $count = $self->dbh->selectrow_array(
    qq{select count(*) from Publications join fulltext on 
    publications.rowid=fulltext.rowid $where}
  );

  return $count;
}

sub fulltext_search {
  ( my $self, my $_query, my $offset, my $limit ) = @_;

  my ($where, $query);

  if ($_query) {
    $query = $self->dbh->quote("$_query*");
    $where = "WHERE fulltext MATCH $query";
  } else {
    $where = '';    #Return everything if query empty
  }

  # explicitely select rowid since it is not included by '*'. Make
  # sure the selected fields are all named like the fields in the
  # Publication class
  my $sth = $self->dbh->prepare(
    "SELECT *,
     offsets(fulltext) as offsets,
     publications.rowid as _rowid,
     publications.title as title,
     publications.abstract as abstract,
     publications.notes as notes
     FROM Publications JOIN fulltext
     ON publications.rowid=fulltext.rowid $where LIMIT $limit OFFSET $offset"
  );

  $sth->execute;

  my @page = ();

  while ( my $row = $sth->fetchrow_hashref() ) {
    my $pub = Paperpile::Library::Publication->new();
    foreach my $field ( keys %$row ) {

      if ( $field eq 'offsets' ) {
        my ( $snippets_text, $snippets_abstract, $snippets_notes ) =
          $self->_snippets( $row->{_rowid}, $row->{offsets}, $_query );

        $pub->_snippets_text($snippets_text);
        $pub->_snippets_abstract($snippets_abstract);
        $pub->_snippets_notes($snippets_notes);

        next;
      }

      next if $field ~~ [ 'author', 'text' ];    # fields only in
                                                 # fulltext, named
                                                 # differently or absent
                                                 # in Publications table
      my $value = $row->{$field};

      $field = 'citekey' if $field eq 'key';     # citekey is called 'key'
                                                 # in ft-table for
                                                 # convenience

      if ($value) {

        # Some unicode magic going one here. In principle perl uses utf-8 and
        # sqlite used utf8. However, strings returned by the DBI driver function
        # are not perl utf-8 strings. We use here utf8::decode which seems to work
        utf8::decode($value);

        $pub->$field($value);
      }
    }
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

  $sth->execute;

  my @page = ();

  while ( my $row = $sth->fetchrow_hashref() ) {
    my $pub = Paperpile::Library::Publication->new();
    foreach my $field ( keys %$row ) {
      my $value = $row->{$field};
      if ($value) {
        utf8::decode($value);
        $pub->$field($value);
      }
    }
    $pub->_imported(1);
    push @page, $pub;
  }

  return [@page];

}

sub exists_pub {
  ( my $self, my $pubs ) = @_;

  my $sth = $self->dbh->prepare("SELECT rowid, * FROM publications WHERE sha1=?");

  foreach my $pub (@$pubs) {
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
            utf8::decode($value);
            $pub->$field($value);
          }
        }
      }
    }

    $pub->_imported($exists);

  }
}

sub _hash2sql {

  ( my $self, my $hash ) = @_;

  my @fields = ();
  my @values = ();

  foreach my $key ( keys %{$hash} ) {

    # ignore fields starting with underscore
    # They are not stored to the database by convention
    next if $key =~ /^_/;

    if ( defined $hash->{$key} ) {
      push @fields, $key;
      push @values, $self->dbh->quote( $hash->{$key} );
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
  ( my $self, my $row_id,  my $folder_id ) = @_;

  ( my $folders ) =
    $self->dbh->selectrow_array("SELECT folders FROM Publications WHERE rowid=$row_id");

  my $newFolders=$self->_remove_from_flatlist($folders, $folder_id);

  $newFolders=$self->dbh->quote($newFolders);

  $self->dbh->do("UPDATE Publications SET folders=$newFolders WHERE rowid=$row_id");
  $self->dbh->do("UPDATE fulltext SET folders=$newFolders WHERE rowid=$row_id");
  $self->dbh->do("DELETE FROM Folder_Publication WHERE (folder_id IN (SELECT rowid FROM Folders WHERE folder_id=$folder_id) AND publication_id=$row_id)");

}


sub add_attachment {

  my ( $self, $file, $rowid ) = @_;

  $self->dbh->do("UPDATE Publications SET attachments=attachments+1 WHERE rowid=$rowid");

  $file=$self->dbh->quote($file);

  $self->dbh->do("INSERT INTO Attachments (file_name,publication_id) VALUES ($file, $rowid)");

}


# Delete PDF or other supplementary files that are attached to an entry
# if $is_pdf is true, the PDF file given in table 'Publications' at rowid is to be deleted
# if $is_pdf is false, the attached file in table 'Attachments' at rowid is to be deleted

sub delete_attachment{

  my ( $self, $rowid, $is_pdf ) = @_;

  my $path;

  my $paper_root=$self->get_setting('paper_root');

  if ($is_pdf){
    ( my $pdf ) =
      $self->dbh->selectrow_array("SELECT pdf FROM Publications WHERE rowid=$rowid ");


    if ($pdf){
      $path = File::Spec->catfile( $paper_root, $pdf );
      $self->dbh->do("UPDATE Fulltext SET text='' WHERE rowid=$rowid");
      unlink($path);
    }

    $self->update_field('Publications', $rowid, 'pdf','');


  } else {

    ( my $file, my $pub_rowid ) =
      $self->dbh->selectrow_array("SELECT file_name, publication_id FROM Attachments WHERE rowid=$rowid");

    $path = File::Spec->catfile( $paper_root, $file);

    unlink($path);
    $self->dbh->do("DELETE FROM Attachments WHERE rowid=$rowid");
    $self->dbh->do("UPDATE Publications SET attachments=attachments-1 WHERE rowid=$pub_rowid");

  }

  ## Remove directory if empty

  if ($path){
    my ($volume,$dir,$file_name) = File::Spec->splitpath( $path );
    # Never remove the paper_root even if its empty;
    return if (File::Spec->canonpath( $paper_root ) eq File::Spec->canonpath( $dir ));
    # Simply remove it; will not do any harm if it is not empty; Did not
    # find an easy way to check if dir is empty, but it does not seem
    # necessary anyway
    rmdir $dir;
  }

}


sub index_pdf {

  my ( $self, $rowid, $pdf_file) = @_;

  my $app_model = Paperpile::Model::App->new();
  my $app_db = Paperpile::Utils->path_to('db/app.db');
  $app_model->set_dsn("dbi:SQLite:$app_db");

  my $bin = Paperpile::Utils->get_binary('extpdf',$app_model->get_setting('platform'));

  my %extpdf;

  $extpdf{command} = 'TEXT';
  $extpdf{inFile} =  $pdf_file ;

  my $xml = XMLout( \%extpdf, RootName => 'extpdf', XMLDecl => 1, NoAttr => 1 );

  my ( $fh, $filename ) = File::Temp::tempfile();
  print $fh $xml;
  close($fh);

  my @text=`$bin $filename`;

  my $text='';

  $text.=$_ foreach (@text);

  $text=$self->dbh->quote($text);

  $self->dbh->do("UPDATE Fulltext SET text=$text WHERE rowid=$rowid");

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

  my ( $self, $rowid, $offsets, $query ) = @_;

  if (not $query){
    return ('','','');
  }

  my @terms=split(/\s+/,$query);

  @terms=($query) if (not @terms);

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

  my %snippets = ( text => '', abstract => '', notes => '' );

  my $context=30; # Characters of context

  while ( $offsets =~ /(\d+) (\d+) (\d+) (\d+)/g ) {

    # We only generate snippets for text, abstract and notes
    next if ( $1 > 2 );

    my $field = $fields[$1];

    # We currently take only the first occurence
    if ( $snippets{$field} eq '' ) {
      ( my $text ) = $self->dbh->selectrow_array("SELECT $field FROM Fulltext WHERE rowid=$rowid ");

      # TODO: more sophisticated way of generating ends, etc.

      my $from=$3-$context;
      $from=0 if $from<0;

      my $snippet = substr( $text, $from, $4+2*$context );

      utf8::decode($snippet);
      $snippet="...".$snippet."...";

      foreach my $term (@terms){
        print STDERR "===============> $term\n";
        print STDERR "--------> $snippet\n";
        $snippet=~s/($query)/<span class="highlight">$1<\/span>/ig;
      }

      $snippets{$field} = $snippet ;
    }
  }

  return ($snippets{text}, $snippets{abstract}, $snippets{notes});

}



1;
