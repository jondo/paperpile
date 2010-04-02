# -*- cperl-indent-level: 4; cperl-continued-brace-offset: -4; cperl-continued-statement-offset: 4 -*-

# Copyright (c) 1998-2005 by Jonathan Swartz. All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

#
# ** Proposed virtual subclass for handler classes (e.g. ApacheHandler). Not in use yet.
# 

package HTML::Mason::Handler;

use strict;
use warnings;

use HTML::Mason::Exceptions ( abbr => [ qw( virtual_error ) ] );

use Class::Container;
use base qw(Class::Container);


sub handle_request
{
    my $self = shift;

    my $req = $self->prepare_request(@_);

    return ref $req ? $req->exec() : $req;
}

sub prepare_request
{
    virtual_error "The prepare_request method must be overridden in a handler subclass.";
}

sub request_args
{
    virtual_error "The request_args method must be overridden in a handler subclass.";
}


1;

__END__

