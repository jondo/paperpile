use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Plack::Runner;
use Paperpile::App;
use Data::Dumper;

use Plack::Middleware::Static;

my $paperpile = new Paperpile::App->new();

$paperpile->startup();

my $root = $paperpile->home_dir() . "/root/";

my $app = sub {
  return $paperpile->app(shift);
};

$app = Plack::Middleware::Static->wrap( $app, path => qr{^/}, root => $root, pass_through => 1 );

my $runner = Plack::Runner->new(
  app          => $app,
  server       => 'Custom',        # Use custom server
  env          => 'deployment',    # Turn of various middlewares including AccessLog
);

$runner->parse_options(@ARGV);

print STDERR "Starting server at 127.0.0.1:3210...\n";

$runner->run;

