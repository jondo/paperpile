# Copyright (c) 1998-2005 by Jonathan Swartz. All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

#
# A library of escape subroutines to be used for substitution escaping
#

package HTML::Mason::Escapes;

use strict;
use warnings;

use HTML::Entities ();


my %html_escape = ('&' => '&amp;', '>'=>'&gt;', '<'=>'&lt;', '"'=>'&quot;');
my $html_escape = qr/([&<>"])/;

sub basic_html_escape
{
    return unless defined ${ $_[0] };

    ${ $_[0] } =~ s/$html_escape/$html_escape{$1}/mg;
}

sub html_entities_escape
{
    return unless defined ${ $_[0] };

    HTML::Entities::encode_entities( ${ $_[0] } );
}

sub url_escape
{
    return unless defined ${ $_[0] };

    use bytes;
    ${ $_[0] } =~ s/([^a-zA-Z0-9_.-])/uc sprintf("%%%02x",ord($1))/eg;
}


1;

__END__

=head1 NAME

HTML::Mason::Escapes - Functions to escape text for Mason

=head1 DESCRIPTION

This module contains functions for implementing Mason's L<substitution
escaping|HTML::Mason::Devel/Escaping expressions> feature.  These
functions may also be called directly.

=over 4

=item html_entities_escape

This function takes a scalar reference and HTML-escapes it using the
C<HTML::Entities> module.  By default, this module assumes that the
string it is escaping is in ISO-8859-1 (pre Perl 5.8.0) or UTF-8 (Perl
5.8.0 onwards).  If this is not the case for your data, you will want
to override this escape to do the right thing for your encoding.  See
the section on L<User-defined Escapes in the Developer's
Manual|HTML::Mason::Devel/User-defined Escapes> for more details on
how to do this.

=item url_escape

This takes a scalar reference and replaces any text it contains
matching C<[^a-zA-Z0-9_.-]> with the URL-escaped equivalent, a percent
sign (%) followed by the hexadecimal number of that character.

=item basic_html_escape

This function takes a scalar reference and HTML-escapes it, escaping
the following characters: '&', '>', '<', and '"'.

It is provided for those who wish to use it to replace (or supplement)
the existing 'h' escape flag, via the Interpreter's L<C<set_escape()>
method|HTML::Mason::Interp/item_set_escape>.

This function is provided in order to allow people to return the HTML
escaping behavior in 1.0x.  However, this behavior presents a
potential security risk of allowing cross-site scripting attacks.
HTML escaping should always be done based on the character set a page
is in.  Merely escaping the four characters mentioned above is not
sufficient.  The quick summary of why is that for some character sets,
characters other than '<' may be interpreted as a "less than" sign,
meaning that just filtering '<' and '>' will not stop all cross-site
scripting attacks.  See
http://www.megasecurity.org/Info/cross-site_scripting.txt for more
details.

=back

=cut
