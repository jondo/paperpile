package MooseX::Role::WithOverloading::Meta::Role::Application::ToRole;
our $VERSION = '0.05';
# ABSTRACT: Roles which support overloading

use Moose::Role;
use aliased 'MooseX::Role::WithOverloading::Meta::Role::Application::ToClass';
use aliased 'MooseX::Role::WithOverloading::Meta::Role::Application::ToInstance';
use namespace::autoclean;

with 'MooseX::Role::WithOverloading::Meta::Role::Application';

around apply => sub {
    my ($next, $self, $role1, $role2) = @_;
    return $self->$next(
        $role1,
        Moose::Util::MetaRole::apply_metaclass_roles(
            for_class                           => $role2,
            application_to_class_class_roles    => [ ToClass     ],
            application_to_role_class_roles     => [ __PACKAGE__ ],
            application_to_instance_class_roles => [ ToInstance  ],
        ),
    );
};

1;

__END__

=pod

=head1 NAME

MooseX::Role::WithOverloading::Meta::Role::Application::ToRole - Roles which support overloading

=head1 VERSION

version 0.05

=head1 AUTHORS

  Florian Ragwitz <rafl@debian.org>
  Tomas Doran <bobtfish@bobtfish.net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Florian Ragwitz.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut 


