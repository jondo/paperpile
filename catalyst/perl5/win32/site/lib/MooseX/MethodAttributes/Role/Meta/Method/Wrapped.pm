package MooseX::MethodAttributes::Role::Meta::Method::Wrapped;
BEGIN {
  $MooseX::MethodAttributes::Role::Meta::Method::Wrapped::AUTHORITY = 'cpan:FLORA';
}
BEGIN {
  $MooseX::MethodAttributes::Role::Meta::Method::Wrapped::VERSION = '0.24';
}
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
=pod

=encoding utf-8

=head1 NAME

MooseX::MethodAttributes::Role::Meta::Method::Wrapped - wrapped metamethod role allowing code attribute introspection

=head1 METHODS

=head2 attributes

Gets the list of code attributes of the original method this meta method wraps.

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

