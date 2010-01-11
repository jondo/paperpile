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
    $pub->pdf($attached_file);
  } else {
    $pub->attachments($pub->attachments + 1);
  }

  my $update = $self->_collect_data([$pub],['pdf','attachments','_attachments_list']);
  $c->stash->{data} = {pubs => $update};

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub list_files : Local {
  my ( $self, $c ) = @_;

  my $rowid  = $c->request->params->{rowid};
  my $sha1 = $c->request->params->{sha1};

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

  $c->stash->{pubs} = {};
  $c->stash->{pubs}->{$sha1} = {_attachments_list => [@output]};

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

  my $undo_path = $c->model('Library')->delete_attachment( $rowid, $is_pdf, 1 );

  $c->session->{"undo_delete_attachment"} = {
    file    => $undo_path,
    is_pdf  => $is_pdf,
    grid_id => $grid_id,
    sha1    => $sha1,
  };
  
  my $pub = $plugin->find_sha1($sha1);
  $pub->pdf('') if ($is_pdf);
  $pub->attachments($pub->attachments - 1) if (!$is_pdf);

  my $update = $self->_collect_data([$pub],['attachments','_attachments_list','pdf']);
  $c->stash->{data} = {pubs => $update};
  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub undo_delete : Local {
  my ( $self, $c ) = @_;

  my $undo_data=$c->session->{"undo_delete_attachment"};

  delete($c->session->{undo_delete_attachment});

  my $file   = $undo_data->{file};
  my $is_pdf = $undo_data->{is_pdf};

  my $grid_id = $undo_data->{grid_id};
  my $sha1    = $undo_data->{sha1};
  my $plugin  = $c->session->{"grid_$grid_id"};

  my $pub      = $plugin->find_sha1($sha1);

  my $attached_file=$c->model('Library')->attach_file($file, $is_pdf, $pub->_rowid, $pub);

  if ($is_pdf){
    $pub->pdf($attached_file);
  } else {
    $pub->attachments($pub->attachments + 1);
  }

  my $update = $self->_collect_data([$pub],['pdf','attachments','_attachments_list']);
  $c->stash->{data} = {pubs => $update};
  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}


sub _collect_data {
  my ( $self, $pubs, $fields ) = @_;

  $pubs = [$pubs] if (!ref $pubs eq 'ARRAY');

  my %output = ();
  foreach my $pub (@$pubs) {
    my $pub_fields = { };
    my $hash = $pub->as_hash;
    if ($fields) {
      map {$pub_fields->{$_} = $hash->{$_}} @$fields;
    } else {
      $pub_fields = $pub->as_hash;
    }
    $output{ $pub->sha1 } = $pub_fields;
  }
  
  return \%output;
}


1;
