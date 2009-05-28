package Paperpile::Controller::Ajax::PdfExtract;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Paperpile::PdfExtract;
use Data::Dumper;
use 5.010;
use File::Find;
use File::Path;
use File::Compare;
use File::Basename;
use File::stat;
use MooseX::Timestamp;
use Paperpile::Plugins::Import;
use Paperpile::Plugins::Export;

sub grid : Local {

  my ( $self, $c ) = @_;

  my $root = $c->request->params->{root};

  my $data = [];

  my @list = ();

  find(
    sub {
      my $name = $File::Find::name;
      push @list, $name if $name =~ /\.pdf$/i;
    },
    $root
  );

  foreach my $file_name (@list) {

    my $pub = Paperpile::Library::Publication->new();

    ( my $basename ) = fileparse($file_name);

    push @$data, {
      file_name     => $file_name,
      file_basename => $basename,
      file_size     => stat($file_name)->size,
      status        => 'NEW',
      status_msg    => '',
      pub           => $pub,
      };
  }

  # Get all existing PDFs in database

  my %pdfs_in_db = ();

  my $paper_root = $c->model('User')->get_setting('paper_root');

  my $sth =
    $c->model('User')
    ->dbh->prepare("SELECT rowid,pdf,title,authors,doi FROM Publications WHERE pdf !='';");
  $sth->execute;

  while ( my $row = $sth->fetchrow_hashref() ) {
    my $file = File::Spec->catfile( $paper_root, $row->{pdf} );

    my $s = stat($file);

    if ($s) {
      $pdfs_in_db{ $s->size } = {
        rowid   => $row->{rowid},
        file    => $file,
        authors => $row->{authors},
        title   => $row->{title},
        doi     => $row->{doi}
      };
    }
  }

  my @output = ();

  foreach my $item (@$data) {

    my $in_db = $pdfs_in_db{ $item->{file_size} };

    if ($in_db) {

      if ( compare( $in_db->{file}, $item->{file_name} ) == 0 ) {
        $item->{status}     = 'IMPORTED';
        $item->{status_msg} = '<b>'.$item->{file_basename}.'</b> already in database';
        $item->{pub}->authors( $in_db->{authors} );
        $item->{pub}->title( $in_db->{title} );
        $item->{pub}->doi( $in_db->{doi} );
      }
    }

    my $tmp = $item->{pub}->as_hash;
    foreach my $key ( 'file_name', 'file_basename', 'file_size', 'status', 'status_msg' ) {
      $tmp->{$key} = $item->{$key};
    }
    push @output, $tmp;
  }

  my @fields = ();

  foreach my $key ( keys %{ Paperpile::Library::Publication->new()->as_hash } ) {
    push @fields, { name => $key };
  }
  push @fields, 'file_name', 'file_basename', 'file_size', 'status', 'status_msg';

  my %metaData = (
    root   => 'data',
    id     => 'file_name',
    fields => [@fields]
  );

  $c->stash->{data}     = [@output];
  $c->stash->{metaData} = {%metaData};
  $c->detach('Paperpile::View::JSON');

}

sub import : Local {

  my ( $self, $c ) = @_;

  my $file_name = $c->request->params->{file_name};
  ( my $file_basename ) = fileparse($file_name);

  my $bin = Paperpile::Utils->get_binary( 'pdftoxml', $c->model('App')->get_setting('platform') );

  my $pub = {};
  my $extract = Paperpile::PdfExtract->new( file => $file_name, pdftoxml => $bin );
  eval { $pub = $extract->parsePDF; };

  my $data = {
    file_name     => $file_name,
    file_basename => $file_basename
  };

  if ( !$pub->{doi} and !$pub->{title} ) {
    $data->{status}     = 'FAIL';
    $data->{status_msg} = 'Could not find title or doi in PDF.';
  } else {
    my $plugin = Paperpile::Plugins::Import::PubMed->new();

    eval { $pub = $plugin->match($pub); };

    if ($@) {
      $data->{status}     = 'FAIL';
      $data->{status_msg} = 'Could not find unique match in database.';
    } else {

      my $pub_in_db =
        $c->model('User')
        ->standard_search( 'sha1=' . $c->model('User')->dbh->quote( $pub->sha1 ), 0, 1 )->[0];

      if ( !$pub_in_db ) {
        $pub->created(timestamp);
        $pub->times_read(0);
        $pub->last_read(timestamp);
        $c->model('User')->create_pubs( [$pub] );
        $pub->_imported(1);

        my $imported = $c->model('User')->attach_file( $file_name, 1, $pub->_rowid, $pub );

        $data->{status_msg} = "Imported <b>$file_basename</b> as entry <b>" . $pub->citekey. "</b>";

      } else {

        if ( $pub_in_db->pdf ) {
          $data->{status_msg} = "<b>$file_basename</b> already exists in database (" . $pub_in_db->pdf . ")";
        } else {
          my $imported =
            $c->model('User')->attach_file( $file_name, 1, $pub_in_db->_rowid, $pub_in_db );
          $data->{status_msg} =
              "<b>$file_basename</b> assigned to citation <b>"
            . $pub_in_db->citekey
            . "</b> that was already in your database.";
        }
      }

      $data->{status} = 'IMPORTED';

    }
  }

  $data->{pub} = $pub;

  my $tmp = $data->{pub}->as_hash;
  foreach my $key ( 'file_name', 'file_basename', 'file_size', 'status', 'status_msg' ) {
    $tmp->{$key} = $data->{$key};
  }

  $c->stash->{data} = $tmp;

  $c->forward('Paperpile::View::JSON');

}




1;
