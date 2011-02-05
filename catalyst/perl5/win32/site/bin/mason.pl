#!C:\Users\wash\play\local\strawberry\perl\bin\perl.exe 

use strict;
use HTML::Mason '1.11';
use File::Basename qw(dirname basename);
use File::Spec ();
use Cwd ();

my ($params, $component, $args) = parse_command_line(@ARGV);

# Set a default comp_root
unless (exists $params->{comp_root}) {
  if (File::Spec->file_name_is_absolute($component)) {
    $params->{comp_root} = dirname($component);
    $component = '/' .  basename($component);
  } else {
    $params->{comp_root} = Cwd::cwd;
    # Convert local path syntax to slashes
    my ($dirs, $file) = (File::Spec->splitpath($component))[1,2];
    $component = '/' . join '/', File::Spec->splitdir($dirs), $file;
  }
}

my $interp = HTML::Mason::Interp->new(%$params);
$interp->exec($component, @$args);

#######################################################################################
sub parse_command_line {
  die usage() unless @_;

  my %params;
  while (@_) {
    if ( $_[0] eq '--config_file' ) {
      shift;
      my $file = shift;
      eval {require YAML; 1}
	or die "--config_file requires the YAML Perl module to be installed.\n";
      my $href = YAML::LoadFile($file);
      @params{keys %$href} = values %$href;
      
    } elsif ( $_[0] =~ /^--/ ) {
      my ($k, $v) = (shift, shift);
      $k =~ s/^--//;
      $params{$k} = $v;
      
    } else {
      my $comp = shift;
      return (\%params, $comp, \@_);
    }
  }

  die usage();
}

sub usage {
  return <<EOF;

 Usage: $0 [--param1 value1 ...] [--config_file file] component [arg1 arg2 ...]
  e.g.: $0 --comp_root /mason/comps component.mas
    or: $0 --config_file /mason/config.yaml component.mas foo 5 bar 3
 
    Use --config_file to specify any additional parameters.
 
    'comp_root' defaults to current directory if component has a 
    relative path, or to dirname(component) otherwise.
 
    See `perldoc HTML::Mason::Params` for a list of valid parameters.

EOF
}
