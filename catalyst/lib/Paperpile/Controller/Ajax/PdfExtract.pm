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
use MooseX::Timestamp;
use Paperpile::Plugins::Import;
use Paperpile::Plugins::Export;

sub grid : Local {

  my ( $self, $c ) = @_;

  my $grid_id = $c->request->params->{grid_id};
  my $root    = $c->request->params->{root};

  my $data=[];

  if ( not defined $c->session->{"pdfextract_$grid_id"}){

    my @list = ();

    find(
      sub {
        my $name = $File::Find::name;
        push @list, $name if $name =~ /\.pdf$/i;
      },
      $root
    );

    foreach my $file_name (@list) {
      my $rel = File::Spec->abs2rel( $file_name, $root );
      my $pub= Paperpile::Library::Publication->new();
      push @$data, { file_name => $rel,
                     status => 'NEW',
                     status_msg => '',
                     pub => $pub,
                   };
    }

    $c->session->{"pdfextract_$grid_id"}=$data;

  } else {
    $data=$c->session->{"pdfextract_$grid_id"};
  }

  my @output=();

  foreach my $item (@$data) {
    my $tmp=$item->{pub}->as_hash;
    foreach my $key ('file_name', 'status', 'status_msg'){
      $tmp->{$key}=$item->{$key};
    }
    push @output, $tmp;
  }

  my @fields = ();

  foreach my $key ( keys %{ Paperpile::Library::Publication->new()->as_hash } ) {
    push @fields, { name => $key };
  }
  push @fields, 'file_name', 'status';

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

  my $grid_id   = $c->request->params->{grid_id};
  my $file_name = $c->request->params->{file_name};
  my $root  = $c->request->params->{root};

  my $data = $c->session->{"pdfextract_$grid_id"};

  my $bin = Paperpile::Utils->get_binary( 'pdftoxml', $c->model('App')->get_setting('platform') );

  my $item=undef;
  foreach my $t (@$data) {
    if ($t->{file_name} eq $file_name){
      $item=$t;
      last;
    }
  }

  my $absolute = File::Spec->catfile( $root, $item->{file_name} );

  my $pub={};
  my $extract = Paperpile::PdfExtract->new( file => $absolute, pdftoxml => $bin );
  eval { $pub = $extract->parsePDF;};

  if (!$pub->{doi} and !$pub->{title}){
    $item->{status}='FAIL';
    $item->{status_msg}='Could not find title or doi in PDF.';
  } else {
    my $plugin=Paperpile::Plugins::Import::PubMed->new();

    eval {
      $pub=$plugin->match($pub);
    };

    if ($@){
      $item->{status}='FAIL';
      $item->{status_msg}='Could not find unique match in database.';
    } else {

      if (!$c->model('User')->has_unique_entry('Publications', 'sha1', $pub->sha1 )){
        $pub->created(timestamp);
        $pub->times_read(0);
        $pub->last_read(timestamp);
        $c->model('User')->create_pubs([$pub]);
        $pub->_imported(1);
        $item->{status_msg}="Imported $file_name as entry ".$pub->citekey;
      } else {
        # Add here code to check if entry has PDF and attach if necessary
        $item->{status_msg}="$file_name already exists in database."
      }

      $item->{status}='IMPORTED';

    }

  }

  $item->{pub}=$pub;


  my $tmp=$item->{pub}->as_hash;
  foreach my $key ('file_name', 'status', 'status_msg'){
    $tmp->{$key}=$item->{$key};
  }

  $c->stash->{data}=$tmp;

  $c->forward('Paperpile::View::JSON');

}

1;
