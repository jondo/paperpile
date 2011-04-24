package Test::Paperpile;

use strict;

use Test::More;
use Data::Dumper;
use YAML;
use File::Path;
use File::Copy::Recursive;
use Plack::Test;
use HTTP::Request::Common;

use base 'Test::Class';

sub class { 'Paperpile' };

sub startup : Tests(startup => 0) {
  my ($self) = @_;

}

sub init_app {

  my ($self) = @_;

  my $a = Paperpile::App->new();
  $a->startup();

  my $app = sub {
    return $a->app(shift);
  };

  $self->{app} = $app;

}

sub setup_workspace {

  my ($self) = @_;

  $self->clean_workspace;

  if (!$self->{app}){
    $self->init_app;
  }

  my $fixtures = Paperpile->path_to("test","data","Fixture","workspace");
  my $workspace = Paperpile->path_to("test","workspace");

  File::Copy::Recursive::fcopy("$fixtures/paperpile.ppl", "$workspace/.paperpile/paperpile.ppl") || die($!);
  File::Copy::Recursive::fcopy("$fixtures/settings.db", "$workspace/.paperpile/settings.db") || die($!);

  my $r = $self->request("/ajax/app/init_session");

  $self->{workspace} = $workspace;

}

sub clean_workspace {

  my ($self) = @_;

  rmtree( Paperpile->path_to("test","workspace") );

}

sub row_ok {

  my ($self, $dbh, $table, $where, $test, $comment) = @_;

  my $results = $dbh->selectrow_hashref("SELECT * FROM $table WHERE $where;");

  foreach my $field (keys %$test){
    is($results->{$field}, $test->{$field}, "$comment: $field=".$results->{$field});
  }

}

sub row_count_ok {

  my ($self, $dbh, $table, $where, $test, $comment) = @_;

  (my $count) = $dbh->selectrow_array("SELECT COUNT(*) FROM $table WHERE $where;");

  is($count, $test, $comment);

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


# Compare $pub against fields in $data. The following suffixes can be
# used (default is "IS")

# field_IS        ... exact match
# field_LIKE      ... pattern match
# field_DEFINED   ... check if defined
# field_UNDEFINED ... check if undefined

# $msg is a prefix that is shown in the test message.

sub test_fields {

  my ($self, $pub, $data, $msg) = @_;

  foreach my $key (keys %$data){
    if ($key eq 'test_comment'){
      $msg.=" (".$data->{test_comment}.")";
      delete($data->{test_comment});
    }
  }

  foreach my $key (keys %$data){

    my $action = 'IS';

    my $expected = $data->{$key};

    $key =~s/_(IS|LIKE|DEFINED|UNDEFINED)$//;

    my $observed = $pub->$key;

    $action = $1 if $1;


    if ($key eq 'abstract'){
      $observed =~s/\s+/ /smg;
      $expected =~s/\s+/ /smg;
      $observed = chomp($observed);
      $expected = chomp($expected);
    }

    if ($action eq 'IS'){
      is($observed,$expected,"$msg: $key matches exactly");
    }

    if ($action eq 'LIKE'){
      like($observed, qr{$expected}, "$msg: $key matches pattern");
    }

    if ($action eq 'DEFINED'){
      ok($observed, "$msg: $key is defined");
    }

    if ($action eq 'UNDEFINED'){
      ok(!$observed, "$msg: $key is undefined");
    }
  }
}



1;
