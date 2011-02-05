package MooseX::Role::WithOverloading::Meta::Role::Application::Composite;
BEGIN {
  $MooseX::Role::WithOverloading::Meta::Role::Application::Composite::AUTHORITY = 'cpan:FLORA';
}
BEGIN {
  $MooseX::Role::WithOverloading::Meta::Role::Application::Composite::VERSION = '0.09';
}
# ABSTRACT: Roles which support overloading

use Moose::Role;
use namespace::autoclean;

with 'MooseX::Role::WithOverloading::Meta::Role::Application';

around apply_overloading => sub {
    my ($next, $self, $composite, $other) = @_;
    for my $role (@{ $composite->get_roles }) {
        $self->$next($role, $other);
    }
};

1;

__END__
=pod

=encoding utf-8

=head1 NAME

MooseX::Role::WithOverloading::Meta::Role::Application::Composite - Roles which support overloading

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

