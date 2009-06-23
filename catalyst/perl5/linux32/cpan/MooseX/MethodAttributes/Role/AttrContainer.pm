package MooseX::MethodAttributes::Role::AttrContainer;
our $VERSION = '0.13';

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
=head1 NAME

MooseX::MethodAttributes::Role::AttrContainer - capture code attributes in the class' metaclass

=head1 VERSION

version 0.13

=head1 METHODS

=head2 MODIFY_CODE_ATTRIBUTES ($code, @attrs)

Accepts a list of attributes for a coderef and stores it the class' metaclass.

See L<attributes>.

=head1 AUTHORS

  Florian Ragwitz <rafl@debian.org>
  Tomas Doran <bobtfish@bobtfish.net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Florian Ragwitz.

This is free software; you can redistribute it and/or modify it under
the same terms as perl itself.

