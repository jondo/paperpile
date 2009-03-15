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

  my @filetypes=qw/pdf ai txt bmp cgm dcm dds exr gif hdr ico jng jp2 jpeg jpg pbm pbmraw
                 pcd pcx pgm pgmraw pic png pnm psd raw rgb rgba tga tif tiff xbm xcf
                 xpm conf vim html htm sgml xhtml xml 3g2 3gp asf asx avi flc fli flv
                 mkv mng mp4 mpeg mpg ogm rv wmp wmv ttf otf exe dll doc odt rtf xls
                 ods xlc xll xlm xlw wpd abw js css php 7z a ace arj bz bz2 cpio gz rar
                 tgz tnf z zip zoo ppt odp ppz ppt msg dwg sxd dhw svg ps eps wmf fig
                 msod qpic ics chm info hlp help aac ac3 aifc aiff ape au flac m3u m4a
                 mac mid midi mp2 mp3 ogg psid ra ram sf sid spx wav wma wv wvc asc cer
                 cert crt der gpg gpg p10 p12 p7c p7m p7s pem sig bin cue img iso mdf nrg
                 jar java class sql moov mov qt/;

  my $mode=$c->request->params->{selectionMode};
  my $root = File::Spec->rootdir();
  my $path=$c->request->params->{path};
  $path=~s/^ROOT/$root/;

  my @contents=();

  my $failure= { "success" => \0, "error" => "Could not read directory." };

  opendir(DIR, File::Spec->catdir($root,$path)) || return $failure;

  @contents = readdir(DIR);

  closedir DIR;

  my @output=();

  foreach my $item (@contents){

    # How can we recognize hidden files under windows?
    if ($c->request->params->{showHidden} eq 'false'){
      next if $item=~/^\./;
    }

    next if $item eq '.';
    next if $item eq '..';

    if (-d File::Spec->catdir($path,$item)){
      push @output, {text=>$item,
                     iconCls=>"folder",
                     disabled=>\0,
                     leaf=>\0};
    } else {
      if ($mode eq 'FILE' or $mode eq 'BOTH'){

        my ($dummy,$dummy2,$suffix) = fileparse($item,qr/\.[^.]*/);

        $suffix=~s/\.//;

        my $iconCls="file";

        if ($suffix ~~ [@filetypes]){
          $iconCls="file-$suffix";
        }

        push @output, {text=>$item,
                       iconCls=>$iconCls,
                       disabled=>\0,
                       leaf=>\1};
      }
    }

  }

  return [@output];

}

sub newdir : Local {
  my ( $self, $c ) = @_;

  my $root = File::Spec->rootdir();
  my $dir  = $c->request->params->{dir};
  $dir =~ s/^ROOT/$root/;

  eval { mkpath($dir); };

  if ($@) {
    return { "success" => \0, "error" => "Could not create directory." };
  } else {
    return { success => \1 };
  }

}



1;
