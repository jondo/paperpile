# Copyright 2009-2011 Paperpile
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


package Paperpile::App;

use strict;

use Mouse;
use Plack::Request;
use Plack::Response;
use Data::Dumper;
use JSON;
use Time::HiRes;
use Text::SimpleTable;
use Template::Tiny;
use File::Find;

use Paperpile;
use Paperpile::App::Context;
use Paperpile::Exceptions;

has '_routes' => ( is => 'rw' );


# The central app function for Plack
sub app {

  my ( $self, $env ) = @_;

  return $self->process_request($env);

}

# Show startup logs and call initialization functions
sub startup {

  my ($self) = @_;

  Paperpile->log("Starting Paperpile.");

  my $table = Text::SimpleTable->new( 20, 50 );

  my $config = Paperpile->config;
  my $c      = $config->{app_settings};

  $table->row( "System",             $c->{platform} );
  $table->row( "Version",            $c->{version_id} . " (" . $c->{version_name} . ")" );
  $table->row( "Build",              $c->{build_number} );
  $table->row( "User DB version",    $c->{settings_db_version} );
  $table->row( "Library DB version", $c->{library_db_version} );
  $table->row( "QRuntime version",   $c->{qruntime_version} );
  $table->row( "User directory",     $config->{paperpile_user_dir} );
  $table->row( "Temp directory",     $config->{tmp_dir} );
  $table->row( "User database",      $config->{user_db} );

  print STDERR $table->draw if $ENV{PLACK_DEBUG};

  Paperpile->log("Loading Controllers.");

  $self->_prepare_controllers;

  $self->log_routes;

}

# Dynamically load controller classes
sub _prepare_controllers {

  my ($self) = @_;

  my %routes;

  find(
    sub {
      my $name = $File::Find::name;

      $name =~ s!\\!/!g;

      if ( $name =~ m!/lib/(Paperpile/.*)\.pm! ) {
        my $class = $1;

        $class =~ s!(/|\\)!::!g;

        eval("use $class;");

        my $route = $class;

        $route =~ s!Paperpile::Controller::!/!;
        $route =~ s!::!/!;
        $route =~ s!^/Root!/!;
        $route = lc($route);

        $routes{$route} = $class;

      }
    },
    Paperpile->path_to( "lib", "Paperpile", "Controller" )
  );

  $self->_routes( {%routes} );

}


# Dispatch request to various handler functions
sub process_request {

  my ( $self, $env ) = @_;

  my $start_time = Time::HiRes::gettimeofday;

  # Create context object
  my $c = Paperpile::App::Context->new();
  $c->request( Plack::Request->new($env) );
  $c->app($self);

  Paperpile->log( sprintf( "Request %s %s", $c->request->method, $c->request->path_info ) );
  $self->log_parameters( $c->request->parameters );

  # Dispatch url path to right class and method

  my $path = $env->{PATH_INFO};

  my $response;

  # Ajax call
  if ($path =~/ajax/){
    $response = $self->process_ajax($c, $env);
  }

  # HTML page
  if ($path =~/screens/){
    $response = $self->process_templates($c, $env);
  }

  Paperpile->log( sprintf( "Request took %.6fs", Time::HiRes::gettimeofday- $start_time ) );

  return $response;

}

# Display templated HTML pages
sub process_templates {

  my ( $self, $c, $env ) = @_;

  my $path = $env->{PATH_INFO};

  $path=~s!/screens/!!;

  require Paperpile::Controller::Root;

  Paperpile::Controller::Root->templates($c, $path);

  my $template_file = Paperpile->path_to("root","templates",$path.'.tt');

  if (!-e $template_file){
    return $self->not_found($env);
  }

  my $template = '';
  open(TT,"<$template_file");
  $template.=$_ foreach (<TT>);

  my $tt = Template::Tiny->new();

  my $body ='';

  $tt->process( \$template, $c->stash, \$body );

  my $response = Plack::Response->new(200);

  $response->content_type('text/html');

  $response->body($body);

  return $response->finalize;

}

# Process Ajax request.
sub process_ajax {
  my ( $self, $c, $env ) = @_;

  my $path = $env->{PATH_INFO};

  # We build a response object
  my $response = Plack::Response->new(200);

  my ( $class, $method ) = ( $path =~ m!(.*)/(.*)$! );
  $class = $self->_routes->{$class};

  if ( !$class ) {
    return $self->not_found($env);
  }

  # Run controller method
  eval "require $class; $class->$method(\$c);";

  # Handle errors
  if ($@) {
    my $error = Exception::Class->caught();

    # We have thrown a Paperpile exception and return details of this
    # exception with status 200.
    if ( ref($error) ) {
      $response->status(200);
      my $data = {
        msg  => $error->error,
        type => ref($error)
      };

      foreach my $field ( $error->Fields ) {
        $data->{$field} = $error->$field;
      }

      $c->stash->{error} = $data;

      print STDERR "[error] Caught ". ref($error) . ": ". $error->error, "\n";

    }

    # Some other error, we return status 500 and the perl error
    # message
    else {
      $response->status(500);
      $c->stash->{error} = {
        msg  => "$@",
        type => 'Unknown',
      };
      print STDERR "[error] $@\n";
    }
  }

  # Create json encoded body from data in stash
  $response->content_type('application/json');

  my $json;

  if ($c->stash->{tree}){
    $json = JSON->new->utf8->encode( $c->stash->{tree} );
  } else {
    $json = JSON->new->utf8->encode( $c->stash );
  }
  $response->body($json);

  return $response->finalize;

}


# Return 404 not found message
sub not_found {

  my ($self, $env) = @_;

  Paperpile->log("Path". $env->{PATH_INFO}. "not found.");

  my $response = Plack::Response->new(404);
  return $response->finalize;
}

# Pretty print request parameters
sub log_parameters {

  my ( $self, $params ) = @_;
  my $table = Text::SimpleTable->new( [ 20, 'Key' ], [ 50, 'Value' ] );

  foreach my $key ( keys %$params ) {
    my $value = join( ",", $params->get_all($key) );

    $table->row( $key, $value );
  }

  if ( !%$params ) {
    $table->row( "", "No parameters" );
  }

  print STDERR $table->draw if $ENV{PLACK_DEBUG};

}

# Pretty print controllers and their routes
sub log_routes {

  my ( $self, $params ) = @_;
  my $table = Text::SimpleTable->new( [ 20, 'Path' ], [ 50, 'Class' ] );

  foreach my $key ( sort keys %{ $self->_routes } ) {
    $table->row( $key, $self->_routes->{$key} );
  }

  print STDERR $table->draw if $ENV{PLACK_DEBUG};

}

1;
