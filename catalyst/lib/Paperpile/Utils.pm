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

$Data::Dumper::Indent = 1;

sub get_browser {

  my ($self, $type) = @_;

  my $browser;

  if (defined $type){
    $browser = WWW::Mechanize->new() if $type eq 'mech';
  } else {
    $browser = LWP::UserAgent->new();
  }

  $browser->proxy('http', 'http://localhost:8146/');
  #my $cookie_jar = HTTP::Cookies->new(
  #  file     => $self->path_to("cookies.txt"),
  #  autosave => 1,
  #  ignore_discard=>1
  #);
  #my $cookie_jar = HTTP::Cookies->new({});

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

  my ($self, $name,$platform)=@_;

  if ($platform =~/windows/i){
    $name.='exe';
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
