package MooseX::MethodAttributes::Role::Meta::Map;
our $VERSION = '0.13';

# ABSTRACT: role for storing code attributes

use Moose::Role;
use MooseX::Types::Moose qw/HashRef ArrayRef Str Int/;

use namespace::clean -except => 'meta';

has _method_attribute_map => (
    is        => 'ro',
    isa       => HashRef[ArrayRef[Str]],
    lazy      => 1,
    default   => sub { +{} },
);

has _method_attribute_list => (
    is      => 'ro',
    isa     => ArrayRef[Int],
    lazy    => 1,
    default => sub { [] },
);


sub register_method_attributes {
    my ($self, $code, $attrs) = @_;
    push @{ $self->_method_attribute_list }, 0 + $code;
    $self->_method_attribute_map->{ 0 + $code } = $attrs;
    return;
}


sub get_method_attributes {
    my ($self, $code) = @_;
    return $self->_method_attribute_map->{ 0 + $code } || [];
}

1;


__END__
=head1 NAME

MooseX::MethodAttributes::Role::Meta::Map - role for storing code attributes

=head1 VERSION

version 0.13

=head1 METHODS

=head2 register_method_attributes ($code, $attrs)

Register a list of attributes for a code reference.



=head2 get_method_attributes ($code)

Get a list of attributes associated with a coderef.

=head1 AUTHORS

  Florian Ragwitz <rafl@debian.org>
  Tomas Doran <bobtfish@bobtfish.net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Florian Ragwitz.

This is free software; you can redistribute it and/or modify it under
the same terms as perl itself.

