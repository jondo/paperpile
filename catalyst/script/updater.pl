## run with the right perl binary!

use strict;
use YAML;
use JSON;
use Data::Dumper;
use Getopt::Long;
use LWP;
use FindBin;
use File::Temp;
use File::stat;
use File::Find;
use File::Path;
use File::Copy::Recursive qw(rcopy);
use Archive::Zip;
use Digest::MD5;

my $check  = 1;
my $help   = 1;
my $update = 0;

GetOptions(
  'check'  => \$check,
  'c'      => \$check,
  'update' => \$update,
  'u'      => \$update,
  "help" => \$help,
  "h"    => \$help
);

$check =0 if ($update);

my $app_dir = "$FindBin::Bin/../../";

my $mock_app_dir = '/home/wash/tmp/paperpile/version-0.1';

my $update_url = 'http://127.0.0.1:3000/updates';
my $platform   = 'linux64';

my $curr_version_id;
my $curr_version_string;

## First read version information from current installation

eval {
  my $app_settings = YAML::LoadFile("$app_dir/catalyst/conf/settings.yaml")->{app_settings}
    || die($!);
  $curr_version_id     = $app_settings->{version_id}     || die("version_id not found");
  $curr_version_string = $app_settings->{version_string} || die("version string not found");
};

if ($@) {
  print STDERR "Could not read app configuration file ($@)\n";
  exit(1);
}

my $browser = LWP::UserAgent->new();

my $response = $browser->get("$update_url/updates.yaml");

if ( $response->is_error ) {
  die( $response->message, " Code: ", $response->code );
}

my $info = YAML::Load( $response->content ) || die("Failed to read update information");

my @new_versions = ();

my $restart = 0;
my $patch   = 1;

foreach my $item (@$info) {
  if ( $item->{release}->{id} > $curr_version_id ) {
    push @new_versions, $item->{release};
    $restart = 1 if $item->{release}->{restart};
    $patch   = 0 if not $item->{release}->{patch};
  }
}

### Check for updates

if ($check) {

  my $output = {};

  if (@new_versions) {
    $output = {
      'update_available' => 1,
      'restart'          => $restart,
      'patch'            => $patch,
      'updates'          => \@new_versions
    };
  } else {
    $output = { 'update_available' => 0 };
  }

  print to_json($output);

  exit(0);

}

### Apply updates

my $tmp_dir = File::Temp::tempdir( 'paperpile-XXXX', TMPDIR => 1, CLEANUP => 0 );

print "$tmp_dir\n";

foreach my $release ( sort { $a->{id} <=> $b->{id} } @new_versions ) {

  my $patch = sprintf( "patch-%s_to_%s-$platform", $release->{id} - 1, $release->{id} );

  print "Downloading update ", $release->{string}, "\n";

  download( "$update_url/$patch.zip", "$tmp_dir/$patch.zip" );

  open(ZIP, "$tmp_dir/$patch.zip") or die "Can't open $patch.zip ($!)";

  my $c = Digest::MD5->new;

  $c->addfile(*ZIP);

  my $checksum = $c->hexdigest;

  close(ZIP);

  if ($checksum != $release->{md5}){
    die("Error downloading $patch.zip (checksum not correct)");
  }

  print "Extracting $patch.zip\n";

  my $zip = Archive::Zip->new();
  if ( $zip->read("$tmp_dir/$patch.zip") != Archive::Zip::AZ_OK ) {
    die "Error reading ZIP file $patch";
  }

  $zip->extractTree( $patch, "$tmp_dir/$patch" );

  print "Applying patch\n";
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
      my $current_size = stat($file)->size;

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



