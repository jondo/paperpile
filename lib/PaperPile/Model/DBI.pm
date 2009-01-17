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

  my ( $self, $fields ) = @_;

  $self->dbh->do("DELETE FROM fields");

  foreach my $field ( keys %$fields ) {
    my $text = $fields->{$field};

    $self->dbh->do("INSERT INTO fields (field,text) VALUES ('$field','$text')")
      or croak("Could not insert $field into table 'fields' ($!).");

    $self->dbh->do("ALTER TABLE publications ADD COLUMN $field TEXT");

  }

  $self->dbh->do(
    "CREATE VIRTUAL TABLE fulltext using fts3(title,abstract,notes,names);");

}

sub create_pub {
  ( my $self,   my $pub )    = @_;
  ( my $fields, my $values ) = $self->_hash2sql( $pub->as_hash() );

  $self->dbh->do("INSERT INTO publications ($fields) VALUES ($values)");

  my $rowid = $self->dbh->func('last_insert_rowid');

  ( $fields, $values ) = $self->_hash2sql(
    {
      rowid    => $rowid,
      title    => $pub->title,
      abstract => $pub->abstract,
      notes    => $pub->notes,
      names  => $pub->_authors_nice,
    }
  );
  $self->dbh->do("INSERT INTO fulltext ($fields) VALUES ($values)");

}

sub reset_db {

  ( my $self ) = @_;

  for my $table (
    qw/publications authors author_publication fields journals fulltext/)
  {
    $self->dbh->do("DELETE FROM $table");
  }
}

# sub fulltext_search {

#   ( my $self, my $query ) = @_;

#   my @output = ();

#   foreach my $row ( $rs->page($page)->all ) {

#     my $data = {};
#     foreach
#       my $column ( $self->resultset('Publication')->result_source->columns )
#     {
#       if ( $row->get_column($column) ) {
#         my $x = $row->get_column($column);

#     # Some unicode magic going one here. In principle perl uses utf-8 and
#     # sqlite used utf8. Howver, strings returned by this DBIx::Class function
#     # are not perl utf-8 strings. We use here utf8::decode which seems to work,
#     # which does not seem that everything is right unicode-wise, so take care...
#         utf8::decode($x);
#         $data->{$column} = $x;
#       }
#     }
#     push @output, PaperPile::Library::Publication->new($data);
#   }

#   print STDERR Dumper(@output);

#   return [@output];
# }

sub fulltext_count {
  ( my $self, my $query ) = @_;

  my $where;
  if ($query){
    $query=$self->dbh->quote($query);
    $where="WHERE fulltext MATCH $query";
  } else {
    $where=''; #Return everything if query empty
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
  if ($query){
    $query=$self->dbh->quote($query);
    $where="WHERE fulltext MATCH $query";
  } else {
    $where=''; #Return everything if query empty
  }

  my $sth = $self->dbh->prepare(qq{SELECT * FROM Publications JOIN fulltext 
ON publications.rowid=fulltext.rowid $where LIMIT $limit OFFSET $offset});

  $sth->execute;

  my @page=();

  while (my $row =$sth->fetchrow_hashref()){
     my $pub=PaperPile::Library::Publication->new();
     foreach my $field (keys %$row){
       next if $field eq 'names'; # is not a standard field of Publication class
       my $value=$row->{$field};
       if ($value){

         # Some unicode magic going one here. In principle perl uses utf-8 and
         # sqlite used utf8. Howver, strings returned by this DBIx::Class function
         # are not perl utf-8 strings. We use here utf8::decode which seems to work,
         # which does not seem that everything is right unicode-wise, so take care...
         utf8::decode($value);

         $pub->$field($value);
       }
     }
     push @page, $pub;
   }

  return [@page];

}



#sub get_by_sha1 {
#  ( my $self, my $sha1 ) = @_;
#  my $data=$self->dbh->selectrow_hashref(qq{SELECT * FROM publications WHERE sha1="
#$sha1 "});
#  return $data;
#}

sub exists_pub {
  ( my $self, my $sha1 ) = @_;

  my $count=$self->dbh->selectrow_array(qq{SELECT count(*) FROM publications WHERE sha1="
  $sha1 "});

  $count=1  if $count>0 ;
  return $count;
}


sub _hash2sql {

  ( my $self, my $hash ) = @_;

  my @fields=();
  my @values=();

  foreach my $key (keys %{$hash}){

    # ignore fields starting with underscore
    # They are not stored to the database by convention
    next if $key=~/^_/;

    if ($hash->{$key}){
      push @fields, $key;
      push @values, $self->dbh->quote($hash->{$key});
    }
  }
  my @output=(join(',',@fields), join(',',@values));

  return @output;
}


1;
