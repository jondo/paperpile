package Paperpile::Controller::Ajax::Attachments;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Utils;
use Paperpile::Library::Publication;
use Data::Dumper;
use File::Path;
use File::Spec;
use File::Copy;
use URI::file;

use File::stat;
use 5.010;

sub attach_file : Local {
  my ( $self, $c ) = @_;

  my $rowid  = $c->request->params->{rowid};
  my $file   = $c->request->params->{file};
  my $is_pdf = $c->request->params->{is_pdf};

  my $grid_id = $c->request->params->{grid_id};
  my $sha1    = $c->request->params->{sha1};
  my $plugin  = $c->session->{"grid_$grid_id"};

  my $pub      = $plugin->find_sha1($sha1);

  my $attached_file=$c->model('Library')->attach_file($file, $is_pdf, $rowid, $pub);

  if ($is_pdf){
    $c->stash->{pdf_file}=$attached_file;
  }

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub list_files : Local {
  my ( $self, $c ) = @_;

  my $rowid  = $c->request->params->{rowid};

  my $sth = $c->model('Library')->dbh->prepare("SELECT rowid, file_name FROM Attachments WHERE publication_id=$rowid;");
  my ( $attachment_rowid, $file_name );
  $sth->bind_columns( \$attachment_rowid, \$file_name );
  $sth->execute;

  my $paper_root=$c->model('Library')->get_setting('paper_root');

  my @output=();
  while ( $sth->fetch ) {

    my $abs=File::Spec->catfile( $paper_root, $file_name );

    my $link="/serve/$file_name";

    (my $suffix)=($link=~/\.(.*+$)/);


    my ($volume,$dirs,$base_name) = File::Spec->splitpath( $abs );

    push @output, {file=>$base_name,
                   path=>$abs,
                   link=>$link,
                   cls=>"file-$suffix",
                   rowid=> $attachment_rowid};

  }

  $c->stash->{list}=[@output];

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub delete_file : Local {
  my ( $self, $c ) = @_;

  my $rowid  = $c->request->params->{rowid};
  my $is_pdf = $c->request->params->{is_pdf};

  my $grid_id = $c->request->params->{grid_id};
  my $sha1    = $c->request->params->{sha1};
  my $plugin  = $c->session->{"grid_$grid_id"};

  $c->model('Library')->delete_attachment($rowid,$is_pdf);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}





1;
