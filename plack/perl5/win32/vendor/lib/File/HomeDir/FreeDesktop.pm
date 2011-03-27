package File::HomeDir::FreeDesktop;

# specific functionality for unixes running free desktops
# compatible with (but not using) File-BaseDir-0.03

use 5.00503;
use strict;
use Carp                ();
use File::Spec          ();
use File::HomeDir::Unix ();
use File::Which         ();

use vars qw{$VERSION @ISA};
BEGIN {
	$VERSION = '0.91';
	@ISA     = 'File::HomeDir::Unix';
}

# xdg uses $ENV{XDG_CONFIG_HOME}/user-dirs.dirs to know where are the
# various "my xxx" directories. That is a shell file. The official API
# is the xdg-user-dir executable. It has no provision for assessing
# the directories of a user that is different than the one we are
# running under; the standard substitute user mechanisms are needed to
# overcome this.

{
    my $xdgprog = File::Which::which('xdg-user-dir');
    sub _my_thingy {
        my ($class, $wanted) = @_;

        # no quoting because input is hard-coded and only comes from this module
        my $thingy = qx($xdgprog $wanted);
        chomp $thingy;
        return $thingy;
    }
}


sub my_desktop   { shift->_my_thingy('DESKTOP');   }
sub my_documents { shift->_my_thingy('DOCUMENTS'); }
sub my_music     { shift->_my_thingy('MUSIC');     }
sub my_pictures  { shift->_my_thingy('PICTURES');  }
sub my_videos    { shift->_my_thingy('VIDEOS');    }

sub my_data {
	$ENV{XDG_DATA_HOME}
	||
	File::Spec->catdir(shift->my_home, qw{ .local share });
}

sub my_download    { shift->_my_thingy('DOWNLOAD');    }
sub my_publicshare { shift->_my_thingy('PUBLICSHARE'); }
sub my_templates   { shift->_my_thingy('TEMPLATES');   }

sub my_cache       {
    $ENV{XDG_CACHE_HOME}
    ||
    File::Spec->catdir(shift->my_home, qw{ .cache });
}

#####################################################################
# General User Methods

sub users_desktop   { Carp::croak('The users_desktop method is not available on an XDG based system.');   }
sub users_documents { Carp::croak('The users_documents method is not available on an XDG based system.'); }
sub users_music     { Carp::croak('The users_music method is not available on an XDG based system.');     }
sub users_pictures  { Carp::croak('The users_pictures method is not available on an XDG based system.');  }
sub users_videos    { Carp::croak('The users_videos method is not available on an XDG based system.');    }
sub users_data      { Carp::croak('The users_data method is not available on an XDG based system.');      }

1;

=pod

=head1 NAME

File::HomeDir::FreeDesktop - find your home and other directories, on unixes running free desktops

=head1 DESCRIPTION

This module provides implementations for determining common user
directories.  In normal usage this module will always be
used via L<File::HomeDir>.

=head1 SYNOPSIS

  use File::HomeDir;
  
  # Find directories for the current user
  $home    = File::HomeDir->my_home;        # /home/mylogin

  $desktop = File::HomeDir->my_desktop;
  $docs    = File::HomeDir->my_documents;
  $music   = File::HomeDir->my_music;
  $pics    = File::HomeDir->my_pictures;
  $videos  = File::HomeDir->my_videos;
  $data    = File::HomeDir->my_data;

