package Paperpile;

use strict;
use warnings;
use parent qw/Catalyst/;
use Catalyst qw/Session Session::State::Cookie Session::Store::File Unicode/;

use Catalyst::Runtime '5.70';

use LWP;

our $VERSION = '0.03';

__PACKAGE__->config( {
    'View::JSON' => {
      expose_stash => qr/^[^_]/,    #Don't show variables starting with underscore (_)
                                    #Is necessary to hide __instancePerContext object
                                    #but might be useful in other context as well...
    }
  }
);

__PACKAGE__->config( {
    'View::JSON::Tree' => {
      expose_stash => 'tree',       #show only one array of objects
    }
  }
);



__PACKAGE__->config->{'Plugin::ConfigLoader'}->{substitutions} = {
  PLATFORM => sub {
    my $c = shift;
    my $platform;
    if ( $^O =~ /linux/i ) {
      my @f = `file /bin/ls`;       # More robust way for this??
      if ( $f[0] =~ /64-bit/ ) {
        $platform = 'linux64';
      } else {
        $platform = 'linux32';
      }
    }
    if ( $^O =~ /cygwin/i or $^O =~ /MSWin/i ) {
      $platform = 'windows32';
    }
    return $platform;
  },
  USERHOME => sub {
    # Add code for other platforms here
    return $ENV{HOME};
  }
};


# Hardcoded for Linux
__PACKAGE__->config( {
    'session' => {
                  storage => $ENV{HOME}."/.paperpile/tmp/session"
    }
  }
);


# Start the application
__PACKAGE__->setup(qw/-Debug ConfigLoader Static::Simple/);

1;
