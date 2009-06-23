package MooseX::MethodAttributes::Role::AttrContainer::Inheritable;
our $VERSION = '0.13';

# ABSTRACT: capture code attributes in the automatically initialized metaclass instance


use Moose::Role;
use Moose::Meta::Class ();
use Moose::Util::MetaRole;
use Moose::Util qw/find_meta does_role/;

use namespace::clean -except => 'meta';

with 'MooseX::MethodAttributes::Role::AttrContainer';

before MODIFY_CODE_ATTRIBUTES => sub {
    my ($class, $code, @attrs) = @_;
    return unless @attrs;
    my $meta = find_meta($class);

    return if $meta
        && does_role($meta, 'MooseX::MethodAttributes::Role::Meta::Class')
        && does_role($meta->method_metaclass, 'MooseX::MethodAttributes::Role::Meta::Method')
        && does_role($meta->wrapped_method_metaclass, 'MooseX::MethodAttributes::Role::Meta::Method::MaybeWrapped');

    Moose::Meta::Class->initialize( $class )
        unless $meta;
    Moose::Util::MetaRole::apply_metaclass_roles(
        for_class                      => $class,
        metaclass_roles                => ['MooseX::MethodAttributes::Role::Meta::Class'],
        method_metaclass_roles         => ['MooseX::MethodAttributes::Role::Meta::Method'],
        wrapped_method_metaclass_roles => ['MooseX::MethodAttributes::Role::Meta::Method::MaybeWrapped'],
    );
};

1;


__END__
=head1 NAME

MooseX::MethodAttributes::Role::AttrContainer::Inheritable - capture code attributes in the automatically initialized metaclass instance

=head1 VERSION

version 0.13

=head1 DESCRIPTION

This role extends C<MooseX::MethodAttributes::Role::AttrContainer> with the
functionality of automatically initializing a metaclass for the caller and
applying the meta roles relevant for capturing method attributes.

=head1 AUTHORS

  Florian Ragwitz <rafl@debian.org>
  Tomas Doran <bobtfish@bobtfish.net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Florian Ragwitz.

This is free software; you can redistribute it and/or modify it under
the same terms as perl itself.

