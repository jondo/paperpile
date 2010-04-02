package MooseX::Role::WithOverloading::Meta::Role::Composite;
our $VERSION = '0.05';
# ABSTRACT: Role for composite roles which support overloading

use Moose::Role;
use Moose::Util::MetaRole;
use aliased 'MooseX::Role::WithOverloading::Meta::Role::Application::Composite::ToClass';
use aliased 'MooseX::Role::WithOverloading::Meta::Role::Application::Composite::ToRole';
use aliased 'MooseX::Role::WithOverloading::Meta::Role::Application::Composite::ToInstance';

use namespace::autoclean;


around apply_params => sub {
    my ($next, $self, @args) = @_;
    return Moose::Util::MetaRole::apply_metaclass_roles(
        for_class                           => $self->$next(@args),
        application_to_class_class_roles    => [ ToClass    ],
        application_to_role_class_roles     => [ ToRole     ],
        application_to_instance_class_roles => [ ToInstance ],
    );
};

1;

__END__

=pod

=head1 NAME

MooseX::Role::WithOverloading::Meta::Role::Composite - Role for composite roles which support overloading

=head1 VERSION

version 0.05

=head1 METHODS

=head2 apply_params

Wrapped method to apply various metaclass roles to aid with role composition.



=head1 AUTHORS

  Florian Ragwitz <rafl@debian.org>
  Tomas Doran <bobtfish@bobtfish.net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Florian Ragwitz.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut 


