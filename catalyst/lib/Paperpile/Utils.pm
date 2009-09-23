package Paperpile::Utils;
use Moose;
use Moose::Util::TypeConstraints;
use Carp;
use LWP;
use Data::Dumper;
use FindBin;
use Config::General;
use Catalyst::Utils;
use File::Path;
use File::Spec;
use File::Copy;
use Path::Class;
use Config::Any;
use HTTP::Cookies;
use WWW::Mechanize;
use Compress::Zlib;
use MIME::Base64;
use Config;
use Paperpile::Model::User;
use Paperpile::Model::Library;
use Storable qw(lock_store lock_retrieve);

$Data::Dumper::Indent = 1;

sub get_tmp_dir {

  my ( $self ) = @_;

  # This is hard-coded for now. Ideally it should read location from
  # paperpile.yaml. Don't know how to do this without access to $c

  my $tmp_dir= $ENV{HOME} . "/.paperpile/tmp";

  return $tmp_dir;
}

sub get_user_settings_model {

  my $self = shift;

  # This is hard-coded for now. Ideally it should read database
  # location from paperpile.yaml. Don't know how to do this without
  # access to $c and replicating substitution code.

  my $user_settings_db = $ENV{HOME} . "/.paperpile/settings.db";
  my $model            = Paperpile::Model::User->new();
  $model->set_dsn( "dbi:SQLite:" . $user_settings_db );

  return $model;

}

sub get_library_model {

  my $self = shift;

  my $settings = $self->get_user_settings_model->settings;

  my $db_file = $settings->{library_db};
  my $model            = Paperpile::Model::Library->new();
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

  #$browser->proxy('http', 'http://localhost:8146/');

  $browser->cookie_jar( {} );

  $browser->agent('Mozilla/5.0');
  return $browser;
}


### get_config()
### Gives access to config data when $c is not available

sub get_config{

  my $self=shift;

  my $file=$self->home."/paperpile.yaml";

  my $conf = Config::Any->load_files({files=>[$file], flatten_to_hash => 0, use_ext=>1});

  # Take care how to get the data out of the object, in older versions
  # of Config::Any we had to use $conf->[0]->{$file}, with version
  # 0.17 this is fine:
  return $conf->{$file};

}

sub get_binary{

  my ($self, $name)=@_;

  my $platform='';
  my $arch_string=$Config{archname};

  if ( $arch_string =~ /linux/i ) {
    $platform = ($arch_string =~ /64/) ? 'linux64' : 'linux32';
  }

  my $bin=File::Spec->catfile($self->path_to('bin'), $platform, $name);

  return $bin;
}


## Gives access to the installation dir of the application outside
## Catalyst classes. Uses the function from Catalyst::Utils. Copied here,
## because it did not work by calling it from the class for some reason.

sub home {
  my $class = shift;

  ( my $file = "$class.pm" ) =~ s{::}{/}g;

  if ( my $inc_entry = $INC{$file} ) {
    {
      ( my $path = $inc_entry ) =~ s/$file$//;
      my $home = dir($path)->absolute->cleanup;

      $home = $home->parent while $home =~ /b?lib$/;

      if ( -f $home->file("Makefile.PL") or -f $home->file("Build.PL") ) {

        my $dir;
        my @dir_list = $home->dir_list();
        while ( ( $dir = pop(@dir_list) ) && $dir eq '..' ) {
          $home = dir($home)->parent->parent;
        }

        return $home->stringify;
      }
    }

    {
      ( my $path = $inc_entry ) =~ s/\.pm$//;
      my $home = dir($path)->absolute->cleanup;
      return $home->stringify if -d $home;
    }
  }
  # did not find anything
  return 0;
}


## Access to this handy helper function outside of catalyst.

sub path_to {
  (my $self, my @path ) = @_;
  my $path = Path::Class::Dir->new( $self->home, @path );
  if ( -d $path ) { return $path }
  else { return Path::Class::File->new( $self->home, @path ) }
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


# Convert tags that can consists of several words to one
# string. Start, end and spaces are encoded by numbers. We cannot
# encode with special characters as they are ignored by FTS.
# eg. "Really crap papers" gets to "88Really99crap99papers88" This hack
# is necessary to allow searching for a specific tag using FTS.
sub encode_tags {

  (my $self, my $tags) = @_;

  return "" if not $tags;

  my @tags = split(/,/, $tags);

  my @new_tags=();

  foreach my $tag (@tags){

    $tag=~s/ /99/g;
    $tag='88'.$tag.'88';
    push @new_tags, $tag;

  }

  return join(',', @new_tags);

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

sub store {

  my ($self, $item, $ref) = @_;

  my $file = File::Spec->catfile($self->get_tmp_dir(), 'cache', $item);

  lock_store($ref, $file) or  die "Can't write to cache\n";

}


sub retrieve {

  my ($self, $item) = @_;

  my $file = File::Spec->catfile($self->get_tmp_dir(), 'cache', $item);

  my $ref=undef;

  eval {
    $ref = lock_retrieve($file);
  };

  return $ref;

}


