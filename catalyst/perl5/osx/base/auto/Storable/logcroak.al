# NOTE: Derived from blib/lib/Storable.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Storable;

#line 70 "blib/lib/Storable.pm (autosplit into blib/lib/auto/Storable/logcroak.al)"
#
# Use of Log::Agent is optional. If it hasn't imported these subs then
# Autoloader will kindly supply our fallback implementation.
#

sub logcroak {
    Carp::croak(@_);
}

# end of Storable::logcroak
1;
