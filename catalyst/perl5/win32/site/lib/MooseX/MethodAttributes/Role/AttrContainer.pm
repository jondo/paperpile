package MooseX::MethodAttributes::Role::AttrContainer;
BEGIN {
  $MooseX::MethodAttributes::Role::AttrContainer::AUTHORITY = 'cpan:FLORA';
}
BEGIN {
  $MooseX::MethodAttributes::Role::AttrContainer::VERSION = '0.24';
}
# ABSTRACT: capture code attributes in the class' metaclass

use Moose::Role;
use Moose::Util qw/find_meta/;

use namespace::clean -except => 'meta';


sub MODIFY_CODE_ATTRIBUTES {
    my ($class, $code, @attrs) = @_;
    find_meta($class)->register_method_attributes($code, \@attrs);
    return ();
}

1;

__END__
=pod

=encoding utf-8

=head1 NAME

MooseX::MethodAttributes::Role::AttrContainer - capture code attributes in the class' metaclass

=head1 METHODS

=head2 MODIFY_CODE_ATTRIBUTES ($code, @attrs)

Accepts a list of attributes for a coderef and stores it the class' metaclass.

See L<attributes>.

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

