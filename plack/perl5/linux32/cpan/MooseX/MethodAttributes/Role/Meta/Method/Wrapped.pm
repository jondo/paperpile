package MooseX::MethodAttributes::Role::Meta::Method::Wrapped;
our $VERSION = '0.13';

# ABSTRACT: wrapped metamethod role allowing code attribute introspection

use Moose::Role;

use namespace::clean -except => 'meta';


sub attributes {
    my ($self) = @_;
    return $self->get_original_method->attributes;
}

sub _get_attributed_coderef {
    my ($self) = @_;
    return $self->get_original_method->_get_attributed_coderef;
}

1;

__END__
=head1 NAME

MooseX::MethodAttributes::Role::Meta::Method::Wrapped - wrapped metamethod role allowing code attribute introspection

=head1 VERSION

version 0.13

=head1 METHODS

=head2 attributes

Gets the list of code attributes of the original method this meta method wraps.

=head1 AUTHORS

  Florian Ragwitz <rafl@debian.org>
  Tomas Doran <bobtfish@bobtfish.net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Florian Ragwitz.

This is free software; you can redistribute it and/or modify it under
the same terms as perl itself.

