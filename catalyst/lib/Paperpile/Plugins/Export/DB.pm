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

  my $dbfile = $self->settings->{out_file};

  # First initialize with empty database file
  my $empty_db = Paperpile::Utils->path_to('db/library.db')->stringify;

  copy( $empty_db, $dbfile ) or FileWriteError->throw( error => "Could not write $dbfile." );

  my $model = Paperpile::Model::Library->new();
  $model->set_dsn( "dbi:SQLite:" . $dbfile );

  foreach my $pub (@{$self->data}){
    $pub->pdf(undef);
  }

  $model->insert_pubs( $self->data );

}

1;
