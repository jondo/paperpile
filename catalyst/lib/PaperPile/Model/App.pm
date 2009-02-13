package PaperPile::Model::App;

use strict;
use Carp;
use base 'PaperPile::Model::DBIbase';
use Data::Dumper;
use Moose;


# Function: init_db(fields: HashRef)

# Initializes database.

sub init_db {

  my ( $self, $settings ) = @_;

  # Create application settings table
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


1;
