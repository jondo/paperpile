use strict;
use warnings;

package MooseX::MethodAttributes::Role;
our $VERSION = '0.20';
# ABSTRACT: code attribute introspection

use Moose ();
use Moose::Exporter;
use Moose::Util::MetaRole;
use Moose::Util qw/find_meta does_role ensure_all_roles/;
# Ensure trait is registered
use MooseX::MethodAttributes::Role::Meta::Role ();


Moose::Exporter->setup_import_methods( also => 'Moose::Role' );

sub init_meta {
    my ($class, %options) = @_;

	my $for_class = $options{for_class};
    my $meta = find_meta($for_class);

    return $meta if $meta
        && does_role($meta, 'MooseX::MethodAttributes::Role::Meta::Role');

    $meta = Moose::Meta::Role->initialize( $for_class )
        unless $meta;

    $meta = Moose::Util::MetaRole::apply_metaclass_roles(
            for_class       => $meta->name,
            metaclass_roles => [ 'MooseX::MethodAttributes::Role::Meta::Role' ],
    );

    ensure_all_roles($meta->name,
        'MooseX::MethodAttributes::Role::AttrContainer',
    );

    return $meta;
}

1;

__END__

=pod

=head1 NAME

MooseX::MethodAttributes::Role - code attribute introspection

=head1 VERSION

version 0.20

=head1 SYNOPSIS

    package MyRole;
    use MooseX::MethodAttributes::Role;

    sub foo : Bar Baz('corge') { ... }

    my $attrs = MyRole->meta->get_method('foo')->attributes; # ["Bar", "Baz('corge')"]

=head1 DESCRIPTION

This module allows you to write a Moose Role with code attributes of methods to
be introspected using Moose meta method objects.

=begin Pod::Coverage

init_meta

=end Pod::Coverage



=head1 AUTHORS

  Florian Ragwitz <rafl@debian.org>
  Tomas Doran <bobtfish@bobtfish.net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Florian Ragwitz.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut 


