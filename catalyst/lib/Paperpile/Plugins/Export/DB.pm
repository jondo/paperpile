package Paperpile::Plugins::Export::DB;

use Moose;
use Moose::Util::TypeConstraints;
use Data::Dumper;
use 5.010;

use File::Copy;
use Paperpile::Utils;
use Paperpile::Model::User;
use Paperpile::Plugins::Import::DB;


extends 'Paperpile::Plugins::Export';

# Supported settings:

# export_file
# export_include_pdfs
# export_include_attachments

sub write {

  my ($self) = @_;

  my $dbfile=$self->settings->{export_file};

  # First initialize with empty database file
  my $empty_db=Paperpile::Utils->path_to('db/local-user.db')->stringify;
  copy( $empty_db, $dbfile ) or die "Could not initialize empty db: $!";

  my $model=Paperpile::Model::User->new();
  $model->set_dsn("dbi:SQLite:".$dbfile);
  $model->insert_pubs($self->data);

}

1;
