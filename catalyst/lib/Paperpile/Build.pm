
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

package Paperpile::Build;
use Moose;

use Paperpile::Model::User;
use Paperpile::Model::Library;
use Paperpile::Utils;

use Config;

use Data::Dumper;
use File::Path;
use File::Find;
use File::Spec::Functions qw(catfile);
use File::Copy::Recursive qw(fcopy dircopy rcopy);
use File::DirCompare;
use File::stat;
use File::Temp qw/tempdir /;
use Digest::MD5;
use Data::GUID;

use YAML qw(LoadFile DumpFile);

has cat_dir  => ( is => 'rw' );    # catalyst directory
has ti_dir   => ( is => 'rw' );    # titanium directory
has dist_dir => ( is => 'rw' );    # distribution directory
has yui_jar  => ( is => 'rw' );    #YUI compressor jar

# File patterns to ignore while packaging

my %ignore = (
  all => [
    qr([~#]),                qr{/tmp/},
    qr{/t/},                 qr{\.gitignore},
    qr{base/CORE/},          qr{base/pod/},
    qr{(base|cpan)/CPAN},    qr{(base|cpan)/Test},
    qr{base/unicore/.*txt$}, qr{runtime/(template|webinspector|installer)},
    qr{ext3/examples},       qr{ext3/src},
    qr{journals.list},
  ],

  linux64 => [qr{/(perl5|bin)/(linux32|osx|win32)}],
  linux32 => [qr{/(perl5|bin)/(linux64|osx|win32)}],
  osx => [qr{/(perl5|bin)/(linux32|linux64|win32)}, qr{Contents/runtime}],

);

sub echo {

  my ( $self, $msg ) = @_;

  my ( $sec, $min, $hour, $day, $month, $year ) = (localtime)[ 0, 1, 2, 3, 4, 5 ];
  printf "[%02d/%02d/%04d %02d:%02d:%02d] %s\n",
    $month + 1, $day, $year + 1900, $hour, $min, $sec, $msg;

}

## Initialize database files

sub initdb {

  my $self = shift;

  chdir $self->cat_dir;

  my $arch_string=$Config{archname};
  if ( $arch_string =~ /(darwin|osx)/i ) {
     $ENV{PATH} = "bin/osx:".$ENV{PATH};
     $ENV{DYLD_LIBRARY_PATH} = "bin/osx";
  }

#  chdir $self->cat_dir . "/db";

  foreach my $key ( 'app', 'user', 'library', 'queue' ) {
    print STDERR "Initializing db/$key.db...\n";
    unlink "db/$key.db";
    my @out = `sqlite3 db/$key.db < db/$key.sql;`;
    print @out;
  }

  my $model = Paperpile::Model::Library->new();
  $model->set_dsn( "dbi:SQLite:" . "db/library.db" );
  $model->connect;

  print join(" ",keys(%{$model->dbh}))."\n";

  my $yaml   = "conf/fields.yaml";
  my $config = LoadFile($yaml);
  foreach my $field ( keys %{ $config->{pub_fields} } ) {
    $model->dbh->do("ALTER TABLE Publications ADD COLUMN $field TEXT");
  }

  foreach my $field ('created','journal','year','authors','attachments','pdf','annote'){
    $model->dbh->do("CREATE INDEX $field\_index ON Publications (trashed,$field);");
  }

  $model->dbh->do("CREATE INDEX guid_index ON Publications (guid);");

  print STDERR "Importing journal list into app.db...\n";

  open( JOURNALS, "<data/journals.list" );
  $model = Paperpile::Model::App->new();
  $model->set_dsn( "dbi:SQLite:" . "db/app.db" );

  $model->dbh->begin_work();

  my %data = ();

  my %seen = ();

  foreach my $line (<JOURNALS>) {

    next if $line =~ /^$/;
    next if $line =~ /^\s*#/;

    my ( $long, $short, $issn, $essn, $source, $url, $reviewed ) = split( /;/, $line );

    $short    = $model->dbh->quote($short);
    $long     = $model->dbh->quote($long);
    $issn     = $model->dbh->quote($issn);
    $essn     = $model->dbh->quote($essn);
    $source   = $model->dbh->quote($source);
    $url      = $model->dbh->quote($url);
    $reviewed = $model->dbh->quote($reviewed);

    next if $seen{$short};

    $seen{$short} = 1;

    $model->dbh->do(
      "INSERT OR IGNORE INTO Journals (short, long, issn, essn, source, url, reviewed) VALUES ($short, $long, $issn, $essn, $source, $url, $reviewed);"
    );

    my $rowid = $model->dbh->func('last_insert_rowid');
    print STDERR "$rowid $short $long\n";
    $model->dbh->do("INSERT INTO Journals_lookup (rowid,short,long) VALUES ($rowid,$short,$long)");

  }

  $model->dbh->commit();

}

## Pack everything in directory for distribution

sub make_dist {

  my ( $self, $platform, $build_number ) = @_;

  my ( $dist_dir, $cat_dir, $ti_dir ) = ( $self->dist_dir, $self->cat_dir, $self->ti_dir );

  my $sub_dir = $platform;

  if ($platform eq 'osx'){
    $ti_dir= "$ti_dir/osx/Contents";
    $sub_dir = "osx/Contents";
  } else {
    $ti_dir = "$ti_dir/$platform";
  }

  `rm -rf $dist_dir/$platform`;

  my @ignore = ();

  push @ignore, @{ $ignore{all} };
  push @ignore, @{ $ignore{$platform} };

  mkpath( catfile("$dist_dir/$sub_dir/catalyst") );

  my $list = $self->_get_list( $cat_dir, \@ignore );
  $self->_copy_list( $list, $cat_dir, "$sub_dir/catalyst" );

  $list = $self->_get_list( $ti_dir, \@ignore );
  $self->_copy_list( $list, $ti_dir, $sub_dir );

  symlink "catalyst/root", "$dist_dir/$sub_dir/Resources" || die("Could not create symlink $!");

  # Copy runtime directory explicitly for OSX (contains empty
  # directories and symlinks which get lost otherwise)
  if ($platform eq 'osx'){
    `rsync -r -a $ti_dir/runtime $dist_dir/$sub_dir`;
  }

  # Update configuration file for current build
  my $yaml   = "$dist_dir/$sub_dir/catalyst/conf/settings.yaml";
  my $config = LoadFile($yaml);

  $config->{app_settings}->{platform} = $platform;

  if ($build_number) {
    $config->{app_settings}->{build_number} = $build_number;
  }

  DumpFile( $yaml, $config );

}

## Concatenate/minify Javascript and CSS

sub minify {

  my $self = shift;

  my $cat_dir = $self->cat_dir;

  my $yui = $self->yui_jar;

  if ( not -e $yui ) {
    die("YUI compressor jar file not found. $yui does not exist");
  }

  my $data = LoadFile("$cat_dir/data/resources.yaml");

  my $all_css = "$cat_dir/root/css/all.css";

  unlink($all_css);

  foreach my $file ( @{ $data->{css} } ) {
    `cat $cat_dir/root/$file >> $all_css`;
  }

  my $all_js = "$cat_dir/root/js/all.js";

  unlink($all_js);

  foreach my $file ( @{ $data->{js} } ) {
    `cat $cat_dir/root/$file >> tmp.js`;
  }
  my @plugins = glob("$cat_dir/root/js/??port/plugins/*js");

  foreach my $file (@plugins) {
    `cat $file >> tmp.js`;
  }

  #`java -jar $yui tmp.js -o $all_js`;
  `cp tmp.js $all_js`;

  unlink('tmp.js');

}

## Concatenate/minify Javascript and CSS

sub dump_includes {

  my $self = shift;

  my $cat_dir = $self->cat_dir;

  my $data = LoadFile("$cat_dir/data/resources.yaml");

  foreach my $file ( @{ $data->{css} } ) {
    print '<link rel="stylesheet" type="text/css" charset="utf-8" href="/' . $file . '"></link>',
      "\n";
  }

  my $curr_dir = `pwd`;
  chomp($curr_dir);
  chdir "$cat_dir/root";
  my @plugins = glob("js/??port/plugins/*js");
  chdir $curr_dir;

  foreach my $file ( @{ $data->{js} }, @plugins ) {
    print '<script type="text/javascript" charset="utf-8" src="/' . $file . '"></script>', "\n";
  }

}

sub get_titanium {

  my ($self) = @_;

  my $version = Paperpile->config->{app_settings}->{titanium_version};

  my $tmp_dir = tempdir( CLEANUP => 1 );

  foreach my $platform ( 'linux32', 'linux64','osx' ) {

    my $dest_dir   = $self->ti_dir . "/$platform";

    my $file_name = "titanium-$version-$platform.tar.gz";
    my $url       = "http://paperpile.com/download/titanium/titanium-$version-$platform.tar.gz";

    $self->echo("Getting Titanium runtime version $version for $platform");

    if ( -e "$dest_dir/runtime/VERSION-$version" ) {
      $self->echo("Titanium runtime version $version already exists.");
      next;
    } else {
      if ( -e "$dest_dir/runtime" ) {
        $self->echo("Deleting old version of Titanium runtime.");
        `rm -rf $dest_dir/runtime $dest_dir/modules $dest_dir/paperpile`;
      }
    }

    # Short-cut to pack and test locally
    my $file = "/Users/wash/tmp/pack/" . $file_name;

    if ( !-e $file ) {
      $self->echo("Downloading runtime.");
      `wget -P $tmp_dir $url`;

      if ( !-e "$tmp_dir/$file_name" ) {
        $self->echo("Could not download runtime for $platform.");
        next;
      }

    } else {
      `cp $file $tmp_dir`;
    }

    `tar -C $tmp_dir -xzf $tmp_dir/$file_name`;

    if ($platform =~/linux/){
      `mv $tmp_dir/titanium-$version-$platform/* $dest_dir`;
    }

    if ($platform eq 'osx'){
      `mv $tmp_dir/titanium-$version-$platform/runtime $dest_dir/Contents`;
      `mv $tmp_dir/titanium-$version-$platform/modules $dest_dir/Contents`;
      `mv $tmp_dir/titanium-$version-$platform/paperpile $dest_dir/Contents/MacOS`;
    }

  }

}

sub create_patch {

  my ( $self, $old_dir, $new_dir, $patch_dir ) = @_;

  my ( @listing, @modified );
  File::DirCompare->compare(
    $old_dir, $new_dir,
    sub {
      my ( $a, $b ) = @_;

      my ( $a_rel, $b_rel );

      if ($a) {
        $a_rel = $a;
        $a_rel =~ s/$old_dir\///;
      }

      if ($b) {
        $b_rel = $b;
        $b_rel =~ s/$new_dir\///;
      }

      if ( !$b ) {
        push @listing, "D   $a_rel";
      } elsif ( !$a ) {
        rcopy( $b, "$patch_dir/$b_rel" );
        push @listing, "A   $b_rel";
      } else {
        if ( -f $a && -f $b ) {
          push @listing, "M   $b_rel";
          rcopy( $b, "$patch_dir/$b_rel" );
        } else {

          # One file, one directory - treat as delete + add
          push @listing, "D   $a_rel";
          push @listing, "A   $b_rel";
        }
      }
    }
  );

  open( DIFF, ">$patch_dir/__DIFF__" );

  foreach my $line (@listing) {
    print DIFF "$line\n";
  }

}

sub file_stats {

  my ( $self, $file ) = @_;

  open( ZIP, $file ) or die "Can't open $file ($!)";

  my $c = Digest::MD5->new;

  $c->addfile(*ZIP);

  close(ZIP);

  return {
    size => stat($file)->size,
    md5  => $c->hexdigest,
  };

}

sub _get_list {

  my ( $self, $source_dir, $ignore ) = @_;

  my @list = ();

  find( {
      no_chdir => 1,
      wanted   => sub {
        my $name = $File::Find::name;

        # Skip symlinks in Titanium runtime of OSX
        return if ($name =~/Versions\/Current/);

        return if -d $name;
        foreach my $r (@$ignore) {
          return if $name =~ $r;
        }
        push @list, File::Spec->abs2rel( $name, $source_dir );
        }
    },
    $source_dir
  );

  return \@list;

}

sub _copy_list {
  my ( $self, $list, $source_dir, $prefix ) = @_;
  foreach my $file (@$list) {
    fcopy( catfile( $source_dir, $file ), catfile( $self->dist_dir, $prefix, $file ) )
      or die( $!, $file );
  }
}

