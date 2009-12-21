## run with the right perl binary!

use strict;
use YAML qw(LoadFile);
use Data::Dumper;
use LWP;

my $file ='../conf/update.yaml';

my $data = LoadFile($file);

print Dumper($data);


