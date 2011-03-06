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


package Paperpile;

use strict;
use warnings;

# <<<<<<< HEAD
# use parent qw/Catalyst/;


# use Catalyst qw/
#   -Debug
#   ConfigLoader
#   Static::Simple
#   Unicode
#   /;

# use Catalyst::Runtime '5.70';
# use Data::Dumper;
# use YAML qw(LoadFile DumpFile);
# use File::Spec;
# use File::HomeDir;

# our $VERSION = '0.03';

# __PACKAGE__->config( {

#     'View::JSON' => {
#       expose_stash => qr/^[^_]/,    #Don't show variables starting with underscore (_)
#                                     #Is necessary to hide __instancePerContext object
#                                     #but might be useful in other context as well...
#     },

#     'View::JSON::Tree' => {
#       expose_stash => 'tree',       #show only one array of objects
#     },

#     'Plugin::ConfigLoader' => {
#       file          => __PACKAGE__->path_to('conf/settings.yaml'),
#       substitutions => {
#         PLATFORM => sub {
#           my $c = shift;
#           return $c->substitutions('PLATFORM');
#         },
#         USERHOME => sub {
#           my $c = shift;
#           return $c->substitutions('USERHOME');
#         },
#         PP_USER_DIR => sub {
#           my $c = shift;
#           return $c->substitutions('PP_USER_DIR');
#         },
#         PP_PAPER_DIR => sub {
#           my $c = shift;
#           return $c->substitutions('PP_PAPER_DIR');
#         },
#         PP_TMP_DIR => sub {
#           my $c = shift;
#           return $c->substitutions('PP_TMP_DIR');
#         },
#       }
#     },
#   }
# );


# # We first load the config file ourselves to allow 'recursive'
# # substitutions in ConfigLoader, i.e. we can substitute fields
# # depending on other settings given in the yaml file.
# my $_settings = LoadFile( __PACKAGE__->path_to('conf/settings.yaml') );

# sub substitutions {

#   my ( $self, $field ) = @_;

#   my $platform;
#   if ( $^O =~ /linux/i ) {
#     my @f = `file /bin/ls`;    # More robust way for this??
#     if ( $f[0] =~ /64-bit/ ) {
#       $platform = 'linux64';
#     } else {
#       $platform = 'linux32';
#     }
#   }
#   if ( $^O =~ /cygwin/i or $^O =~ /MSWin/i ) {
#     $platform = 'win32';
#   }

#   if ( $^O =~ /(darwin|osx)/i ) {
#     $platform = 'osx';
#   }

#   # Set basic locations based on platform
#   my $userhome;
#   my $pp_user_dir;
#   my $pp_paper_dir;
#   my $pp_tmp_dir;

#   if ( $platform =~ /linux/ ) {
#     $userhome     = $ENV{HOME};
#     $pp_user_dir  = $ENV{HOME} . '/.paperpile';
#     $pp_paper_dir = $ENV{HOME} . '/.paperpile/papers';

#     my $tmp = $ENV{TMPDIR} || '/tmp';
#     $pp_tmp_dir   = File::Spec->catfile($tmp, "paperpile-".$ENV{USER});

#   }

#   if ( $platform eq 'osx' ) {
#     $userhome     = $ENV{HOME};
#     $pp_user_dir  = $ENV{HOME} . '/Library/Application Support/Paperpile';
#     $pp_paper_dir = $ENV{HOME} . '/Documents/Paperpile';

#     my $tmp = $ENV{TMPDIR} || '/tmp';
#     $pp_tmp_dir   = File::Spec->catfile($tmp, "paperpile-".$ENV{USER});

#   }

#   if ( $platform eq 'win32' ) {

#     $userhome = File::HomeDir->my_home;
#     $pp_user_dir  = File::Spec->catfile(File::HomeDir->my_data,"Paperpile");
#     $pp_paper_dir = File::Spec->catfile(File::HomeDir->my_documents,"Paperpile");
#     $pp_tmp_dir   = File::Spec->catfile(File::HomeDir->my_data,"Temp","paperpile");

#   }


#   # If we have a development version (i.e. no build number) we use a
#   # different user dir to allow parallel usage of a stable Paperpile
#   # installation and development
#   if ( $_settings->{app_settings}->{build_number} == 0 ) {
#     $pp_user_dir  = File::Spec->catfile($userhome,".paperdev");
#     $pp_paper_dir  =File::Spec->catfile($userhome,".paperdev","papers");
#   }

#   my %fields = (
#     'USERHOME'     => $userhome,
#     'PLATFORM'     => $platform,
#     'PP_USER_DIR'  => $pp_user_dir,
#     'PP_PAPER_DIR' => $pp_paper_dir,
#     'PP_TMP_DIR'   => $pp_tmp_dir,
#   );

#   return $fields{$field};

# }

# # Start the application
# __PACKAGE__->setup();
# =======
#use parent qw/Catalyst/;


# use Catalyst qw/
#   -Debug
#   ConfigLoader
#   Static::Simple
#   Unicode
#   /;

# use Catalyst::Runtime '5.70';
# use Data::Dumper;
# use YAML qw(LoadFile DumpFile);
# use File::Spec;

# our $VERSION = '0.03';

# __PACKAGE__->config( {

#     'View::JSON' => {
#       expose_stash => qr/^[^_]/,    #Don't show variables starting with underscore (_)
#                                     #Is necessary to hide __instancePerContext object
#                                     #but might be useful in other context as well...
#     },

#     'View::JSON::Tree' => {
#       expose_stash => 'tree',       #show only one array of objects
#     },

#     'Plugin::ConfigLoader' => {
#       file          => __PACKAGE__->path_to('conf/settings.yaml'),
#       substitutions => {
#         PLATFORM => sub {
#           my $c = shift;
#           return $c->substitutions('PLATFORM');
#         },
#         USERHOME => sub {
#           my $c = shift;
#           return $c->substitutions('USERHOME');
#         },
#         PP_USER_DIR => sub {
#           my $c = shift;
#           return $c->substitutions('PP_USER_DIR');
#         },
#         PP_PAPER_DIR => sub {
#           my $c = shift;
#           return $c->substitutions('PP_PAPER_DIR');
#         },
#         PP_TMP_DIR => sub {
#           my $c = shift;
#           return $c->substitutions('PP_TMP_DIR');
#         },
#       }
#     },
#   }
# );


# # We first load the config file ourselves to allow 'recursive'
# # substitutions in ConfigLoader, i.e. we can substitute fields
# # depending on other settings given in the yaml file.
# my $_settings = LoadFile( __PACKAGE__->path_to('conf/settings.yaml') );

# sub substitutions {

#   my ( $self, $field ) = @_;

#   my $platform;
#   if ( $^O =~ /linux/i ) {
#     my @f = `file /bin/ls`;    # More robust way for this??
#     if ( $f[0] =~ /64-bit/ ) {
#       $platform = 'linux64';
#     } else {
#       $platform = 'linux32';
#     }
#   }
#   if ( $^O =~ /cygwin/i or $^O =~ /MSWin/i ) {
#     $platform = 'windows32';
#   }

#   if ( $^O =~ /(darwin|osx)/i ) {
#     $platform = 'osx';
#   }

#   # Set basic locations based on platform
#   my $userhome;
#   my $pp_user_dir;
#   my $pp_paper_dir;
#   my $pp_tmp_dir;

#   if ( $platform =~ /linux/ ) {
#     $userhome     = $ENV{HOME};
#     $pp_user_dir  = $ENV{HOME} . '/.paperpile';
#     $pp_paper_dir = $ENV{HOME} . '/.paperpile/papers';

#     my $tmp = $ENV{TMPDIR} || '/tmp';
#     $pp_tmp_dir   = File::Spec->catfile($tmp, "paperpile-".$ENV{USER});

#   }

#   if ( $platform eq 'osx' ) {
#     $userhome     = $ENV{HOME};
#     $pp_user_dir  = $ENV{HOME} . '/Library/Application Support/Paperpile';
#     $pp_paper_dir = $ENV{HOME} . '/Documents/Paperpile';

#     my $tmp = $ENV{TMPDIR} || '/tmp';
#     $pp_tmp_dir   = File::Spec->catfile($tmp, "paperpile-".$ENV{USER});

#   }

#   # If we have a development version (i.e. no build number) we use a
#   # different user dir to allow parallel usage of a stable Paperpile
#   # installation and development
#   if ( $_settings->{app_settings}->{build_number} == 0 ) {
#     $pp_user_dir  = $ENV{HOME} . '/.paperdev';
#     $pp_paper_dir = $ENV{HOME} . '/.paperdev/papers';
#   }

#   my %fields = (
#     'USERHOME'     => $userhome,
#     'PLATFORM'     => $platform,
#     'PP_USER_DIR'  => $pp_user_dir,
#     'PP_PAPER_DIR' => $pp_paper_dir,
#     'PP_TMP_DIR'   => $pp_tmp_dir,
#   );

#   return $fields{$field};

# }

# # Start the application
# __PACKAGE__->setup();

1;
