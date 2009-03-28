package Paperpile::Controller::Ajax::CRUD;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Paperpile::Library::Publication;
use Data::Dumper;
use MooseX::Timestamp;
use 5.010;

sub insert_entry : Local {
  my ( $self, $c ) = @_;

  my $grid_id = $c->request->params->{grid_id};
  my $sha1      = $c->request->params->{sha1};
  my $plugin = $c->session->{"grid_$grid_id"};

  my $pub = $plugin->find_sha1($sha1);

  $pub->created(timestamp);
  $pub->times_read(0);
  $pub->last_read(timestamp); ## for the time being

  $c->model('User')->create_pub($pub);

  $pub->_imported(1);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub complete_entry : Local{

  my ( $self, $c ) = @_;
  my $grid_id = $c->request->params->{grid_id};
  my $sha1      = $c->request->params->{sha1};
  my $plugin = $c->session->{"grid_$grid_id"};

  my $pub = $plugin->find_sha1($sha1);
  $pub=$plugin->complete_details($pub);

  $c->stash->{data} = $pub->as_hash;

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub new_entry: Local {

  my ( $self, $c ) = @_;

  my %fields=();

  foreach my $key (%{$c->request->params}){
    next if $key=~/^_/;
    $fields{$key}=$c->request->params->{$key};
  }

  my $pub=Paperpile::Library::Publication->new({%fields});
  print STDERR Dumper($pub);

  $pub->created(timestamp);
  $pub->times_read(0);
  $pub->last_read(timestamp); ## for the time being

  $c->model('User')->create_pub($pub);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');



}


sub delete_entry : Local {
  my ( $self, $c ) = @_;

  my $grid_id = $c->request->params->{grid_id};
  my $rowid     = $c->request->params->{rowid};

  #my $source = $c->session->{"grid_$grid_id"};

  $c->model('User')->delete_pubs( [$rowid] );

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub update_entry : Local {
  my ( $self, $c ) = @_;

  my $grid_id = $c->request->params->{grid_id};
  my $rowid     = $c->request->params->{rowid};
  my $sha1      = $c->request->params->{sha1};

  # get old data
  my $plugin = $c->session->{"grid_$grid_id"};
  my $pub = $plugin->find_sha1($sha1);
  my $data=$pub->as_hash;

  # apply new values to old entry
  foreach my $field (keys %{$c->request->params}){
    next if $field=~/source_id/;
    $data->{$field}=$c->request->params->{$field};
  }

  my $newPub=Paperpile::Library::Publication->new($data);

  $c->model('User')->update_pub($newPub);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}


sub update_notes : Local {
  my ( $self, $c ) = @_;

  my $rowid     = $c->request->params->{rowid};
  my $sha1      = $c->request->params->{sha1};
  my $html      = $c->request->params->{html};


  $c->model('User')->update_field('Publications', $rowid, 'notes', $html);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub update_tags : Local {
  my ( $self, $c ) = @_;

  my $rowid     = $c->request->params->{rowid};
  my $sha1      = $c->request->params->{sha1};
  my $tags      = $c->request->params->{tags};

  $c->model('User')->update_tags($rowid, $tags);

  $c->stash->{success} = 'true';
  $c->forward('Paperpile::View::JSON');

}

sub generate_edit_form : Local {
  my ( $self, $c ) = @_;

  my $pub = Paperpile::Library::Publication->new();

  my $pubtype = $c->request->params->{pubtype};

  my %config=Paperpile::Utils::get_config;

  my @output=();

  foreach my $field (split(/\s+/,$config{pubtypes}->{$pubtype}->{all})){
    push @output, {name=>$field, fieldLabel=>$config{fields}->{$field}};
  }

  my $form=[@output];

  $c->stash->{form} = $form;

  $c->forward('Paperpile::View::JSON');

}


1;
