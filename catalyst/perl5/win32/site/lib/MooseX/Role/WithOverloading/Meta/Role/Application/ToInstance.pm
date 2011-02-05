package MooseX::Role::WithOverloading::Meta::Role::Application::ToInstance;
BEGIN {
  $MooseX::Role::WithOverloading::Meta::Role::Application::ToInstance::AUTHORITY = 'cpan:FLORA';
}
BEGIN {
  $MooseX::Role::WithOverloading::Meta::Role::Application::ToInstance::VERSION = '0.09';
}
# ABSTRACT: Roles which support overloading

use Moose::Role;
use namespace::autoclean;

with qw(
    MooseX::Role::WithOverloading::Meta::Role::Application
    MooseX::Role::WithOverloading::Meta::Role::Application::FixOverloadedRefs
);

1;

__END__
=pod

=encoding utf-8

=head1 NAME

MooseX::Role::WithOverloading::Meta::Role::Application::ToInstance - Roles which support overloading

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

