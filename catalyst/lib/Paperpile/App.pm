package Paperpile::App;

use strict;

use Mouse;
use Plack::Request;
use Plack::Response;
use Data::Dumper;
use JSON;
use YAML::XS qw(LoadFile DumpFile);
use Cwd qw(abs_path);
use Time::HiRes;
use Text::SimpleTable;
use Template::Tiny;

use File::Spec;
use File::Find;


use Paperpile::App::Context;
use Paperpile::Exceptions;

has '_routes' => ( is => 'rw' );
has '_config' => ( is => 'rw' );

sub startup {

  my ($self) = @_;

  $self->log("Starting Paperpile.");

  my $config = $self->config->{app_settings};

  my $table = Text::SimpleTable->new( 20, 50 );

  $table->row( "System",             $config->{platform} );
  $table->row( "Version",            $config->{version_id} . " (" . $config->{version_name} . ")" );
  $table->row( "Build",              $config->{build_number} );
  $table->row( "User DB version",    $config->{settings_db_version} );
  $table->row( "Library DB version", $config->{library_db_version} );
  $table->row( "QRuntime version",   $config->{qruntime_version} );
  $table->row( "User directory",     $self->config->{paperpile_user_dir} );
  $table->row( "Temp directory",     $self->config->{tmp_dir} );
  $table->row( "User database",      $self->config->{user_db} );

  print STDERR $table->draw;

  $self->log("Loading Controllers.");

  $self->_load_controllers;

  $self->log_routes;

}

sub config {

  my ($self) = @_;

  # If instantiated cache config. However, also allow function calls
  # on class without object
  if ( ref $self ) {
    if ( defined $self->_config ) {
      return $self->_config;
    }
  }

  my $config = $self->_raw_config;

  my $substitutions = $self->_substitutions;

  $self->_substitute_config( $config, $substitutions );

  if ( ref $self ) {
    $self->_config($config);
  }

  return $config;
}

sub get_model {

  my ( $self, $name ) = @_;

  $name = lc($name);

  my $model;

  if ( $name eq "user" ) {
    my $file = $self->config->{user_db};
    return Paperpile::Model::User->new( { file => $file } );
  }

  if ( $name eq "app" ) {
    my $file = $self->path_to( "db", "app.db" );
    return Paperpile::Model::App->new( { file => $file } );
  }

  if ( $name eq "queue" ) {
    my $file = $self->config->{queue_db};
    return Paperpile::Model::Queue->new( { file => $file } );
  }

  if ( $name eq "library" ) {

    my $file = Paperpile::Utils->session->{library_db};

    if ( !$file ) {
      my $file = $self->get_model("User")->settings->{library_db};
    }

    return Paperpile::Model::Library->new( { file => $file } );
  }
}

# Get configuration data without substitution of special fields
sub _raw_config {

  my ($self) = @_;

  my $file = $self->path_to( "conf", "settings.yaml" );

  return LoadFile($file);
}

# Replace special fields such as __USERHOME__ in configuration
# data. This function works recursively through the whole data
# structure ($item is the current node and should be initialized with
# the hashref from _raw_config). The replacement values of the special
# fields are given by $substitutions

sub _substitute_config {

  my ( $self, $item, $substitutions ) = @_;

  # If hash, call myself for each item again.
  if ( ref($item) eq "HASH" ) {
    foreach my $value ( values %{$item} ) {
      my $new_item = ref($value) ? $value : \$value;
      $self->_substitute_config( $new_item, $substitutions );
    }
  }

  # If array, also call myself for each item again.
  if ( ref($item) eq "ARRAY" ) {
    foreach my $value ( @{$item} ) {
      my $new_item = ref($value) ? $value : \$value;
      $self->_substitute_config( $new_item, $substitutions );
    }
  }

  # If scalar, we substitute the special fields __XXX__
  if ( ref($item) eq "SCALAR" ) {

    my $value = $$item;

    if ( $value =~ /__(.*)__/ ) {

      foreach my $pattern ( keys %$substitutions ) {
        my $replacement = $substitutions->{$pattern};
        $value =~ s/__$pattern\__/$replacement/;
      }
    }
    $$item = $value;
  }
}

# Return run-time values for substititions as hash

sub _substitutions {

  my ($self) = @_;

  my $platform;
  if ( $^O =~ /linux/i ) {
    my @f = `file /bin/ls`;    # More robust way for this??
    if ( $f[0] =~ /64-bit/ ) {
      $platform = 'linux64';
    } else {
      $platform = 'linux32';
    }
  }
  if ( $^O =~ /cygwin/i or $^O =~ /MSWin/i ) {
    $platform = 'windows32';
  }

  if ( $^O =~ /(darwin|osx)/i ) {
    $platform = 'osx';
  }

  # Set basic locations based on platform
  my $userhome;
  my $pp_user_dir;
  my $pp_paper_dir;
  my $pp_tmp_dir;

  if ( $platform =~ /linux/ ) {
    $userhome     = $ENV{HOME};
    $pp_user_dir  = $ENV{HOME} . '/.paperpile';
    $pp_paper_dir = $ENV{HOME} . '/.paperpile/papers';

    my $tmp = $ENV{TMPDIR} || '/tmp';
    $pp_tmp_dir = File::Spec->catfile( $tmp, "paperpile-" . $ENV{USER} );

  }

  if ( $platform eq 'osx' ) {
    $userhome     = $ENV{HOME};
    $pp_user_dir  = $ENV{HOME} . '/Library/Application Support/Paperpile';
    $pp_paper_dir = $ENV{HOME} . '/Documents/Paperpile';

    my $tmp = $ENV{TMPDIR} || '/tmp';
    $pp_tmp_dir = File::Spec->catfile( $tmp, "paperpile-" . $ENV{USER} );

  }

  # If we have a development version (i.e. no build number) we use a
  # different user dir to allow parallel usage of a stable Paperpile
  # installation and development
  if ( $self->_raw_config->{app_settings}->{build_number} == 0 ) {
    $pp_user_dir  = $ENV{HOME} . '/.paperdev';
    $pp_paper_dir = $ENV{HOME} . '/.paperdev/papers';
  }

  return {
    'USERHOME'     => $userhome,
    'PLATFORM'     => $platform,
    'PP_USER_DIR'  => $pp_user_dir,
    'PP_PAPER_DIR' => $pp_paper_dir,
    'PP_TMP_DIR'   => $pp_tmp_dir,
  };

}

sub home_dir {

  my ($self) = @_;

  # Find home directory via location of Paperpile.pm file
  foreach my $i ( 0 .. $#INC ) {
    my $dir = $INC[$i];
    if ( -e File::Spec->catfile( $dir, "Paperpile.pm" ) ) {
      $dir =~ s!(/|\\)lib(/|\\)?$!!;
      return abs_path($dir);
    }
  }
}

sub path_to {

  my $self = shift;

  return File::Spec->catfile( $self->home_dir, @_ );

}

sub app {

  my ( $self, $env ) = @_;

  return $self->process_request($env);

}

sub _load_controllers {

  my ($self) = @_;

  my %routes;

  find(
    sub {
      my $name = $File::Find::name;

      if ( $name =~ m!/lib/(Paperpile/.*)\.pm! ) {
        my $class = $1;

        $class =~ s!(/|\\)!::!g;

        eval "use $class;";

        if ($@) {
          die("Could not load controller $class ($@).");
        }

        my $route = $class;

        $route =~ s!Paperpile::Controller::!/!;
        $route =~ s!::!/!;
        $route =~ s!^/Root!/!;
        $route = lc($route);

        $routes{$route} = $class;

      }
    },
    $self->path_to( "lib", "Paperpile", "Controller" )
  );

  $self->_routes( {%routes} );

}

sub not_found {

  my ($self) = @_;
  my $response = Plack::Response->new(404);
  return $response->finalize;
}

sub process_request {

  my ( $self, $env ) = @_;

  my $start_time = Time::HiRes::gettimeofday;

  # Create context object
  my $c = Paperpile::App::Context->new();
  $c->request( Plack::Request->new($env) );
  $c->app($self);

  $self->log( sprintf( "Request %s %s", $c->request->method, $c->request->path_info ) );
  $self->log_parameters( $c->request->parameters );

  # Dispatch url path to right class and method

  my $path = $env->{PATH_INFO};

  my $response;

  if ($path =~/ajax/){
    $response = $self->process_ajax($c, $env);
  }

  if ($path =~/screens/){
    $response = $self->process_templates($c, $env);
  }

  $self->log( sprintf( "Request took %.6fs", Time::HiRes::gettimeofday- $start_time ) );

  return $response;

}

sub process_templates {

  my ( $self, $c, $env ) = @_;

  my $path = $env->{PATH_INFO};

  $path=~s!/screens/!!;

  Paperpile::Controller::Root->templates($c, $path);

  my $template_file = $self->path_to("root","templates",$path.'.tt');

  if (!-e $template_file){
    return $self->not_found;
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

sub process_ajax {
  my ( $self, $c, $env ) = @_;

  my $path = $env->{PATH_INFO};

  # We build a response object
  my $response = Plack::Response->new(200);

  my ( $class, $method ) = ( $path =~ m!(.*)/(.*)$! );
  $class = $self->_routes->{$class};

  if ( !$class ) {
    return $self->not_found;
  }

  # Run controller method
  eval "$class->$method(\$c);";

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


sub log {

  my ( $self, $msg ) = @_;

  print STDERR "[info] " . $msg, "\n";

}

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

  print STDERR $table->draw;

}

sub log_routes {

  my ( $self, $params ) = @_;
  my $table = Text::SimpleTable->new( [ 20, 'Path' ], [ 50, 'Class' ] );

  foreach my $key ( sort keys %{ $self->_routes } ) {
    $table->row( $key, $self->_routes->{$key} );
  }

  print STDERR $table->draw;

}

1;
