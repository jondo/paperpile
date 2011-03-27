package MooseX::MethodAttributes::Role::AttrContainer::Inheritable;
our $VERSION = '0.20';
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

=head1 NAME

MooseX::MethodAttributes::Role::AttrContainer::Inheritable - capture code attributes in the automatically initialized metaclass instance

=head1 VERSION

version 0.20

=head1 DESCRIPTION

This role extends C<MooseX::MethodAttributes::Role::AttrContainer> with the
functionality of automatically initializing a metaclass for the caller and
applying the meta roles relevant for capturing method attributes.



=head1 AUTHORS

  Florian Ragwitz <rafl@debian.org>
  Tomas Doran <bobtfish@bobtfish.net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Florian Ragwitz.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut 


