use strict;
use warnings;

package MooseX::MethodAttributes;
our $VERSION = '0.13';

# ABSTRACT: code attribute introspection

use Moose ();
use Moose::Exporter;
use Moose::Util::MetaRole;
# Ensure trait is registered
use MooseX::MethodAttributes::Role::Meta::Role ();


Moose::Exporter->setup_import_methods;

sub init_meta {
    my ($class, %options) = @_;
    my $meta = Moose->init_meta(%options);
    Moose::Util::MetaRole::apply_metaclass_roles(
        for_class                      => $options{for_class},
        metaclass_roles                => ['MooseX::MethodAttributes::Role::Meta::Class'],
        method_metaclass_roles         => ['MooseX::MethodAttributes::Role::Meta::Method'],
        wrapped_method_metaclass_roles => ['MooseX::MethodAttributes::Role::Meta::Method::MaybeWrapped'],
    );
    Moose::Util::MetaRole::apply_base_class_roles(
        for_class => $options{for_class},
        roles     => ['MooseX::MethodAttributes::Role::AttrContainer'],
    );
    return $meta;
}

1;

__END__
=head1 NAME

MooseX::MethodAttributes - code attribute introspection

=head1 VERSION

version 0.13

=head1 SYNOPSIS

    package MyClass;

    use Moose;
    use MooseX::MethodAttributes;

    sub foo : Bar Baz('corge') { ... }

    my $attrs = MyClass->meta->get_method('foo')->attributes; # ["Bar", "Baz('corge')"]

=head1 DESCRIPTION

This module allows code attributes of methods to be introspected using Moose
meta method objects.

=pod

=begin Pod::Coverage

init_meta

=end Pod::Coverage

=cut

=head1 AUTHORS

  Florian Ragwitz <rafl@debian.org>
  Tomas Doran <bobtfish@bobtfish.net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Florian Ragwitz.

This is free software; you can redistribute it and/or modify it under
the same terms as perl itself.

