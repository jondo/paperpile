
# Copyright 2009, 2010 Paperpile
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
use Moose;

use LWP;
use HTTP::Cookies;
use WWW::Mechanize;

use File::Path;
use File::Spec;
use File::Copy;

use Storable qw(lock_store lock_retrieve);
use Compress::Zlib;
use MIME::Base64;
use Digest::MD5;
use URI::Split qw(uri_split uri_join);

use Data::Dumper;
use Config;

## If we use Utils.pm from a script outside Paperpile it seems we have to also
## "use Paperpile;" in the calling script. Otherwise we get strange errrors.
use Paperpile;
use Paperpile::Model::User;
use Paperpile::Model::Library;
use Paperpile::Model::Queue;


sub get_tmp_dir {

  my ( $self ) = @_;

  return Paperpile->config->{tmp_dir};

}

sub get_user_settings_model {

  my $self = shift;

  my $dsn = Paperpile->config->{'Model::User'}->{dsn};

  my $model = Paperpile::Model::User->new();

  $model->set_dsn($dsn);

  return $model;

}

sub get_queue_model {

  my $self = shift;

  my $dsn = Paperpile->config->{'Model::Queue'}->{dsn};

  my $model = Paperpile::Model::Queue->new();
  $model->set_dsn($dsn);

  return $model;
}



sub get_library_model {

  my $self = shift;

  my $settings = $self->get_user_settings_model->settings;

  my $db_file = $settings->{library_db};
  my $model   = Paperpile::Model::Library->new();
  $model->set_dsn( "dbi:SQLite:" . $db_file );

  return $model;

}


sub get_browser {

  my ( $self, $test_proxy ) = @_;

  my $settings;

  # To test the proxy settings, we can pass the settings directly from
  # the settings screen. Otherwise we read from the user database.
  if ($test_proxy) {
    $settings = $test_proxy;
  } else {

    my $model = $self->get_user_settings_model;
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
    my $fc=File::Spec->catfile($self->path_to('bin'), 'osx','fonts','fonts.conf');
    $ENV{FONTCONFIG_FILE}=$fc;
  }

  my $bin=File::Spec->catfile($self->path_to('bin'), $platform, $name);

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

  return $platform;

}


sub get_config{

  my $self=shift;

  return Paperpile->config;

}

sub home {
  return Paperpile->config->{home};
}


sub path_to {
  (my $self, my @path ) = @_;

  return Paperpile->path_to(@path);

}

## We store root as explicit 'ROOT/' in database and frontend. Adjust
## it to system root.

sub adjust_root {

  (my $self, my $path) = @_;

  my $root = File::Spec->rootdir();
  $path =~ s/^ROOT/$root/;

  return $path;

}

sub encode_db {

  (my $self, my $file) = @_;

  open(FILE, "<$file") || die("Could not read $file ($!)");
  binmode(FILE);

  my $content='';
  my $buff;

  while (read(FILE, $buff, 8 * 2**10)) {
    $content.=$buff;
  }

  my $compressed = Compress::Zlib::memGzip($content) ;
  my $encoded = encode_base64($compressed);

  return $encoded;

}

sub decode_db {

  ( my $self, my $string ) = @_;

  my $compressed=decode_base64($string);
  my $uncompressed = Compress::Zlib::memGunzip($compressed);

  return $uncompressed;

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

sub session {

  my ($self, $c, $data) = @_;

  my $local = 0;

  if (!$local){
    if (not defined $data){
      return $c->session;
    } else {
      foreach my $key (keys %$data){
        if (not defined $data->{$key}){
          delete($c->session->{$key})
        } else {
          $c->session->{$key}= $data->{$key};
        }
      }
    }
  }
}

1;
