package # hide from PAUSE
    Package::Stash::Conflicts;

use strict;
use warnings;

use Dist::CheckConflicts
    -dist      => 'Package::Stash',
    -conflicts => {
        'Class::MOP' => '1.08',
        'MooseX::Role::WithOverloading' => '0.08',
        'namespace::clean' => '0.18',
    },
    -also => [ qw(
        Package::DeprecationManager
        Package::Stash::XS
        Scalar::Util
    ) ],
;

1;
