package Catalyst::Plugin::Unicode;

use strict;

use MRO::Compat;

our $VERSION = '0.91';

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

Catalyst::Plugin::Unicode - Unicode aware Catalyst

=head1 SYNOPSIS

    use Catalyst qw[Unicode];


=head1 DESCRIPTION

On request, decodes all params from UTF-8 octets into a sequence of 
logical characters. On response, encodes body into UTF-8 octets.

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

=head1 LICENSE

This library is free software . You can redistribute it and/or modify 
it under the same terms as perl itself.

=cut
