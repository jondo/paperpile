# Copyright (c) 1998-2005 by Jonathan Swartz. All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

#
# Miscellaneous Mason-related utilities expected to be used by
# external applications.
#

package HTML::Mason::Utils;

use HTML::Mason::Tools qw(compress_path);
use strict;
use warnings;

require Exporter;

use vars qw(@ISA @EXPORT_OK);

@ISA = qw(Exporter);
@EXPORT_OK = qw(data_cache_namespace cgi_request_args);

sub data_cache_namespace
{
    my ($comp_id) = @_;
    return compress_path($comp_id);
}

sub cgi_request_args
{
    my ($q, $method) = @_;

    my %args;

    # Checking that there really is no query string when the method is
    # not POST is important because otherwise ->url_param returns a
    # parameter named 'keywords' with a value of () (empty array).
    # This is apparently a feature related to <ISINDEX> queries or
    # something (see the CGI.pm) docs.  It makes my head hurt. - dave
    my @methods =
        $method ne 'POST' || ! $ENV{QUERY_STRING} ? ( 'param' ) : ( 'param', 'url_param' );

    foreach my $key ( map { $q->$_() } @methods ) {
        next if exists $args{$key};
        my @values = map { $q->$_($key) } @methods;
        $args{$key} = @values == 1 ? $values[0] : \@values;
    }

    return wantarray ? %args : \%args;
}


1;

__END__

=head1 NAME

HTML::Mason::Utils - Publicly available functions useful outside of Mason

=head1 DESCRIPTION

The functions in this module are useful when you need to interface
code you have written with Mason.

=head1 FUNCTIONS

=over 4

=item data_cache_namespace ($comp_id)

Given a component id, this method returns its default
C<Cache::Cache> namespace.  This can be useful if you want to access
the cached data outside of Mason.

With a single component root, the component id is just the component
path. With multiple component roots, the component id is
C<key>/C<path>, where C<key> is the key corresponding to the root that
the component falls under.

=item cgi_request_args ($cgi, $method)

This function expects to receive a C<CGI.pm> object and the request
method (GET, POST, etc).  Given these two things, it will return a
hash in list context or a hashref in scalar context.  The hash(ref)
will contain all the arguments passed via the CGI request.  The keys
will be argument names and the values will be either scalars or array
references.

=back

=cut

