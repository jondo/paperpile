package Paperpile::Controller::Ajax::Files;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Data::Dumper;
use File::Spec;
use File::Path;
use File::Basename;

use 5.010;

sub dialogue : Local {
  my ( $self, $c ) = @_;

  my $output;

  if ($c->request->params->{cmd} eq 'get'){
    $output=$c->forward('get');
  }

  if ($c->request->params->{cmd} eq 'newdir'){
    $output=$c->forward('newdir');
  }

  $c->stash->{tree} = $output;

  $c->forward('Paperpile::View::JSON::Tree');

}

sub get : Local {
  my ( $self, $c ) = @_;

  my @filetypes = qw/pdf ai txt bmp cgm dcm dds exr gif hdr ico jng jp2 jpeg jpg pbm pbmraw
    pcd pcx pgm pgmraw pic png pnm psd raw rgb rgba tga tif tiff xbm xcf
    xpm conf vim html htm sgml xhtml xml 3g2 3gp asf asx avi flc fli flv
    mkv mng mp4 mpeg mpg ogm rv wmp wmv ttf otf exe dll doc odt rtf xls
    ods xlc xll xlm xlw wpd abw js css php 7z a ace arj bz bz2 cpio gz rar
    tgz tnf z zip zoo ppt odp ppz ppt msg dwg sxd dhw svg ps eps wmf fig
    msod qpic ics chm info hlp help aac ac3 aifc aiff ape au flac m3u m4a
    mac mid midi mp2 mp3 ogg psid ra ram sf sid spx wav wma wv wvc asc cer
    cert crt der gpg gpg p10 p12 p7c p7m p7s pem sig bin cue img iso mdf nrg
    jar java class sql moov mov qt/;

  my $mode = $c->request->params->{selectionMode};
  my $path = $c->request->params->{path};
  my $filter=$c->request->params->{filter};

  $path=Paperpile::Utils->adjust_root($path);

  my @filters=();
  if ($filter){
    # 'ALL' means showing all, i.e. no filter
    if ($filter eq 'ALL'){
      @filters=();
    } else {
      @filters=split(',',$filter);
    }
  }

  # Read directory content

  my $failure = { "success" => \0, "error" => "Could not read directory." };
  my @contents = ();
  opendir( DIR, $path ) || return $failure;
  @contents = readdir(DIR);
  closedir DIR;

  # Collect list of files/directories depending on options and filter

  my @dirs  = ();
  my @files = ();

  foreach my $item (@contents) {

    next if $item eq '.';
    next if $item eq '..';

    # How can we recognize hidden files under windows?
    if ( $c->request->params->{showHidden} eq 'false' ) {
      next if $item =~ /^\./;
    }

    # Entry is a directory
    if ( -d File::Spec->catdir( $path, $item ) ) {
      push @dirs, {
        text     => $item,
        iconCls  => "folder",
        disabled => \0,
        leaf     => \1,         # In the current front-end we just want
                                # a flat list for each dir, so we also
                                # set directories as leafs.
        type     => 'DIR',
      };
    }
    # Entry is a file
    else {
      if ( $mode eq 'FILE' or $mode eq 'BOTH' ) {

        # Get file suffix
        my ( $dummy, $dummy2, $suffix ) = fileparse( $item, qr/\.[^.]*/ );
        $suffix =~ s/\.//;
        $suffix=lc($suffix);

        # Skip if not in list of file-extensions given in filters
        if (@filters){
          my $is_ok=0;
          foreach my $s (@filters){
            print STDERR "$s vs $suffix\n";
            if ($suffix eq $s){
              $is_ok=1;
              last;
            }
          }
          next unless $is_ok;
        }

        # Assign css style depending on file-extension
        my $iconCls = "file";
        if ( $suffix ~~ [@filetypes] ) {
          $iconCls = "file-$suffix";
        }

        push @files, {
          text     => $item,
          iconCls  => $iconCls,
          disabled => \0,
          leaf     => \1,
          type     => 'FILE',
          };
      }
    }

  }

  @dirs  = sort { $a->{text} cmp $b->{text} } @dirs;
  @files = sort { $a->{text} cmp $b->{text} } @files;

  return [ @dirs, @files ];

}

sub newdir : Local {
  my ( $self, $c ) = @_;

  my $dir  = $c->request->params->{dir};

  $dir=Paperpile::Utils->adjust_root($dir);

  eval { mkpath($dir); };

  if ($@) {
    return { "success" => \0, "error" => "Could not create directory." };
  } else {
    return { success => \1 };
  }

}


sub stats : Local {
  my ( $self, $c ) = @_;

  my $location = $c->request->params->{location};
  $location=Paperpile::Utils->adjust_root($location);

  my %stats = ();

  $stats{exists}     = ( -e $location ) ? \1 : \0;
  $stats{dir}        = ( -d $location ) ? \1 : \0;
  $stats{readable}   = ( -r $location ) ? \1 : \0;
  $stats{writable}   = ( -w $location ) ? \1 : \0;
  $stats{executable} = ( -x $location ) ? \1 : \0;

  $c->stash->{stats} = {%stats};

  $c->forward('Paperpile::View::JSON');

}



1;
