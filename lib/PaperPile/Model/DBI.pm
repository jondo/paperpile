package PaperPile::Model::DBI;

use strict;
use Carp;
use base 'PaperPile::Model::DBIbase';
use Data::Dumper;
use Moose;


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
    times_read         INTEGER)"
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
    "CREATE VIRTUAL TABLE Fulltext using fts3(title,abstract,notes,names,tags,folders);");

  # Create user settings table
  $self->dbh->do('DROP TABLE IF EXISTS Settings');
  $self->dbh->do("CREATE TABLE Settings (key TEXT, value TEXT)");

  foreach my $key ( keys %$settings ) {
    my $value = $settings->{$key};
    $self->dbh->do("INSERT INTO Settings (key,value) VALUES ('$key','$value')");
  }
}

sub get_setting {

  ( my $self, my $key ) = @_;

  $key = $self->dbh->quote($key);

  ( my $value ) =
    $self->dbh->selectrow_array("SELECT value FROM Settings WHERE key=$key ");

  return $value;

}

sub create_pub {
    ( my $self, my $pub ) = @_;

    ## Insert main entry into Publications table
    ( my $fields, my $values ) = $self->_hash2sql( $pub->as_hash() );
    $self->dbh->do("INSERT INTO publications ($fields) VALUES ($values)");

    ## Insert searchable fields into fulltext table
    my $pub_rowid = $self->dbh->func('last_insert_rowid');

    ( $fields, $values ) = $self->_hash2sql( {
            rowid    => $pub_rowid,
            title    => $pub->title,
            abstract => $pub->abstract,
            notes    => $pub->notes,
            names    => $pub->_authors_nice,
            tags     => $pub->tags,
            folders  => $pub->folders,
        }
    );

    $self->dbh->do("INSERT INTO fulltext ($fields) VALUES ($values)");

    ## Insert authors

    my $insert =
      $self->dbh->prepare("INSERT INTO authors (key,first,last,von,jr) VALUES(?,?,?,?,?)");
    my $search = $self->dbh->prepare("SELECT rowid FROM authors WHERE key = ?");
    my $insert_join =
      $self->dbh->prepare("INSERT INTO author_publication (author_id,publication_id) VALUES(?,?)");

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

    $pub->_rowid($pub_rowid);

    return $pub_rowid;
}

sub delete_pubs {

    ( my $self, my $rowids ) = @_;

    my $delete_main = $self->dbh->prepare(
        "DELETE FROM publications WHERE rowid=?"
    );
    my $delete_fulltext    = $self->dbh->prepare("DELETE FROM fulltext WHERE rowid=?");
    my $delete_author_join = $self->dbh->prepare(
        "DELETE FROM author_publication WHERE publication_id=?"
    );
    my $delete_authors = $self->dbh->prepare(
        "DELETE From authors where rowid not in (SELECT author_id FROM author_publication)"
    );

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


sub insert_folder {
  ( my $self, my $folder) = @_;

  my $select=$self->dbh->prepare("SELECT rowid FROM Folders WHERE folder=?");
  my $insert=$self->dbh->prepare("INSERT INTO Folders (folder) VALUES(?)");

  my $folder_rowid=undef;

  $select->bind_columns(\$folder_rowid);
  $select->execute($folder);
  $select->fetch;
  if (not defined $folder_rowid){
    $insert->execute($folder);
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

  my $select=$self->dbh->prepare("SELECT rowid FROM Folders WHERE folder=?");
  my $insert=$self->dbh->prepare("INSERT INTO Folders (folder) VALUES(?)");
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
  ( my $self, my $folder ) = @_;

  # First delete all flat folder assignments in the Publication table
  # which are below the given folder (i.e. their path starts with the
  # folder to delete)

  my $select = $self->dbh->prepare("SELECT rowid,folders FROM Publications");
  my $update = $self->dbh->prepare("UPDATE Publications SET folders=? WHERE rowid=?");
  my ( $rowid, $curr_folders );
  $select->execute;
  $select->bind_columns( \$rowid, \$curr_folders );

  while ( $select->fetch ) {
    my @folders = split( /,/, $curr_folders );
    my @new = ();
    print STDERR "$rowid, $curr_folders";
    foreach my $f (@folders) {
      if ( not $f =~ /^$folder/ ) {
        push @new, $f;
      }
    }
    my $new = join( ',', @new );
    $update->execute( $new, $rowid );

    print STDERR "----> $curr_folders\n";

  }

  $self->dbh->do(
    "DELETE FROM Folder_Publication WHERE Folder_Publication.rowid in
    (SELECT Folder_Publication.rowid FROM Folders, Folder_Publication 
    WHERE (folder_id=Folders.rowid) and folder like '$folder%')"
  );

  $self->dbh->do( "DELETE FROM Folders WHERE folder LIKE '$folder%'" );


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

  my $sth=$self->dbh->prepare("SELECT folder from Folders;");

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
  ( my $self, my $query, my $offset, my $limit ) = @_;

  my $where;
  if ($query) {
    $query = $self->dbh->quote("$query*");
    $where = "WHERE fulltext MATCH $query";
  }
  else {
    $where = '';    #Return everything if query empty
  }

  # explicitely select rowid since it is not included by *
  my $sth = $self->dbh->prepare(
    "SELECT *,
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
    my $pub = PaperPile::Library::Publication->new();
    foreach my $field ( keys %$row ) {
      next if $field eq 'names';  # is not a standard field of Publication class
      my $value = $row->{$field};

      if ($value) {

        # Some unicode magic going one here. In principle perl uses utf-8 and
        # sqlite used utf8. However, strings returned by the DBI driver function
        # are not perl utf-8 strings. We use here utf8::decode which seems to work,
        # which does not seem that everything is right unicode-wise, so take care...
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

  my $sth = $self->dbh->prepare( "SELECT * FROM Publications WHERE $query;" );

  $sth->execute;

  my @page = ();

  while ( my $row = $sth->fetchrow_hashref() ) {
    my $pub = PaperPile::Library::Publication->new();
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

  my $sth = $self->dbh->prepare("SELECT sha1 FROM publications WHERE sha1=?");

  foreach my $pub (@$pubs) {
    $sth->execute( $pub->sha1 );

    if ( $sth->fetchrow_arrayref ) {
      $pub->_imported(1);
    }
    else {
      $pub->_imported(0);
    }
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

1;
