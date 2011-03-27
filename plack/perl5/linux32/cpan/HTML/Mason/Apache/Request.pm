# -*- cperl-indent-level: 4; cperl-continued-brace-offset: -4; cperl-continued-statement-offset: 4 -*-

# Copyright (c) 1998-2005 by Jonathan Swartz. All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

package HTML::Mason::Apache::Request;

use strict;
use warnings;

use base 'Apache::Request';


sub new
{
    my $class = shift;
    my $r     = Apache::Request->instance(shift);

    return bless { r => $r }, $class;
}

sub send_http_header
{
    my $self = shift;

    return if $self->notes('sent_http_header');

    $self->SUPER::send_http_header(@_);

    $self->notes( 'sent_http_header' => 1 );
}


1;
