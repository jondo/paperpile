package Test::Paperpile::Controller::Ajax::App;

use strict;
use Test::More;
use Plack::Test;
use Data::Dumper;
use HTTP::Request::Common;
use File::Path;

use Paperpile;
use Paperpile::App;

use base 'Test::Paperpile::Controller::Ajax';

sub class { 'Paperpile::Controller::Ajax::App' }

sub startup : Test(startup => 1) {
  my ($self) = @_;

  $self->SUPER::startup();

  use_ok $self->class;

  # Clean workspace
  if ( !$self->{workspace} =~ m!test/workspace! ) {
    die( "Something wrong with test workspace. I don't delete " . $self->{workspace} );
  } else {
    rmtree( $self->{workspace} );
  }

}

sub init_session : Tests(10){

  my ($self) = @_;

  my $r = $self->request("/ajax/app/init_session", 'application/json','200');

  my $workspace = $self->{workspace};
  my $tmp_dir = Paperpile->tmp_dir;

  foreach my $dir ( 'rss', 'import', 'download', 'jobs', 'json', 'filesync' ){
    ok(-d "$tmp_dir/$dir", "Subfolder '$dir' exists in temporary folder.");
  }

  ok(-e "$workspace/paperpile.ppl", "Library database exists.");
  ok(-e "$workspace/settings.db", "User settings database exists.");

}

1;
