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

=pod
=head1 init_db(fields: HashRef)

Initializes database. Gets list with fields and adds these
to table 'fields' and adds the columns to 'publications'.
Creates fulltext table.

=cut

sub init_db{

  my ($self, $fields)=@_;

  $self->dbh->do("DELETE FROM fields");

  foreach my $field (keys %$fields){
    my $text=$fields->{$field};

    $self->dbh->do("INSERT INTO fields (field,text) VALUES ('$field','$text')")
      or croak("Could not insert $field into table 'fields' ($!).");

    $self->dbh->do("ALTER TABLE publications ADD COLUMN $field TEXT");

  }

  $self->dbh->do("CREATE VIRTUAL TABLE fulltext using fts3(title,abstract,notes,authors);");

}


1;
