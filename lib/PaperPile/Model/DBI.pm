package PaperPile::Model::DBI;

use strict;
use Carp;
use base 'Catalyst::Model::DBI';
use Data::Dumper;

__PACKAGE__->config(
  dsn      => 'dbi:SQLite:/home/wash/play/PaperPile/db/default.db',
  user     => '',
  password => '',
  options  => {},
);

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
    "CREATE VIRTUAL TABLE fulltext using fts3(title,abstract,notes,names);");

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

  ( $fields, $values ) = $self->_hash2sql(
    {
      rowid    => $pub_rowid,
      title    => $pub->title,
      abstract => $pub->abstract,
      notes    => $pub->notes,
      names    => $pub->_authors_nice,
    }
  );

  $self->dbh->do("INSERT INTO fulltext ($fields) VALUES ($values)");

  ## Insert authors

  my $insert = $self->dbh->prepare(
    "INSERT INTO authors (key,first,last,von,jr) VALUES(?,?,?,?,?)");
  my $search = $self->dbh->prepare("SELECT rowid FROM authors WHERE key = ?");
  my $insert_join = $self->dbh->prepare(
    "INSERT INTO author_publication (author_id,publication_id) VALUES(?,?)");

  foreach my $author ( @{ $pub->get_authors } ) {
    my $author_rowid;
    $search->execute( $author->key );
    $author_rowid = $search->fetchrow_array;
    if ( not $author_rowid ) {
      my @values = (
        $author->key, $author->first, $author->last,
        $author->von, $author->jr
      );
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

  my $delete_main =
    $self->dbh->prepare("DELETE FROM publications WHERE rowid=?");
  my $delete_fulltext =
    $self->dbh->prepare("DELETE FROM fulltext WHERE rowid=?");
  my $delete_author_join = $self->dbh->prepare(
    "DELETE FROM author_publication WHERE publication_id=?");
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
  ( my $self, my $rowid, my $field, my $value ) = @_;

  $value = $self->dbh->quote($value);

  $self->dbh->do("UPDATE Publications SET $field=$value WHERE rowid=$rowid");

}

sub reset_db {

  ( my $self ) = @_;

  for my $table (
    qw/publications authors author_publication fields journals fulltext/)
  {
    $self->dbh->do("DELETE FROM $table");
  }

  return 1;
}

sub fulltext_count {
  ( my $self, my $query ) = @_;

  my $where;
  if ($query) {
    $query = $self->dbh->quote($query);
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
    $query = $self->dbh->quote($query);
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
