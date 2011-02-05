package MooseX::MethodAttributes::Role::AttrContainer::Inheritable;
BEGIN {
  $MooseX::MethodAttributes::Role::AttrContainer::Inheritable::AUTHORITY = 'cpan:FLORA';
}
BEGIN {
  $MooseX::MethodAttributes::Role::AttrContainer::Inheritable::VERSION = '0.24';
}
# ABSTRACT: capture code attributes in the automatically initialized metaclass instance


use Moose::Role;
use MooseX::MethodAttributes ();

use namespace::clean -except => 'meta';

with 'MooseX::MethodAttributes::Role::AttrContainer';

before MODIFY_CODE_ATTRIBUTES => sub {
    my ($class, $code, @attrs) = @_;
    return unless @attrs;
    MooseX::MethodAttributes->init_meta( for_class => $class );
};

1;


__END__
=pod

=encoding utf-8

=head1 NAME

MooseX::MethodAttributes::Role::AttrContainer::Inheritable - capture code attributes in the automatically initialized metaclass instance

=head1 DESCRIPTION

This role extends C<MooseX::MethodAttributes::Role::AttrContainer> with the
functionality of automatically initializing a metaclass for the caller and
applying the meta roles relevant for capturing method attributes.

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

