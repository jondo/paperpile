## Run with the Paperpile perl binary!

# Copyright 2009, 2010 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.  You should have received a
# copy of the GNU General Public License along with Paperpile.  If
# not, see http://www.gnu.org/licenses.

use strict;
use FindBin;
use Getopt::Long;

use YAML;
use JSON;
use Data::Dumper;

use File::Temp;
use File::Find;
use File::Path;
use File::Copy::Recursive qw(rcopy);

use Archive::Zip;
use Digest::MD5;

use LWP;

# Force output as it happens
$| = 1;

# Catch all errors and return them as JSON. Note that the script
# always return 0
$SIG{__DIE__} = sub { print STDOUT to_json( { error => @_ } ), "\n"; };

open STDERR, ">/dev/null";

####################### General settings #############################

my $app_dir             = "$FindBin::Bin/../../";
my $update_url          = 'http://paperpile.com/download/files';
my $latest              = 'latest';
my $progress_resolution = 10;
my $platform            = get_platform();

# Mock dir for testing; It is not wise to patch the development
# working directory
#$app_dir = '/home/wash/tmp/paperpile/paperpile';

####################### Command line options #########################

my $check  = 1;
my $update = 0;
my $debug  = 0;
my $help   = 0;

GetOptions(
  'check'  => \$check,
  'c'      => \$check,
  'update' => \$update,
  'debug'  => \$debug,
  'u'      => \$update,
  'help'   => \$help,
  'h'      => \$help
);

$check = 0 if ($update);

# To test the release before it is live we can use the --debug option
# or set the PP_DEBUG environment variable
if ( $ENV{PP_DEBUG} ) {
  $debug = 1;
}

$latest = 'stage' if $debug;

######### Read version information from current installation #########

my $curr_version_id;
my $curr_version_name;

my $app_settings = YAML::LoadFile("$app_dir/catalyst/conf/settings.yaml")->{app_settings}
  || die($!);

$curr_version_id   = $app_settings->{version_id}   || die("version_id not found");
$curr_version_name = $app_settings->{version_name} || die("version name not found");

my $needs_sudo = ( -w "$app_dir/catalyst/conf/settings.yaml" ) ? 0 : 1;

########### Get update information from remote server ################

my $browser = LWP::UserAgent->new();

my $response = $browser->get("$update_url/$latest/updates.yaml");

if ( $response->is_error ) {
  die( $response->message, " Code: ", $response->code );
}

my $info = YAML::Load( $response->content ) || die("Failed to read update information");

my @new_versions = ();

my $restart         = 0;    # A restart is needed
my $patch_available = 1;    # Update can be done via a patch (or series of patches)
my $download_size   = 0;    # The total size of downloads

foreach my $item (@$info) {

  if ( $item->{release}->{id} > $curr_version_id ) {

    $item->{release}->{patch_name} =
      sprintf( "patch-%s_to_%s-$platform", $item->{release}->{id} - 1, $item->{release}->{id} );

    $restart         = 1 if $item->{release}->{restart};
    $patch_available = 0 if not $item->{release}->{patch};
    $download_size += $item->{release}->{size}->{$platform};

    push @new_versions, $item->{release};
  }
}

########## --check: Report the update details and exit ###############

if ($check) {

  my $output = {};

  if (@new_versions) {
    $output = {
      'update_available' => 1,
      'restart'          => $restart,
      'patch_available'  => $patch_available,
      'download_size'    => $download_size,
      'updates'          => \@new_versions
    };
  } else {
    $output = { 'update_available' => 0 };
  }

  print to_json($output), "\n";

  exit(0);
}

################## --update: Apply the updates #######################

if ($needs_sudo) {

  #`sudo -k`;    # reset sudo to force password entry for gksudo every time (for testing)

  # Get catalyst base dir via the include path of the perl binary
  my $cat_path = $INC[0];
  $cat_path =~ s!/perl5/$platform/base!!;

  my $call = "$cat_path/perl5/$platform/bin/perl $cat_path/script/updater.pl --update";

  if ($debug) {
    $call .= " --debug";
  }

  # We support gksudo and pkexec, kdesudo behaved strangely and is not
  # supported for now

  my $gksudo = `which gksudo`;
  my $pkexec = `which pkexec`;

  chomp($gksudo);
  chomp($pkexec);

  my $login_error = to_json( {
      error =>
        'Administrative privileges are required to perform the update. Authentication failed.'
    }
  );

  my $sudo_error = to_json(
    { error => 'Authentication failed. Please install gksudo or kdesudo to perform the update.' } );

  if ($gksudo) {

    # Call myself via gksudo
    my $code = system("$gksudo -k -D Paperpile -- $call");

    # If 'Cancel' is hit or password is wrong gksudo return non-zero
    # value (the script itself always returns 0, if an error occurs
    # this goes to the json output)
    if ( $code != 0 ) {
      print $login_error, "\n";
    }
    exit(0);

  } elsif ($pkexec) {

    my $code = system("pkexec $call");

    if ( $code != 0 ) {
      print $login_error, "\n";
    }
    exit(0);

  } else {
    print $sudo_error, "\n";
    exit(0);
  }
}

# For the case that --update is given but no updates are available
die("No update available") if ( not @new_versions );

@new_versions = sort { $a->{id} <=> $b->{id} } @new_versions;

my $tmp_dir = File::Temp::tempdir( 'paperpile-XXXX', TMPDIR => 1, CLEANUP => 0 );

my $downloaded = 0;

##### Download #####

my $status = 'DOWNLOAD';
echo("Downloading updates");

foreach my $release (@new_versions) {

  my $patch = $release->{patch_name};

  my ( $from, $to ) = ( $patch =~ /patch-(\d+)_to_(\d+)-.*/ );

  download( "$update_url/$to/$patch.zip", "$tmp_dir/$patch.zip" );

  open( ZIP, "$tmp_dir/$patch.zip" ) or die "Can't open $patch.zip ($!)";

  my $c = Digest::MD5->new;

  $c->addfile(*ZIP);

  my $checksum = $c->hexdigest;

  close(ZIP);

  if ( $checksum != $release->{md5}->{$platform} ) {
    die("Error downloading $patch.zip (checksum not correct)");
  }
}

##### Extract ######

$status = 'EXTRACT';
echo("Extracting updates");

foreach my $release (@new_versions) {

  my $patch = $release->{patch_name};

  my $zip = Archive::Zip->new();

  if ( $zip->read("$tmp_dir/$patch.zip") != Archive::Zip::AZ_OK ) {
    die "Error reading ZIP file $patch";
  }

  $zip->extractTree( $patch, "$tmp_dir/$patch" );

}

##### Apply the updates ######

$status = 'PATCH';
echo("Applying updates");

foreach my $release (@new_versions) {
  my $patch = $release->{patch_name};
  apply_patch( $app_dir, "$tmp_dir/$patch" );
}

####################### Helper functions #############################

sub download {

  my ( $url, $file ) = @_;

  my $chunk_size = $download_size / $progress_resolution;
  my $curr_chunk = 0;

  open( FILE, ">$file" ) || die("Could not write $file ($!)");
  binmode FILE;

  my $res = $browser->request(
    HTTP::Request->new( GET => $url ),
    sub {
      my ( $data, $response, $protocol ) = @_;
      print FILE $data;
      $downloaded += length($data);
      $curr_chunk += length($data);
      if ( $curr_chunk >= $chunk_size ) {
        echo("Downloading updates");
        $curr_chunk = 0;
      }
    }
  );

  close(FILE);

  my $error = '';
  my $code  = $res->code;

  if ( $res->header("X-Died") || !$res->is_success ) {
    unlink($file);
    if ( $res->header("X-Died") ) {
      $error = $res->header("X-Died");
    } else {
      $error = $res->message;
    }
  }

  if ($error) {
    die("Error downloading $url ($error, $code)");
  }

}

sub apply_patch {

  my ( $dest_dir, $patch_dir, $rollback_dir ) = @_;

  find( {
      no_chdir => 1,
      wanted   => sub {
        my $file_abs = $File::Find::name;
        my $file_rel = File::Spec->abs2rel( $file_abs, $patch_dir );
        rcopy( $file_abs, "$dest_dir/$file_rel" );
        }
    },
    $patch_dir
  );

  open( DIFF, "<$patch_dir/__DIFF__" )
    || die("Could not read __DIFF__ listing in patch directory ( $!)");

  while (<DIFF>) {
    my ( $status, $file ) = split;
    if ( $status eq 'D' ) {
      if ( -d "$dest_dir/$file" ) {
        rmtree("$dest_dir/$file");
      } else {
        unlink("$dest_dir/$file");
      }
    }
  }

  unlink("$dest_dir/__DIFF__");

}

sub echo {

  my $msg = shift;

  my $data = { msg => $msg, status => $status };

  $data->{downloaded} = $downloaded if defined($downloaded);

  print to_json($data), "\n";

}

sub get_platform {

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

  if ( $^O =~ /darwin/i ) {
    $platform = 'osx';
  }

  return $platform;

}

