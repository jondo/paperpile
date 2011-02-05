package Catalyst::Plugin::Unicode;

use strict;

use MRO::Compat;

our $VERSION = '0.93';

sub finalize {
    my $c = shift;

    if ( $c->response->{body} && utf8::is_utf8($c->response->{body}) ){
        utf8::encode( $c->response->{body} );
    }

    return $c->next::method(@_);
}

sub prepare_parameters {
    my $c = shift;

    $c->next::method(@_);

    for my $value ( values %{ $c->request->{parameters} } ) {

        if ( ref $value && ref $value ne 'ARRAY' ) {
            next;
        }

        utf8::decode($_) for ( ref($value) ? @{$value} : $value );
    }
}

1;

__END__

=head1 NAME

Catalyst::Plugin::Unicode - Unicode aware Catalyst (old style)

=head1 SYNOPSIS

    # DO NOT USE THIS - Use Catalyst::Plugin::Unicode::Encoding instead
    #                   which is both more correct, and handles more cases.
    use Catalyst qw[Unicode];

=head1 DESCRIPTION

On request, decodes all params from UTF-8 octets into a sequence of
logical characters. On response, encodes body into UTF-8 octets.

Note that this plugin tries to autodetect if your response is encoded into
characters before trying to encode it into a byte stream. This is B<bad>
as sometimes it can guess wrongly and cause problems.

As an example, latin1 characters such as é (e-accute) will not actually
cause the output to be encoded as utf8.

Using L<Catalyst::Plugin::Unicode::Encoding> is much more recommended,
and that also does additional things (like decoding file upload filenames
and request parameters which this plugin does not).

This plugin should be considered deprecated, but is maintained as a large
number of applications are using it already.

=head1 OVERLOADED METHODS

=over 4

=item finalize

Encodes body into UTF-8 octets.

=item prepare_parameters

Decodes parameters into a sequence of logical characters.

=back

=head1 SEE ALSO

L<utf8>, L<Catalyst>.

=head1 AUTHORS

Christian Hansen, C<< <ch@ngmedia.com> >>

Marcus Ramberg, C<< <mramberg@pcan.org> >>

Jonathan Rockway C<< <jrockway@cpan.org> >>

Tomas Doran, (t0m) C<< <bobtfish@bobtfish.net> >>

=head1 COPYRIGHT

Copyright (c) 2005 - 2009
the Catalyst::Plugin::Unicode L</AUTHORS>
as listed above.

=head1 LICENSE

This library is free software . You can redistribute it and/or modify
it under the same terms as perl itself.

=cut
