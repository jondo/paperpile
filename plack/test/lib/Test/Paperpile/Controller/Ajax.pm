package Test::Paperpile::Controller::Ajax;

use strict;
use Test::More;
use Plack::Test;
use Data::Dumper;
use HTTP::Request::Common;

use Paperpile;
use Paperpile::App;

use base 'Test::Paperpile';

sub startup : Test(startup) {
  my ($self) = @_;

  my $a = Paperpile::App->new();
  $a->startup();

  my $app = sub {
    return $a->app(shift);
  };

  $self->{app} = $app;

  $self->{workspace} = Paperpile->config->{paperpile_user_dir};

}

# Requests $path from Plack application. Returns HTTP::Response
# object. If $content_type and $code are given two tests are added to
# check for the given values.
sub request {

  my ( $self, $path, $content_type, $code ) = @_;

  my $res;

  test_psgi $self->{app}, sub {
    my $cb = shift;
    $res = $cb->( GET $path);
  };

  if ($content_type && $code){
    is($res->code, $code, "Request $path: got 200");
    is($res->header('Content-type'), $content_type, "Request $path: content type is $content_type");
  }

  return $res;
}



1;
