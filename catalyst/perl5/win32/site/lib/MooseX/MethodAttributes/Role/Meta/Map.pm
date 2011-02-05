package MooseX::MethodAttributes::Role::Meta::Map;
BEGIN {
  $MooseX::MethodAttributes::Role::Meta::Map::AUTHORITY = 'cpan:FLORA';
}
BEGIN {
  $MooseX::MethodAttributes::Role::Meta::Map::VERSION = '0.24';
}
# ABSTRACT: generic role for storing code attributes used by classes and roles with attributes

use Moose::Role;
use MooseX::Types::Moose 0.20 qw/HashRef ArrayRef Str Int/;

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
=pod

=encoding utf-8

=head1 NAME

MooseX::MethodAttributes::Role::Meta::Map - generic role for storing code attributes used by classes and roles with attributes

=head1 METHODS

=head2 register_method_attributes ($code, $attrs)

Register a list of attributes for a code reference.

=head2 get_method_attributes ($code)

Get a list of attributes associated with a coderef.

=head1 AUTHORS

=over 4

=item *

Florian Ragwitz <rafl@debian.org>

=item *

Tomas Doran <bobtfish@bobtfish.net>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Florian Ragwitz.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

