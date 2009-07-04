package Paperpile::Controller::Ajax::App;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Paperpile::Utils;
use Data::Dumper;
use File::Spec;
use File::Path;
use File::Copy;
use Paperpile::Exceptions;
use 5.010;
use POSIX;

sub kill_server : Local {
  exit(0);
}

sub heartbeat : Local {

  my ( $self, $c ) = @_;

  $c->stash->{version} = $c->config->{app_settings}->{version};
  $c->stash->{status} = 'RUNNING';

}


sub init_session : Local {

  my ( $self, $c ) = @_;

  # Clear session variables
  foreach my $key ( keys %{ $c->session } ) {
    delete( $c->session->{$key} ) if $key =~ /^(grid|viewer|tree|library_db|pdfextract)/;
  }

  my $user_dir = $c->config->{'paperpile_user_dir'};

  # No settings file exists in .paperpile in user's home directory
  if ( !-e $c->config->{'user_settings_db'} ) {

    # create .paperpile if not exists
    if ( !-e $user_dir ) {
      mkpath( $c->config->{'paperpile_user_dir'} )
        or FileWriteError->throw(
        "Could not start application. Error initializing Paperpile directory.");
    }

    # initialize databases
    copy( $c->path_to('db/user.db')->stringify, $c->config->{'user_settings_db'} )
      or FileWriteError->throw("Could not start application. Error initializing database.");

    # Don't overwrite an existing library database in the case the
    # user has just deleted the user settings database
    if ( !-e $c->config->{'user_settings'}->{library_db} ) {
      copy( $c->path_to('db/library.db')->stringify, $c->config->{'user_settings'}->{library_db} )
        or FileWriteError->throw("Could not start application. Error initializing database.");
    }

    $c->model('User')->set_settings( $c->config->{'user_settings'} );
    $c->session->{library_db} = $c->config->{'user_settings'}->{library_db};
    $c->model('Library')->set_settings( $c->config->{'library_settings'} );

  } else {

    my $library_db = $c->model('User')->get_setting('library_db');

    # User might have deleted or moved her library. In that case we initialize an empty one and
    # warn the user
    if ( !-e $library_db ) {

      $c->session->{library_db} = $c->config->{'user_settings'}->{library_db};

      copy( $c->path_to('db/library.db')->stringify, $c->config->{'user_settings'}->{library_db} )
        or FileWriteError->throw(
        "Could not start application. Error initializing Paperpile database.");

      LibraryMissingError->throw(
        "Could not find your Paperpile library file $library_db. Start with an empty one.");
    }

    $c->session->{library_db} = $library_db;

  }

  mkpath($c->model('User')->get_setting('tmp_dir'));

}






1;
