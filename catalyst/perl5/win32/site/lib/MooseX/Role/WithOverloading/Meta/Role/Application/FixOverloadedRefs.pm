package MooseX::Role::WithOverloading::Meta::Role::Application::FixOverloadedRefs;
BEGIN {
  $MooseX::Role::WithOverloading::Meta::Role::Application::FixOverloadedRefs::AUTHORITY = 'cpan:FLORA';
}
BEGIN {
  $MooseX::Role::WithOverloading::Meta::Role::Application::FixOverloadedRefs::VERSION = '0.09';
}
# ABSTRACT: Fix up magic when applying roles to instances with magic on old perls

use Moose::Role;
use namespace::autoclean;

if ($] < 5.008009) {
    after apply => sub {
        reset_amagic($_[2]);
    };
}


1;

__END__
=pod

=encoding utf-8

=head1 NAME

MooseX::Role::WithOverloading::Meta::Role::Application::FixOverloadedRefs - Fix up magic when applying roles to instances with magic on old perls

=for Pod::Coverage reset_amagic

=head1 AUTHORS

=over 4

=item *

Florian Ragwitz <rafl@debian.org>

=item *

Tomas Doran <bobtfish@bobtfish.net>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Florian Ragwitz.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

