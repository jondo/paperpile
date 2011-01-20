# Copyright 2009, 2010 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public License for more details.  You should have
# received a copy of the GNU Affero General Public License along with
# Paperpile.  If not, see http://www.gnu.org/licenses.


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
use Paperpile::Queue;
use Paperpile::Migrate;
use 5.010;
use POSIX;

sub heartbeat : Local {

  my ( $self, $c ) = @_;

  $c->stash->{version} = $c->config->{app_settings}->{version};
  $c->stash->{status}  = 'RUNNING';

}

sub init_session : Local {

  my ( $self, $c ) = @_;

  # Create temporary directory if not already exists

  my $tmp_dir = Paperpile::Utils->get_tmp_dir;

  mkpath( $tmp_dir );

  if ( !( -w $tmp_dir ) ) {
    FileWriteError->throw("Could not start application. Temporary file $tmp_dir not writable.");
  }

  foreach my $subdir ('rss','import','download','queue','filesync'){
    mkpath( File::Spec->catfile( $tmp_dir, $subdir ) );
  }

  # Clear temporary PDF downloads and file imports
  unlink( glob( File::Spec->catfile( $tmp_dir, 'download', '*pdf' ) ) );
  unlink( glob( File::Spec->catfile( $tmp_dir, 'import',   '*ppl' ) ) );

  # Clear file with cancel handles and any potential lock files that
  # have been left after a crash
  unlink( File::Spec->catfile( $tmp_dir, 'cancel_data' ) );
  unlink( glob( File::Spec->catfile( $tmp_dir, '*lock' ) ) );

  # Clear session variables
  unlink( File::Spec->catfile($tmp_dir, 'local_session' ) );

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
      or
      FileWriteError->throw("Could not start application (Error initializing settings database)");

    Paperpile::Utils->session($c, {library_db => $c->config->{'user_settings'}->{library_db}});

    # Don't overwrite an existing library database in the case the
    # user has just deleted the user settings database
    if ( !-e $c->config->{'user_settings'}->{library_db} ) {
      copy( $c->path_to('db/library.db')->stringify, $c->config->{'user_settings'}->{library_db} )
        or FileWriteError->throw("Could not start application. Error initializing database.");
      $c->model('Library')->set_default_collections;
    }

    $c->model('User')->set_settings( $c->config->{'user_settings'} );
    $c->model('Library')->set_settings( $c->config->{'library_settings'} );

  }

  # Settings file exists
  else {

    my $library_db = $c->model('User')->get_setting('library_db');

    # User might have deleted or moved her library. In that case we initialize an empty one
    if ( !-e $library_db ) {

      Paperpile::Utils->session($c,{library_db => $c->config->{'user_settings'}->{library_db}});

      copy( $c->path_to('db/library.db')->stringify, $c->config->{'user_settings'}->{library_db} )
        or FileWriteError->throw(
        "Could not start application. Error initializing Paperpile database.");

      $c->model('Library')->set_default_collections;

      # Notify frontend of missing library (is ignored right now)
      LibraryMissingError->throw(
        "Could not find your Paperpile library file $library_db. Start with an empty one.");
    }

    Paperpile::Utils->session($c,{library_db => $library_db});

  }

  # Check versions of databases and migrate them if necessary

  my $db_library_version   = $c->model('Library')->get_setting('db_version');
  my $db_settings_version  = $c->model('User')->get_setting('db_version');
  my $app_library_version  = $c->config->{app_settings}->{library_db_version};
  my $app_settings_version = $c->config->{app_settings}->{settings_db_version};

  if ( ( $db_library_version != $app_library_version )
    or ( $db_settings_version != $app_settings_version ) ) {
    DatabaseVersionError->throw("Database needs to be migrated to latest version");
  }

  if ( not -e $c->config->{'queue_db'} ) {
    copy( $c->path_to('db/queue.db')->stringify, $c->config->{'queue_db'} )
      or
      FileWriteError->throw("Could not start application (Error initializing queue database,  $!)");

  } else {

    #clear queue for now at startup
    my $q = Paperpile::Queue->new();
    $q->clear_all;
  }


}

sub migrate_db : Local {

  my ( $self, $c ) = @_;

  my $mg = Paperpile::Migrate->new('tmp_dir'=>Paperpile::Utils->get_tmp_dir,
                                   'user_settings' => $c->config->{'user_settings'},
                                   'library_settings' => $c->config->{'library_settings'},
                                  );

  $mg->app_library_version( $c->config->{app_settings}->{library_db_version} );
  $mg->app_settings_version( $c->config->{app_settings}->{settings_db_version} );

  $mg->settings_db( $c->config->{'user_settings_db'} );
  $mg->library_db( $c->model('User')->get_setting('library_db') );

  $mg->migrate('library');
  $mg->migrate('settings');

}

1;
