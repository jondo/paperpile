package MooseX::MethodAttributes::Role::Meta::Method;
BEGIN {
  $MooseX::MethodAttributes::Role::Meta::Method::AUTHORITY = 'cpan:FLORA';
}
BEGIN {
  $MooseX::MethodAttributes::Role::Meta::Method::VERSION = '0.24';
}
# ABSTRACT: metamethod role allowing code attribute introspection

use Moose::Role;

use namespace::clean -except => 'meta';


has attributes => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_attributes',
);


sub _build_attributes {
    my ($self) = @_;
    return $self->associated_metaclass->get_method_attributes($self->_get_attributed_coderef);
}

sub _get_attributed_coderef {
    my ($self) = @_;
    return $self->body;
}

1;

__END__
=pod

=encoding utf-8

=head1 NAME

MooseX::MethodAttributes::Role::Meta::Method - metamethod role allowing code attribute introspection

=head1 ATTRIBUTES

=head2 attributes

Gets the list of code attributes of the method represented by this meta method.

=head1 METHODS

=head2 _build_attributes

Builds the value of the C<attributes> attribute based on the attributes
captured in the associated meta class.

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

