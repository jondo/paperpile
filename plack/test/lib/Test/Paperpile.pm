package Test::Paperpile;

use strict;

use Test::More;
use Test::Exception;

use Data::Dumper;
use YAML;
use File::Path;
use File::Copy::Recursive;
use Plack::Test;
use HTTP::Request::Common;
use Encode qw(encode decode);

use Paperpile::App;

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

sub workspace {

  my ($self) = @_;

  return(Paperpile->path_to("test","workspace"));

}

sub setup_workspace {

  my ($self) = @_;

  $self->clean_workspace;

  if (!$self->{app}){
    $self->init_app;
  }

  # Copy database file into workspace directory
  my $fixtures = Paperpile->path_to("test","data","Fixture","workspace");
  my $workspace = $self->workspace;

  File::Copy::Recursive::fcopy("$fixtures/paperpile.ppl", "$workspace/.paperpile/paperpile.ppl") || die($!);
  File::Copy::Recursive::fcopy("$fixtures/settings.db", "$workspace/.paperpile/settings.db") || die($!);

  # Update paths in databases
  my $dbh = DBI->connect("dbi:SQLite:$workspace/.paperpile/settings.db");
  my $library = $dbh->quote("$workspace/.paperpile/paperpile.ppl");
  $dbh->do("UPDATE Settings SET value=$library WHERE key='library_db'");

  $dbh = DBI->connect("dbi:SQLite:$workspace/.paperpile/paperpile.ppl");
  my $paper_root = $dbh->quote("$workspace/.paperpile/papers");
  $dbh->do("UPDATE Settings SET value=$paper_root WHERE key='paper_root'");

  my $r = $self->request("/ajax/app/init_session");

}

sub clean_workspace {

  my ($self) = @_;

  rmtree( $self->workspace );
  mkpath( $self->workspace );

}

sub row_ok {

  my ($self, $dbh, $table, $where, $test, $comment) = @_;

  my $results = $dbh->selectrow_hashref("SELECT * FROM $table WHERE $where;");

  foreach my $key (keys %$test){

    my $expected = $test->{$key};

    my $action = 'IS';
    if ($key=~s/_(IS|LIKE|DEFINED|UNDEFINED)$//){
      $action = $1;
    }

    my $observed = $results->{$key};

    my $string = '';
    $string = "$comment: " if $comment;

    ## encode utf8 output because Test::More output cannot easily be
    ## set to utf-8.
    my $forprint = $expected;
    utf8::encode($forprint);

    if ($action eq 'IS'){
      is($observed, $expected, "$string$key = ".$forprint);
    }

    if ($action eq 'LIKE'){
      like($observed, qr{$expected}, "$string$key matches pattern");
    }

    if ($action eq 'DEFINED'){
      ok($observed, "$string$key: is defined");
    }

    if ($action eq 'UNDEFINED'){
      ok(!$observed, "$string$key: is not defined");
    }
  }

  return $results;

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

    if ($key eq 'folders_tmp'){
      ok(1,"SKIPPING test until folders_tmp is implemented.");
      next;
    }

    my $action = 'IS';

    my $expected = $data->{$key};

    $key =~s/_(IS|LIKE|DEFINED|UNDEFINED)$//;

    if ($key=~s/_(IS|LIKE|DEFINED|UNDEFINED)$//){
      $action = $1;
    }

    my $observed = $pub->$key;

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
