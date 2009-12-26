## run with the right perl binary!

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

# Catch all errors and return them as JSON
$SIG{__DIE__} = sub { print to_json( { error => @_ } ); };

### General settings

my $app_dir      = "$FindBin::Bin/../../";
my $mock_app_dir = '/home/wash/tmp/paperpile/version-0.1';
my $update_url   = 'http://127.0.0.1:3000/updates';
my $platform     = 'linux64';

### Command line options

my $check  = 1;
my $update = 0;
my $help   = 0;

GetOptions(
  'check'  => \$check,
  'c'      => \$check,
  'update' => \$update,
  'u'      => \$update,
  "help"   => \$help,
  "h"      => \$help
);

$check = 0 if ($update);

### Read version information from current installation

my $curr_version_id;
my $curr_version_string;

my $app_settings = YAML::LoadFile("$app_dir/catalyst/conf/settings.yaml")->{app_settings}
  || die($!);
$curr_version_id     = $app_settings->{version_id}     || die("version_id not found");
$curr_version_string = $app_settings->{version_string} || die("version string not found");

### Get update file from remote server

my $browser = LWP::UserAgent->new();

my $response = $browser->get("$update_url/updates.yaml");

if ( $response->is_error ) {
  die( $response->message, " Code: ", $response->code );
}

my $info = YAML::Load( $response->content ) || die("Failed to read update information");

### Check if new updates are available and collect details for these updates

my @new_versions = ();

my $restart       = 0;    # A restart is needed
my $patch         = 1;    # Update can be done via a patch (or series of patches)
my $download_size = 0;    # The total size of downloads

foreach my $item (@$info) {

  if ( $item->{release}->{id} > $curr_version_id ) {

    $item->{release}->{patch_name} =
      sprintf( "patch-%s_to_%s-$platform", $item->{release}->{id} - 1, $item->{release}->{id} );

    $restart = 1 if $item->{release}->{restart};
    $patch   = 0 if not $item->{release}->{patch};
    $download_size += $item->{release}->{size};

    push @new_versions, $item->{release};
  }
}

die("Killed here");

### If --check is given we just report the update details and exit

if ($check) {

  my $output = {};

  if (@new_versions) {
    $output = {
      'update_available' => 1,
      'restart'          => $restart,
      'patch'            => $patch,
      'download_size'    => $download_size,
      'updates'          => \@new_versions
    };
  } else {
    $output = { 'update_available' => 0 };
  }

  print to_json($output);

  exit(0);
}

### Apply the updates

@new_versions = sort { $a->{id} <=> $b->{id} } @new_versions;

my $tmp_dir = File::Temp::tempdir( 'paperpile-XXXX', TMPDIR => 1, CLEANUP => 0 );

my $downloaded = 0;

my $status = 'DOWNLOAD';
echo("Downloading updates");

foreach my $release (@new_versions) {

  my $patch = $release->{patch_name};

  download( "$update_url/$patch.zip", "$tmp_dir/$patch.zip" );

  open( ZIP, "$tmp_dir/$patch.zip" ) or die "Can't open $patch.zip ($!)";

  my $c = Digest::MD5->new;

  $c->addfile(*ZIP);

  my $checksum = $c->hexdigest;

  close(ZIP);

  if ( $checksum != $release->{md5} ) {
    die("Error downloading $patch.zip (checksum not correct)");
  }
}

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

$status = 'PATCH';
echo("Applying updates");

foreach my $release (@new_versions) {
  my $patch = $release->{patch_name};
  apply_patch( $mock_app_dir, "$tmp_dir/$patch" );
}

sub download {

  my ( $url, $file ) = @_;

  open( FILE, ">$file" ) || die("Could not write $file ($!)");
  binmode FILE;

  my $res = $browser->request(
    HTTP::Request->new( GET => $url ),
    sub {
      my ( $data, $response, $protocol ) = @_;
      print FILE $data;
      $downloaded += length($data);
      echo("Downloading updates");
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
