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

use Paperpile::Plugins::Import;
use Paperpile::Plugins::Export;

sub grid : Local {

  my ( $self, $c ) = @_;

  my $grid_id = $c->request->params->{grid_id};
  my $root    = $c->request->params->{root};
  #my $task    = $c->request->params->{task};

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
      push @$data, { file_name => $rel, pub=>$pub };
    }

    #my $file_name = pop(@list);
    #my $bin = my $bin =

    $c->session->{"pdfextract_$grid_id"}=$data;

  } else {
    $data=$c->session->{"pdfextract_$grid_id"};
  }

  my @output=();

  foreach my $item (@$data) {
    my $tmp=$item->{pub}->as_hash;
    foreach my $key ('file_name'){
      $tmp->{$key}=$item->{$key};
    }
    push @output, $tmp;
  }

  my @fields = ();

  foreach my $key ( keys %{ Paperpile::Library::Publication->new()->as_hash } ) {
    push @fields, { name => $key };
  }
  push @fields, 'file_name';

  my %metaData = (
    root   => 'data',
    id     => 'file_name',
    fields => [@fields]
  );

  $c->stash->{data}     = [@output];
  $c->stash->{metaData} = {%metaData};
  $c->detach('Paperpile::View::JSON');

}

sub extract : Local {

  my ( $self, $c ) = @_;

  my $grid_id   = $c->request->params->{grid_id};
  my $file_name = $c->request->params->{file_name};
  my $root      = $c->request->params->{root};

  my $data = $c->session->{"pdfextract_$grid_id"};

  my $bin = Paperpile::Utils->get_binary( 'pdftoxml', $c->model('App')->get_setting('platform') );

  foreach my $item (@$data) {

    my $absolute = File::Spec->catfile( $root, $item->{file_name} );

    print STDERR "==>$absolute\n";

    my $extract = Paperpile::PdfExtract->new( file => $absolute, pdftoxml => $bin );
    my ( $title, $authors, $doi, $level );
    eval { ( $title, $authors, $doi, $level ) = $extract->parsePDF; };

    if ( !$@ ) {
      print STDERR "$title, $authors, $doi\n";
      $item->{pub}->title($title);
      $item->{pub}->_authors_display($authors);
      $item->{pub}->doi($doi);
    }
  }

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

1;
