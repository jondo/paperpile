# Copyright (c) 1998-2005 by Jonathan Swartz. All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

package HTML::Mason::Cache::BaseCache;
use strict;
use warnings;

#
# Override to handle busy_lock and expire_if.
#
sub get
{
    my ($self, $key, %params) = @_;
    die "must specify key" unless defined($key);

    foreach my $param (keys(%params)) {
        unless ($param =~ /^(busy_lock|expire_if)$/) {
            die "unknown param '$param'";
        }
    }

    $self->_conditionally_auto_purge_on_get();

    if (my $sub = $params{expire_if}) {
        $self->expire_if($key, $sub);
    }

    my $object = $self->get_object($key) or
        return undef;

    if (Cache::BaseCache::Object_Has_Expired($object))
    {
        if ($params{busy_lock}) {
            # If busy_lock value provided, set a new "temporary"
            # expiration time that many seconds forward, and return
            # undef so that this process will start recomputing.
            my $busy_lock_time = Cache::BaseCache::Canonicalize_Expiration_Time($params{busy_lock});
            $object->set_expires_at(time + $busy_lock_time);
            $self->set_object($key, $object);
        } else {
            $self->remove($key);
        }
        return undef;
    }

    return $object->get_data( );
}

sub expire
{
    my ($self, $key) = @_;

    if (my $obj = $self->get_object($key)) {
        $obj->set_expires_at(time-1);
        $self->set_object($key, $obj);
    }
}

sub expire_if
{
    my ($self, $key, $sub) = @_;
    die "must specify subroutine" unless defined($sub) and ref($sub) eq 'CODE';

    if (my $obj = $self->get_object($key)) {
        my $retval = $sub->($obj);
        if ($retval) {
            $self->expire($key);
        }
        return $retval;
    } else {
        return 1;
    }
}


1;

__END__

=head1 NAME

HTML::Mason::Cache::BaseCache - Base cache object

=head1 DESCRIPTION

This is the base module for all cache implementations used in Mason.
It provides a few additional methods on top of C<Cache::BaseCache> in
Dewitt Clinton's C<Cache::Cache> package.

An object of this class is returned from L<$m-E<gt>cache|HTML::Mason::Request/item_cache>.

=head1 METHODS

=over

=item clear ()

=for html <a name="item_clear"></a>

Remove all values in the cache.

=item get (key, [%params])

=for html <a name="item_get"></a>

Returns the value associated with I<key> or undef if it is
non-existent or expired. This is extended with the following optional
name/value parameters:

=over

=item busy_lock => duration

If the value has expired, set its expiration time to the current time plus
I<duration> (instead of removing it from the cache) before returning undef.
This is used to prevent multiple processes from recomputing the same
expensive value simultaneously. The I<duration> may be of any form acceptable
to L<set|HTML::Mason::Cache::BaseCache/item_set>.

=item expire_if => sub

If the value exists and has not expired, call I<sub> with the cache
object as a single parameter. If I<sub> returns a true value, expire
the value.

=back

=item get_object (key)

=for html <a name="item_get_object"></a>

Returns the underlying C<Cache::Object> object associated with I<key>.
The most useful methods on this object are

    $co->get_created_at();    # when was object stored in cache
    $co->get_accessed_at();   # when was object last accessed
    $co->get_expires_at();    # when does object expire

=item expire (key)

=for html <a name="item_expire"></a>

Expires the value associated with I<key>, if it exists. Differs from
L<remove|HTML::Mason::Cache::BaseCache/item_remove> only in that
the cache object is left around, e.g. for retrieval by
L<get_object|HTML::Mason::Cache::BaseCache/item_get_object>.

=item remove (key)

=for html <a name="item_remove"></a>

Removes the cache object associated with I<key>, if it exists.

=item set (key, data, [duration])

=for html <a name="item_set"></a>

Associates I<data> with I<key> in the cache. I<duration>
indicates the time until the value should be erased.  If
I<duration> is unspecified, the value will never expire
by time.

I<$expires_in> may be a simple number of seconds, or a string of the
form "[number] [unit]", e.g., "10 minutes".  The valid units are s,
second, seconds, sec, m, minute, minutes, min, h, hour, hours, d, day,
days, w, week, weeks, M, month, months, y, year, and years.

=back

=cut
