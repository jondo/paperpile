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


package Paperpile::Utils;
use Mouse;

use LWP;
use HTTP::Cookies;
use WWW::Mechanize;

use File::Path;
use File::Spec;
use File::Copy;

use Storable qw(lock_store lock_retrieve);
use Digest::MD5;
use URI::Split qw(uri_split uri_join);
use Encode;
use XML::Simple;

use Data::Dumper;
use Date::Format;
use Config;

use Paperpile;

use Paperpile::Model::User;
use Paperpile::Model::Library;
use Paperpile::Model::Queue;

sub get_tmp_dir {

  my ( $self ) = @_;

  return Paperpile->tmp_dir;

}

sub get_browser {

  my ( $self, $test_proxy ) = @_;

  my $settings;

  # To test the proxy settings, we can pass the settings directly from
  # the settings screen. Otherwise we read from the user database.
  if ($test_proxy) {
    $settings = $test_proxy;
  } else {

    my $model = $self->get_model("User");
    $settings = $model->settings;
  }

  my $browser = LWP::UserAgent->new();

  if ( $settings->{use_proxy} ) {
    if ( $settings->{proxy} ) {

      my $proxy = $settings->{proxy};

      $proxy =~ s|http://||g;

      if ( $settings->{proxy_user} and $settings->{proxy_passwd} ) {

        # TODO: add user/passwd code. Would be nice if I knew a test
        # proxy for this.

      } else {
        $browser->proxy( 'http', 'http://' . $proxy );
      }
    }
  }

  $browser->cookie_jar( {} );

  $browser->agent('Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.1.5) Gecko/20091109 Ubuntu/9.10 (karmic) Firefox/3.5.5');
  return $browser;
}


# Helper function to check if a get request via LWP user agent was
# successful. $response is the response object of the request and $msg
# and optional message string which will prepended to the error in the
# exception.

sub check_browser_response {

  my ( $self, $response, $msg ) = @_;

  if ( defined $msg ) {
    $msg = "$msg: ";
  } else {
    $msg = '';
  }

  if ( $response->is_error ) {
    NetGetError->throw(
      error => $msg . $response->message,
      code  => $response->code
    );
  }
}


sub get_binary{

  my ($self, $name)=@_;

  my $platform=$self->get_platform;

  if ($platform eq 'osx'){
    # Make sure that fontconfig configuration files are found on OSX
    my $fc=File::Spec->catfile(Paperpile->path_to('bin'), 'osx','fonts','fonts.conf');
    $ENV{FONTCONFIG_FILE}=$fc;
  }

  my $bin=File::Spec->catfile(Paperpile->path_to('bin'), $platform, $name);

  $bin=~s/ /\\ /g;

  return $bin;
}

sub get_platform{

  my ($self) = @_;

  my $platform='';
  my $arch_string=$Config{archname};

  if ( $arch_string =~ /linux/i ) {
    $platform = ($arch_string =~ /64/) ? 'linux64' : 'linux32';
  }

  if ( $arch_string =~ /osx/i ) {
    $platform = 'osx';
  }

  if ( $arch_string =~ /MSWin32/i ) {
    $platform = 'win32';
  }


  return $platform;

}


## We store root as explicit 'ROOT/' in database and frontend. Adjust
## it to system root.

sub adjust_root {

  (my $self, my $path) = @_;

  my $root = File::Spec->rootdir();
  $path =~ s/^ROOT/$root/;

  return $path;

}


# Convert labels that can consists of several words to one
# string. Start, end and spaces are encoded by numbers. We cannot
# encode with special characters as they are ignored by FTS.
# eg. "Really crap papers" gets to "88Really99crap99papers88" This hack
# is necessary to allow searching for a specific label using FTS.
sub encode_labels {

  (my $self, my $labels) = @_;

  return "" if not $labels;

  my @labels = split(/,/, $labels);

  my @new_labels=();

  foreach my $label (@labels){

    $label=~s/ /99/g;
    $label='88'.$label.'88';
    push @new_labels, $label;

  }

  return join(',', @new_labels);

}


# Copies file $source to $dest. Creates directory if not already
# exists and makes sure that file name is unique.

sub copy_file{

  my ( $self, $source, $dest ) = @_;

  # Create directory if not already exists
  my ($volume,$dir,$file_name) = File::Spec->splitpath( $dest );
  mkpath($dir);

  # Make sure file-name is unique
  # For PDFs it is necessarily unique if the PDF pattern includes [key], 
  # However, we allow arbitrary patterns so it can happen that PDFs are not unique.

  # if foo.doc already exists create foo_1.doc
  if (-e $dest){
    my $basename=$file_name;
    my $suffix='';
    if ($file_name=~/^(.*)\.(.*)$/){
      ($basename, $suffix)=($1, $2);
    }

    my @numbers=();
    foreach my $file (glob("$dir/*")){
      if ($file =~ /$basename\_(\d+)\.$suffix$/){
        push @numbers, $1;
      }
    }
    my $new_number=1;
    if (@numbers){
      @numbers=sort @numbers;
      $new_number=$numbers[$#numbers]+1;
    }

    $dest=File::Spec->catfile($dir,"$basename\_$new_number");
    if ($suffix){
      $dest.=".$suffix";
    }
  }

  # copy the file
  copy($source, $dest) || die("Could not copy $source to $dest ($!)");

  return $dest;
}


# Registers a handle from the frontend connects it to the PID of the
# current process. The idea is that the frontend only needs to know
# about the handle and the backend only needs to know about its PID

sub register_cancel_handle {

  my ( $self, $handle ) = @_;

  my $new_cancel_data = { map => {}, cancel => {} };

  my $cancel_data = $self->retrieve('cancel_data');

  if ($cancel_data) {
    $new_cancel_data = $cancel_data;
  }

  $new_cancel_data->{map}->{$$} = $handle;
  $new_cancel_data->{map}->{$handle} = $$;

  $new_cancel_data->{cancel}->{$handle}   = 0;

  $self->store('cancel_data', $new_cancel_data);

}

# Marks a handle for cancelling. The next time a process that is
# associated with handle calls 'check_cancel' gets 1 as answer and
# should stop. If $kill is true, the process associated with the
# handle is killed immediately

sub activate_cancel_handle {

  my ( $self, $handle, $kill ) = @_;

  my $cancel_data = $self->retrieve('cancel_data');

  return if not defined $cancel_data;

  if ($kill){
    my $pid = $cancel_data->{map}->{$handle};
    delete($cancel_data->{map}->{$pid});
    delete($cancel_data->{map}->{$handle});
    delete($cancel_data->{cancel}->{$handle});
    $self->store( 'cancel_data', $cancel_data );

    # Note to future-self: Make sure this works on OSX and windows
    my $processInfo = `ps -A |grep $pid`;

    # Paranoia check to make sure the process is indeed a perl process
    if (! ($processInfo =~/perl/) ){
      die("Cancel would have killed $processInfo. Aborted");
    }

    print STDERR "KILLING: $processInfo";

    kill(9,$pid);

  } else {
    $cancel_data->{cancel}->{$handle} = 1;
  }

  $self->store( 'cancel_data', $cancel_data );

}

# If it returns 1 the process with process id $pid should stop.

sub check_cancel {

  my ( $self, $pid ) = @_;

  my $cancel_data = $self->retrieve('cancel_data');

  return 0 if not defined $cancel_data;

  my $handle = $cancel_data->{map}->{$pid};

  return $cancel_data->{cancel}->{$handle};

}

# Cleanup. Should be called before a process that registered a cancel
# handle quits.

sub clear_cancel {

  my ( $self, $pid ) = @_;

  my $cancel_data = $self->retrieve('cancel_data');

  return 0 if not defined $cancel_data;

  my $handle = $cancel_data->{map}->{$pid};

  delete($cancel_data->{map}->{$pid});
  delete($cancel_data->{map}->{$handle});
  delete($cancel_data->{cancel}->{$handle});

  $self->store( 'cancel_data', $cancel_data );

}

sub calculate_md5 {
  my ($self, $file) = @_;
  open( FILE, "<$file" ) or FileReadError->throw( error => "Could not read " . $file );
  my $c = Digest::MD5->new;
  $c->addfile(*FILE);
  return $c->hexdigest;
}



sub store {

  my ($self, $item, $ref) = @_;

  my $file = File::Spec->catfile($self->get_tmp_dir(), $item);

  lock_store($ref, $file) or  die "Can't write to cache\n";

}


sub retrieve {

  my ($self, $item) = @_;

  my $file = File::Spec->catfile($self->get_tmp_dir(), $item);

  my $ref=undef;

  eval {
    $ref = lock_retrieve($file);
  };

  return $ref;

}

sub find_zotero_sqlite {

  my $self = shift;

  # a typical Zotero path in windows (German)
  # C:\Dokumente und Einstellungen\someone\Anwendungsdaten\
  # Mozilla\Firefox\Profiles\b57sxgsi.default\zotero.sqlite

  # a typical Zotero path in ubuntu
  # ~/.mozilla/firefox/iqurqbah.default/zotero/zotero.sqlite

  # Try to find file in Linux environment
  my $home         = $ENV{'HOME'};
  my $firefox_path = "$home/.mozilla/firefox";
  if ( -d $firefox_path ) {
    my @profiles = ();
    opendir( DIR, $firefox_path );
    while ( defined( my $file = readdir(DIR) ) ) {

      next if ( $file eq '.' or $file eq '..' );
      push @profiles, "$firefox_path/$file"
        if ( -d "$firefox_path/$file" );
    }
    close(DIR);

    foreach my $profile (@profiles) {
      if ( -e "$profile/zotero/zotero.sqlite" ) {
        return "$profile/zotero/zotero.sqlite";
      }
    }
  }

}

# Checks if a file attached in a BibTex or other file exists and
# converts it to a canonical form. If we can't find a readable file we
# return undef

sub process_attachment_name {

  (my $self, my $file) = @_;

  print STDERR "$file\n";

  $file=~s{^file://}{}i;

  # Try to grab the actual path
  if ( $file =~ /^.*:(.*):.*$/ ) {
    $file = $1;
  }

  # Mendeley may escapes underscores (at least on Linux). We
  # have to unescape them to make them work (TODO: check
  # this under Windows).

  $file=~s/\\_/_/g;

  # Mendeley does not show the first '/'. Relative paths are
  # useless so if we don't find the file we try to make this absolute
  # by brute force TODO: make this work for Windows
  if ( !-e $file ) {
    $file = "/$file";
  }

  # If we still do not find a file, it is not readable, or
  # it is a directory, we give up
  if ( !(-e $file) || !(-r $file) || -d $file) {
    return undef;
  } else {
    return $file;
  }
}

# Check list of pubs $pubs for duplicate sha1 and modify title to make
# sure all pubs in the list are unique
sub uniquify_pubs {

  my ($self, $pubs) = @_;

  my %seen;

  foreach my $pub (@$pubs) {
    $pub->sanitize_fields;
    $seen{$pub->sha1} = 0;
  }

  foreach my $pub (@$pubs) {
    my $sha1 = $pub->sha1;
    if ($seen{$sha1} > 0 ){
      $pub->title($pub->title." (Duplicate ".$seen{$sha1}.")");
    }
    $seen{$sha1}++;
  }
}

# Updates the job information for job with $jobid. If $jobid is not
# defined it just returns without doing anything.  The function
# returns 1 if the job was not interrupted, otherwise it returns 0.
# If the optional $cancel_msg is given, it directly throws a
# UserCancel expection with $cancel_msg as content.

sub update_job_info {

  my ( $self, $jobid, $key, $value, $cancel_msg ) = @_;

  return(1) if (!$jobid);

  my $job = Paperpile::Job->new( { id => $jobid } );

  $job->update_info( $key, $value );

  if ($job->interrupt eq "CANCEL"){
    if ($cancel_msg){
      UserCancel->throw( error => $cancel_msg );
    } else {
      return 0;
    }
  } else {
    return 1;
  }

}

sub domain_from_url {

  my ($self, $url) = @_;

  my ( $scheme, $auth, $path, $query, $frag ) = uri_split($url);
  $auth =~ s/^www\.//i;

  return $auth;

}

# Wrapper script around $c->session. On the desktop we use a custom
# solution to store the session to avoid a strange race condition bug
# in the session plugin.

# USAGE: session($c) ... returns hashref of current session data
#        session($c, {key=>value}) ... set key in session data

# Important: The local version writes and restores the data everytime
# the function is called. So if you store an object in the session
# hash and change the object afterwards it will not be updated in the
# session hash unless session is called again.

sub session {

  my ( $self, $c, $data ) = @_;

  my $s = $self->retrieve("local_session");
  $s = {} if !defined $s;

  if ( not defined $data ) {
    return $s;
  } else {
    foreach my $key ( keys %$data ) {
      if ( not defined $data->{$key} ) {
        delete( $s->{$key} );
      } else {
        $s->{$key} = $data->{$key};
      }
    }
    $self->store( "local_session", $s );
  }
}

# Decode $data which was read from external files. If $encoding is
# given use this encoding. Otherwise, we try to decode to UTF-8 and if
# this fails we decode to ISO-LATIN-1. This is probably the best we
# can do although it will fail on any other legacy ASCII extension
# that ISO-LATIN-1.

sub decode_data {

  my ($self, $data, $encoding) = @_;

  # We have an encoding, so use it
  if ($encoding){
    return decode($encoding, $data);
  }

  my $decoded_data;

  # Try to decode in UTF-8. If it is encoded in UTF-8 that's
  # perfect. If the input file is plain ASCII this does not change
  # anything and is also good. If it contains non UTF-8 characters we
  # interpret this as ISO-LATIN-1.
  if (eval { $decoded_data = decode_utf8($data, Encode::FB_CROAK); 1 }) {
    return $decoded_data;
  } else {
    return decode('iso-8859-1', $data);
  }
}


sub gm_timestamp {

  my @time = gmtime(time);
  return strftime( "%Y-%m-%d %X", @time );

}


# Run extpdf with arguments given as hashref in $arguments. Returns
# either hashref with results (INFO, WORDLIST) or a simple scalar
# value with the data (TEXT, RENDER)

sub extpdf {

  my ( $self, $arguments ) = @_;

  my $command = $arguments->{command};

  if ( !( $command ~~ [ 'INFO', 'WORDLIST', 'TEXT', 'RENDER' ] ) ) {
    ExtpdfError->throw( error => "Unknown command '$command' for extpdf" );
  }

  my $extpdf = $self->get_binary('extpdf');

  my $xml = XMLout( $arguments, RootName => 'extpdf', XMLDecl => 1, NoAttr => 1 );

  my ( $fh, $filename ) = File::Temp::tempfile();
  print $fh $xml;
  close($fh);

  my @result = `$extpdf $filename`;

  if ( $? != 0 ) {
    ExtpdfError->throw( error => "Unknown error in extpdf." );
  }

  my ($output_string, $output);

  $output_string.=$_ foreach (@result);

  if ($command ~~ ['INFO', 'WORDLIST']){
    $output = XMLin($output_string);
  } else {
    $output = $output_string;
  }

  unlink($filename);

  return $output;

}

sub get_model {

  my ( $self, $name ) = @_;

  $name = lc($name);

  my $model;

  if ( $name eq "user" ) {
    my $file = Paperpile->config->{user_db};
    return Paperpile::Model::User->new( { file => $file } );
  }

  if ( $name eq "app" ) {
    my $file = Paperpile->path_to( "db", "app.db" );
    return Paperpile::Model::App->new( { file => $file } );
  }

  if ( $name eq "queue" ) {
    my $file = Paperpile->config->{queue_db};
    return Paperpile::Model::Queue->new( { file => $file } );
  }

  if ( $name eq "library" ) {

    my $file = $self->session->{library_db};

    if ( !$file ) {
      my $file = $self->get_model("User")->settings->{library_db};
    }

    return Paperpile::Model::Library->new( { file => $file } );
  }
}



1;
