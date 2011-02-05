package MooseX::Emulate::Class::Accessor::Fast::Meta::Role::Attribute;
use Moose::Role;

sub accessor_metaclass { 'MooseX::Emulate::Class::Accessor::Fast::Meta::Accessor' }

1;
