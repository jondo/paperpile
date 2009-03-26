package Paperpile::Utils;
use Moose;
use Moose::Util::TypeConstraints;
use Carp;
use LWP;
use Data::Dumper;
use FindBin;
use Config::General;
use Catalyst::Utils;
use File::Spec;
use Path::Class;
use Config::Any;

$Data::Dumper::Indent = 1;

sub get_browser{
  my $browser = LWP::UserAgent->new;
  #$browser->proxy('http', 'http://localhost:8146/');
  $browser->cookie_jar({});
  $browser->agent('Mozilla/5.0');
  return $browser;
}


### get_config()
### Gives access to config data when $c is not available

sub get_config{

  my $self=shift;

  #my $conf = Config::General->new($self->home."/paperpile.yaml");

  my $file=$self->home."/paperpile.yaml";

  my $conf = Config::Any->load_files({files=>[$file], flatten_to_hash => 0});

  return $conf->[0]->{$file};

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

