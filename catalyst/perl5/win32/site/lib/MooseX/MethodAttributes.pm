package MooseX::MethodAttributes;
BEGIN {
  $MooseX::MethodAttributes::AUTHORITY = 'cpan:FLORA';
}
BEGIN {
  $MooseX::MethodAttributes::VERSION = '0.24';
}
# ABSTRACT: code attribute introspection

use Moose ();
use Moose::Exporter;
use Moose::Util::MetaRole;
use Moose::Util qw/find_meta does_role/;
# Ensure trait is registered
use MooseX::MethodAttributes::Role::Meta::Role ();


Moose::Exporter->setup_import_methods;

sub init_meta {
    my ($class, %options) = @_;

    my $for_class = $options{for_class};
    my $meta = find_meta($for_class);

    return $meta if $meta
        && does_role($meta, 'MooseX::MethodAttributes::Role::Meta::Class')
        && does_role($meta->method_metaclass, 'MooseX::MethodAttributes::Role::Meta::Method')
        && does_role($meta->wrapped_method_metaclass, 'MooseX::MethodAttributes::Role::Meta::Method::MaybeWrapped');

    $meta = Moose::Meta::Class->initialize( $for_class )
        unless $meta;

    $meta = Moose::Util::MetaRole::apply_metaroles(
        for             => $for_class,
        class_metaroles => {
            class  => ['MooseX::MethodAttributes::Role::Meta::Class'],
            method => ['MooseX::MethodAttributes::Role::Meta::Method'],
            wrapped_method => [
                'MooseX::MethodAttributes::Role::Meta::Method::MaybeWrapped'],
        },
    );

    Moose::Util::MetaRole::apply_base_class_roles(
        for_class => $for_class,
        roles     => ['MooseX::MethodAttributes::Role::AttrContainer'],
    );

    return $meta;
}

1;

__END__
=pod

=encoding utf-8

=head1 NAME

MooseX::MethodAttributes - code attribute introspection

=head1 SYNOPSIS

    package MyClass;

    use Moose;
    use MooseX::MethodAttributes;

    sub foo : Bar Baz('corge') { ... }

    my $attrs = MyClass->meta->get_method('foo')->attributes; # ["Bar", "Baz('corge')"]

=head1 DESCRIPTION

This module allows code attributes of methods to be introspected using Moose
meta method objects.

=for Pod::Coverage init_meta

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

