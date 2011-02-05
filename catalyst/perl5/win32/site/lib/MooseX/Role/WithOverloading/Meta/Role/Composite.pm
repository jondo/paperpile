package MooseX::Role::WithOverloading::Meta::Role::Composite;
BEGIN {
  $MooseX::Role::WithOverloading::Meta::Role::Composite::AUTHORITY = 'cpan:FLORA';
}
BEGIN {
  $MooseX::Role::WithOverloading::Meta::Role::Composite::VERSION = '0.09';
}
# ABSTRACT: Role for composite roles which support overloading

use Moose::Role;
use Moose::Util::MetaRole;
use aliased 'MooseX::Role::WithOverloading::Meta::Role::Application::Composite::ToClass';
use aliased 'MooseX::Role::WithOverloading::Meta::Role::Application::Composite::ToRole';
use aliased 'MooseX::Role::WithOverloading::Meta::Role::Application::Composite::ToInstance';

use namespace::autoclean;


around apply_params => sub {
    my ($next, $self, @args) = @_;
    return Moose::Util::MetaRole::apply_metaroles(
        for            => $self->$next(@args),
        role_metaroles => {
            application_to_class    => [ToClass],
            application_to_role     => [ToRole],
            application_to_instance => [ToInstance],
        },
    );
};

1;

__END__
=pod

=encoding utf-8

=head1 NAME

MooseX::Role::WithOverloading::Meta::Role::Composite - Role for composite roles which support overloading

=head1 METHODS

=head2 apply_params

Wrapped method to apply various metaclass roles to aid with role composition.

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

