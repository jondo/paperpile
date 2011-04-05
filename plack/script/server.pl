# Copyright 2009-2011 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public License for more details.  You should have
# received a copy of the GNU Affero General Public License along with
# Paperpile.  If not, see http://www.gnu.org/licenses.

use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Plack::Runner;
use Paperpile::App;
use Data::Dumper;

use Plack::Middleware::Static;

my $paperpile = new Paperpile::App->new();

$paperpile->startup();

my $root = Paperpile->home_dir() . "/root/";

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

print STDERR "Starting Paperpile server at 127.0.0.1:3210...\n";

$runner->run;
