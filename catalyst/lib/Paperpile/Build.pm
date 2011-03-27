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


package Paperpile::Build;
use Mouse;

use Paperpile::Model::User;
use Paperpile::Model::Library;
use Paperpile::Utils;
use Paperpile::App;

use Config;

use Data::Dumper;
use File::Path;
use File::Find;
use File::Spec::Functions qw(catfile);
use File::Copy::Recursive qw(fcopy dircopy rcopy);
use File::stat;
use File::Temp qw/tempdir /;
use Digest::MD5;
use Data::GUID;

use YAML qw(LoadFile DumpFile);

has cat_dir  => ( is => 'rw' );    # catalyst directory
has qt_dir   => ( is => 'rw' );    # qt directory
has qt_sdk   => ( is => 'rw' );    # qt sdk directory
has dist_dir => ( is => 'rw' );    # distribution directory
has yui_jar  => ( is => 'rw' );    #YUI compressor jar

# File patterns to ignore while packaging

my %ignore = (
  all => [
    qr([~#]),                qr{/tmp/},
    qr{catalyst/test/},      qr{\.gitignore},
    qr{(base|lib)/CORE/},    qr{(base|lib)/pods?/},
    qr{(base|lib|cpan)/CPAN},qr{(base|lib|cpan)/Test},
    qr{Devel/Cover},
    qr{(base|lib)/unicore/.*txt$},
    qr{ext/examples},       qr{ext/src},
    qr{journals.list},
    qr{ext-all\.js}, # we use the debug version of extjs for now
    qr{ext-all-debug-w-comments\.js},
    qr{bin/osx/.*sqlite.*},
    qr{PlugIns/codecs}, # Don't include JP/CN etc. unicode codecs for now
    qr{plugins/codecs},
    qr{PlugIns/imageformats/libqtiff.dylib},

  ],

  linux64 => [qr{/(perl5|bin)/(linux32|osx|win32)}],
  linux32 => [qr{/(perl5|bin)/(linux64|osx|win32)}],
  osx => [qr{/(perl5|bin)/(linux32|linux64|win32)}, qr{Contents/runtime}],
  win32 => [qr{/(perl5|bin)/(linux32|linux64|osx)}],
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

  if ( Paperpile::Utils->get_platform eq 'osx' ) {
    $ENV{PATH}              = "bin/osx:" . $ENV{PATH};
    $ENV{DYLD_LIBRARY_PATH} = "bin/osx";
  }

  foreach my $key ( 'app', 'user', 'library', 'queue' ) {
    $self->echo("Initializing db/$key.db...");
    unlink "db/$key.db";
    my @out = `sqlite3 db/$key.db < db/$key.sql;`;
    print @out;
  }

  my $model;
  if ( Paperpile::Utils->get_platform eq 'osx' ) {
    $model = Paperpile::Model::Library->new( { file => "db/library" } );
  } else {
    $model = Paperpile::Model::Library->new( { file => "db/library.db" } );
  }

  my $yaml   = "conf/fields.yaml";
  my $config = LoadFile($yaml);
  foreach my $field ( keys %{ $config->{pub_fields} } ) {
    $model->dbh->do("ALTER TABLE Publications ADD COLUMN $field TEXT");
  }

  foreach my $field ( 'created', 'journal', 'year', 'authors', 'attachments', 'pdf', 'annote' ) {
    $model->dbh->do("CREATE INDEX $field\_index ON Publications (trashed,$field);");
  }

  $model->dbh->do("CREATE INDEX guid_index ON Publications (guid);");

  $self->echo("Importing journal list into app.db...");

  open( JOURNALS, "<data/journals.list" );
  $model = Paperpile::Model::App->new( { file => "db/app.db" } );

  $model->dbh->begin_work();

  my %data = ();

  my %seen = ();

  my $counter = 0;
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

# We don't fill the main table for now because it is not in use but very big
#$model->dbh->do(
#  "INSERT OR IGNORE INTO Journals (short, long, issn, essn, source, url, reviewed) VALUES ($short, $long, $issn, $essn, $source, $url, $reviewed);"
#);

    #my $rowid = $model->dbh->func('last_insert_rowid');
    print STDERR "." if ( $counter % 100 == 0 );
    $model->dbh->do("INSERT INTO Journals_lookup (short,long) VALUES ($short,$long)");

    $counter++;

  }
  print STDERR "\n";

  $model->dbh->commit();

}

## Pack everything in directory for distribution

sub make_dist {

  my ( $self, $platform, $build_number ) = @_;

  my ( $dist_dir, $cat_dir, $qt_dir ) = ( $self->dist_dir, $self->cat_dir, $self->qt_dir );

  my $sub_dir = $platform;

  if ($platform eq 'osx'){
    $qt_dir= "$qt_dir/osx/Contents";
  } else {
    $qt_dir = "$qt_dir/$platform";
  }

  $self->echo("Cleaning up old builds.");

  `rm -rf $dist_dir/$platform`;

  my @ignore = ();

  push @ignore, @{ $ignore{all} };
  push @ignore, @{ $ignore{$platform} };

  $self->echo("Copying runtime files.");
  $sub_dir = 'osx/Contents' if ($platform eq 'osx');

  my $list = $self->_get_list( $qt_dir, \@ignore );
  $self->_copy_list( $list, $qt_dir, $sub_dir );


  $self->echo("Copying catalyst files.");
  $sub_dir = 'osx/Contents/Resources' if ($platform eq 'osx');

  mkpath( catfile("$dist_dir/$sub_dir/catalyst") );
  $list = $self->_get_list( $cat_dir, \@ignore );
  $self->_copy_list( $list, $cat_dir, "$sub_dir/catalyst" );

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

  my $data = LoadFile("$cat_dir/conf/resources.yaml");

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


sub dump_includes {

  my $self = shift;

  my $cat_dir = $self->cat_dir;

  my $data = LoadFile("$cat_dir/conf/resources.yaml");

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


sub create_patch {

  # Only need this on the packaging machine and we don't have to
  # bother installing it on other platforms like windows.
  require File::DirCompare;

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

# Downloads Qt Runtime libraries. If platform is given for a specific
# platform, if empty for the current platform. If platform is 'all'
# the libraries for all platforms are downloaded.

sub get_qruntime {

  my ($self,$platform) = @_;

  my $version = Paperpile::App->config->{app_settings}->{qruntime_version};

  my $tmp_dir = tempdir( CLEANUP => 1 );

  # Fix for msys environment on windows
  $tmp_dir=~s!\\!/!g;
  $tmp_dir=~s!^c:!/c/!ig;

  my @platforms;

  if ($platform){
    if ($platform eq 'all'){
      @platforms = ( 'linux32', 'linux64','osx','win32' );
    } else {
      @platforms = ($platform);
    }
  } else {
    @platforms = (Paperpile::Utils->get_platform);
  }


  foreach my $platform (@platforms) {

    my $dest_dir   = $self->qt_dir . "/$platform";

    my $file_name = "qruntime-$version-$platform.tar.gz";
    my $url       = "http://paperpile.com/download/qruntime/$file_name";

    $self->echo("Getting QRuntime version $version for $platform");

    if ($platform eq 'osx'){
      if ( -e "$dest_dir/Contents/Frameworks/QRUNTIME-$version" ) {
        $self->echo("QRuntime version $version already exists.");
        next;
      } else {
        if ( -e "$dest_dir/Contents/Frameworks" ) {
          $self->echo("Deleting old version of QRuntime runtime.");
          `rm -rf $dest_dir/Contents/Frameworks/* $dest_dir/Contents/PlugIns/*`;
        }
      }
    }

    if ($platform=~/linux(64|32)/){
      if ( -e "$dest_dir/lib/QRUNTIME-$version" ) {
        $self->echo("QRuntime version $version already exists.");
        next;
      } else {
        if ( -e "$dest_dir/lib" ) {
          $self->echo("Deleting old version of QRuntime runtime.");
          `rm -rf $dest_dir/lib/* $dest_dir/plugins/*`;
        }
      }
    }

    if ($platform eq 'win32'){
      if ( -e "$dest_dir/QRUNTIME-$version" ) {
        $self->echo("QRuntime version $version already exists.");
        next;
      } else {
        $self->echo("Deleting old version of QRuntime runtime.");
        `rm -rf $dest_dir/*dll $dest_dir/plugins/*`;
      }
    }


    # Short-cut to pack and test locally
    my $file='';
    #$file = "/Users/wash/tmp/pack/" . $file_name;
    #$file = "./$file_name";

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

    $self->echo("Extracting files.");

    `tar -C $tmp_dir -xzf $tmp_dir/$file_name`;

    $file_name=~s/\.tar\.gz//;

    $self->echo("Copying files.");

    if ($platform eq 'osx'){
      `mv $tmp_dir/$file_name/Contents/Frameworks/* $dest_dir/Contents/Frameworks`;
      `mv $tmp_dir/$file_name/Contents/PlugIns/* $dest_dir/Contents/PlugIns`;
    }

    if ($platform=~/linux(64|32)/){
      `mv $tmp_dir/$file_name/lib/* $dest_dir/lib`;
      `mv $tmp_dir/$file_name/plugins/* $dest_dir/plugins`;
    }

    if ($platform eq 'win32'){
      `mv $tmp_dir/$file_name/*dll $tmp_dir/$file_name/QRUNTIME* $dest_dir`;
      `mv $tmp_dir/$file_name/plugins/* $dest_dir/plugins`;
    }



  }
}



sub push_qruntime {

  my ( $self ) = @_;

  my $platform = Paperpile::Utils->get_platform;

  my $qruntime_version = Paperpile::App->config->{app_settings}->{qruntime_version};

  my $dest_dir = "qruntime-$qruntime_version-$platform";

  $self->echo("Creating $dest_dir...");

  `rm -rf $dest_dir` if (-e $dest_dir);
  mkdir $dest_dir;


  if ($platform eq 'osx'){

    my $contents = Paperpile::App->path_to("")."/../c/qruntime/paperpile.app/Contents";

    mkdir "$dest_dir/Contents";
    mkdir "$dest_dir/Contents/Frameworks";
    mkdir "$dest_dir/Contents/PlugIns";

    die("Frameworks not in Bundle. Run macdeployqt first.") if (!-e "$contents/Frameworks");

    $self->echo("Copying frameworks...");

    `cp -r $contents/Frameworks/* $dest_dir/Contents/Frameworks`;

    `touch $dest_dir/Contents/Frameworks/QRUNTIME-$qruntime_version`;

    $self->echo("Copying plugins...");

    foreach my $plugin ('codecs', 'imageformats'){
      `cp -r $contents/PlugIns/$plugin $dest_dir/Contents/PlugIns`;
    }
  }

  if ($platform=~/linux(64|32)/) {

    my $runtime = Paperpile::App->path_to("")."/../c/qruntime";

    mkdir "$dest_dir/lib";
    mkdir "$dest_dir/plugins";

    $self->echo("Copying libraries...");

    my @qt_libs = ('libQtCore.so.4','libQtDBus.so.4','libQtGui.so.4',
                   'libQtNetwork.so.4','libQtWebKit.so.4','libQtXml.so.4',
                   'libphonon.so.4'
                  );

    my $lib_dir = $self->qt_sdk."/lib";

    foreach my $lib (@qt_libs){
      `cp -r -L $lib_dir/$lib $dest_dir/lib`;
    }

    `touch $dest_dir/lib/QRUNTIME-$qruntime_version`;

    $self->echo("Copying plugins...");

    foreach my $plugin ('codecs', 'imageformats'){
      `cp -r $lib_dir/../qt/plugins/$plugin $dest_dir/plugins`;
    }
  }

  if ($platform eq 'win32') {

    mkdir "$dest_dir";
    mkdir "$dest_dir/plugins";

    $self->echo("Copying Qt libraries...");

    my @qt_libs = ('QtCore4.dll','QtGui4.dll',
                   'QtNetwork4.dll','QtWebKit4.dll','QtXml4.dll',
                   'phonon4.dll'
                  );

    my $lib_dir = $self->qt_sdk."/qt/bin";

    foreach my $lib (@qt_libs){
      `cp -r -L $lib_dir/$lib $dest_dir`;
    }

    `touch $dest_dir/QRUNTIME-$qruntime_version`;

    $self->echo("Copying Qt plugins...");

    foreach my $plugin ('codecs', 'imageformats'){
      `cp -r $lib_dir/../plugins/$plugin $dest_dir/plugins`;
      `rm -f $dest_dir/plugins/$plugin/*a`;
      `rm -f $dest_dir/plugins/$plugin/*d4.dll`;
    }

    $self->echo("Copying additional dlls...");

    # We need additional dlls, which need to be available locally in
    # the following hard-coded path. They have been downloaded
    # pre-compiled from: http://www.winkde.org/pub/kde/ports/win32

    my $local_lib_dir = '../../local/bin';

    my @local_libs = qw/libfreetype.dll libjpeg.dll
                        libopenjpeg.dll libpoppler-cpp.dll
                        libpoppler.dll libzlib1.dll libiconv.dll
                        liblcms-1.dll libpng14.dll libpoppler-qt4.dll
                        libxml2.dll/;

    foreach my $lib (@local_libs){
      `cp -r -L "$local_lib_dir/$lib" $dest_dir`;
    }
  }

  $self->echo("Packaging...");

  `tar czf $dest_dir.tar.gz $dest_dir`;

  $self->echo("Uploading (needs ssh keys so if you're not me it won't work...)");
  system("scp $dest_dir.tar.gz paperpile.com:/scratch/qruntime");

  $self->echo("Cleaning up");
  `rm -rf $dest_dir $dest_dir.tar.gz`;

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

