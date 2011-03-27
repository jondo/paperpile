package Catalyst::Helper::View::Mason;

use strict;
use warnings;

our $VERSION = '0.13';

=head1 NAME

Catalyst::Helper::View::Mason - Helper for Mason Views

=head1 SYNOPSIS

    script/create.pl view Mason Mason

=head1 DESCRIPTION

Helper for Mason Views.

=head2 METHODS

=head3 mk_compclass

=cut

sub mk_compclass {
    my ($self, $helper) = @_;
    my $file = $helper->{file};
    $helper->render_file('compclass', $file);
}

=head1 SEE ALSO

L<Catalyst::Manual>, L<Catalyst::Test>, L<Catalyst::Request>,
L<Catalyst::Response>, L<Catalyst::Helper>

=head1 AUTHOR

Florian Ragwitz <rafl@debian.org>

Originally written by:

Andres Kievsky
Sebastian Riedel, C<sri@oook.de>

=head1 LICENSE

This library is free software . You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;

__DATA__

__compclass__
package [% class %];

use strict;
use warnings;

use parent 'Catalyst::View::Mason';

__PACKAGE__->config(use_match => 0);

=head1 NAME

[% class %] - Mason View Component for [% app %]

=head1 DESCRIPTION

Mason View Component for [% app %]

=head1 SEE ALSO

L<[% app %]>, L<HTML::Mason>

=head1 AUTHOR

[% author %]

=head1 LICENSE

This library is free software . You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
