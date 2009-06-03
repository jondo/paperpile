package Catalyst::Devel;

use strict;
use warnings;

our $VERSION             = '1.17';
our $CATALYST_SCRIPT_GEN = 38;

$VERSION = eval $VERSION;

=head1 NAME

Catalyst::Devel - Catalyst Development Tools

=head1 DESCRIPTION

The C<Catalyst-Devel> distribution includes a variety of modules useful
for the development of Catalyst applications, but not required to run
them. This is intended to make it easier to deploy Catalyst apps. The
runtime parts of Catalyst are now known as C<Catalyst::Runtime>. 

C<Catalyst-Devel> includes the L<Catalyst::Helper> system, which
autogenerates scripts and tests; L<Module::Install::Catalyst>, a
L<Module::Install> extension for Catalyst; and requirements for a
variety of development-related modules. The documentation remains with
L<Catalyst::Runtime>.

=head1 SEE ALSO

L<Catalyst|Catalyst::Runtime>.

=head1 AUTHOR

Catalyst Contributors, see Catalyst.pm

=head1 PROJECT FOUNDER

sri: Sebastian Riedel <sri@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
