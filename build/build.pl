#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use File::Path;
use File::Find;
use File::Spec::Functions qw(catfile);
use File::Copy::Recursive qw(fcopy dircopy);
use 5.010;

my $platform = 'linux64';
my $cat_dir  = '../catalyst';
my $ti_dir   = "../titanium/$platform";

my $target_dir = '../dist/data';

my @ignore = (
  qr([~#]),                qr{/tmp/},
  qr{/t/},                 qr{\.gitignore},
  qr{base/CORE/},          qr{base/pod/},
  qr{(base|cpan)/CPAN},    qr{(base|cpan)/Test},
  qr{base/unicore/.*txt$}, qr{runtime/(template|webinspector|installer)},
  qr{catalyst/data/journals.list},
);

if ( $platform eq 'linux64' ) {
  push @ignore, qr{/(perl5|bin)/(linux32|osx|win32)};
}

mkpath( catfile("$target_dir/$platform/catalyst") );

my $list = get_list($cat_dir);
copy_list( $list, $cat_dir, "$platform/catalyst" );

$list = get_list($ti_dir);
copy_list( $list, $ti_dir, $platform );

symlink "catalyst/root", "$target_dir/$platform/Resources";

sub get_list {

  my $source_dir = shift;

  my @list = ();

  find( {
      no_chdir => 1,
      wanted   => sub {
        my $name = $File::Find::name;
        return if -d $name;
        foreach my $r (@ignore) {
          return if $name =~ $r;
        }
        push @list, File::Spec->abs2rel( $name, $source_dir );
        }
    },
    $source_dir
  );

  return \@list;

}

sub copy_list {
  my ( $list, $source_dir, $prefix ) = @_;
  foreach my $file (@$list) {
    fcopy( catfile( $source_dir, $file ), catfile( $target_dir, $prefix, $file ) )
      or die( $!, $file );
  }
}

