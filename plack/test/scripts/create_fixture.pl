#!../../perl5/linux64/bin/paperperl -w

use strict;
use lib "../../lib";

use Plack::Test;
use HTTP::Request::Common;
use Data::Dumper;

use Paperpile;
use Paperpile::App;
use Paperpile::Utils;
use Paperpile::Formats::Bibtex;

$ENV{PP_TESTING} = 1;

# Clean workspace
`rm -rf ../workspace/.paperpile`;

# Create mock instance of server
my $a = Paperpile::App->new();
$a->startup();

my $app = sub {
  return $a->app(shift);
};

my $res;

# Initialize settings and empty db in ../workspace
test_psgi $app, sub {
  my $cb = shift;
  $res = $cb->( GET "/ajax/app/init_session");
};

# Read data from Bibtex file
my $data =  Paperpile::Formats::Bibtex->new( file => "../data/Misc/diss.bib" )->read ;

# Insert data into database
my $model = Paperpile::Utils->get_model('Library');
$model->insert_pubs($data, 1);

# Copy files to fixture folder
`cp -r ../workspace/.paperpile/* ../data/Fixture/workspace`;
