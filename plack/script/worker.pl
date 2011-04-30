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
use Data::Dumper;

use Paperpile;
use Paperpile::App;
use Paperpile::Utils;
use Paperpile::Queue;
use Paperpile::Job;


my $id = $ARGV[0];

my $tmp = File::Spec->catfile(Paperpile::Utils->get_tmp_dir, "worker_$id.log");

close(STDOUT);
open(STDERR,">$tmp");

my $job = Paperpile::Job->new(id => $id);


my $start_time = time;
$job->start($start_time);

$job->update_status('RUNNING');

eval { $job->_do_work; };

my $end_time = time;

if ($@) {
  $job->_catch_error;
} else {
  $job->duration( $end_time - $start_time );
  $job->update_status('DONE');
}

if ($job->queued){
  my $q = Paperpile::Queue->new();
  $q->run;
}

exit(0);
