package Paperpile;

use strict;
use warnings;

use parent qw/Catalyst/;

use Catalyst qw/
  -Debug
  ConfigLoader
  Static::Simple
  Session
  Session::State::Cookie
  Session::Store::File
  Unicode
  /;

use Catalyst::Runtime '5.70';
use Data::Dumper;
use YAML qw(LoadFile DumpFile);

our $VERSION = '0.03';

__PACKAGE__->config( {

    'View::JSON' => {
      expose_stash => qr/^[^_]/,    #Don't show variables starting with underscore (_)
                                    #Is necessary to hide __instancePerContext object
                                    #but might be useful in other context as well...
    },

    'View::JSON::Tree' => {
      expose_stash => 'tree',       #show only one array of objects
    },

    'Plugin::ConfigLoader' => {
      file          => __PACKAGE__->path_to('conf/settings.yaml'),
      substitutions => {
        PLATFORM => sub {
          my $c = shift;
          return $c->substitutions('PLATFORM');
        },
        USERHOME => sub {
          my $c = shift;
          return $c->substitutions('USERHOME');
        },
        PP_USER_DIR => sub {
          my $c = shift;
          return $c->substitutions('PP_USER_DIR');
        },
      }
    },
  }
);

# We first load the config file ourselves to allow 'recursive'
# substitutions in ConfigLoader, i.e. we can substitute fields
# depending on other settings given in the yaml file.
my $_settings = LoadFile( __PACKAGE__->path_to('conf/settings.yaml') );

sub substitutions {

  my ( $self, $field ) = @_;

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

  # This needs to be adjusted for other platfroms than Linux
  my $userhome    = $ENV{HOME};
  my $pp_user_dir = $ENV{HOME} . '/.paperpile';

  # If we have a development version (i.e. no build number) we use a
  # different user dir to allow parallel usage of a stable Paperpile
  # installation and development
  if ( $_settings->{app_settings}->{build_number} == 0 ) {
    $pp_user_dir = $ENV{HOME} . '/.paperdev';
  }

  my %fields = (
    'USERHOME'    => $userhome,
    'PLATFORM'    => $platform,
    'PP_USER_DIR' => $pp_user_dir
  );

  return $fields{$field};

}

# Start the application
__PACKAGE__->setup();

1;
