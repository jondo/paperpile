package MooseX::Role::WithOverloading;
BEGIN {
  $MooseX::Role::WithOverloading::AUTHORITY = 'cpan:FLORA';
}
BEGIN {
  $MooseX::Role::WithOverloading::VERSION = '0.09';
}
# ABSTRACT: Roles which support overloading

use XSLoader;
use Moose::Role ();
use Moose::Exporter;
use Moose::Util::MetaRole;
use aliased 'MooseX::Role::WithOverloading::Meta::Role', 'MetaRole';
use aliased 'MooseX::Role::WithOverloading::Meta::Role::Application::ToClass';
use aliased 'MooseX::Role::WithOverloading::Meta::Role::Application::ToRole';
use aliased 'MooseX::Role::WithOverloading::Meta::Role::Application::ToInstance';

use namespace::clean;

XSLoader::load(__PACKAGE__, our $VERSION);

Moose::Exporter->setup_import_methods(also => 'Moose::Role');

sub init_meta {
    my ($class, %opts) = @_;
    my $meta = Moose::Role->init_meta(%opts);

    return Moose::Util::MetaRole::apply_metaroles(
        for            => $meta,
        role_metaroles => {
            role                    => [MetaRole],
            application_to_class    => [ToClass],
            application_to_role     => [ToRole],
            application_to_instance => [ToInstance],
        },
    );
}

1;


__END__
=pod

=encoding utf-8

=head1 NAME

MooseX::Role::WithOverloading - Roles which support overloading

=head1 SYNOPSIS

    package MyRole;
    use MooseX::Role::WithOverloading;

    use overload
        q{""}    => 'as_string',
        fallback => 1;

    has message => (
        is       => 'rw',
        isa      => 'Str',
    );

    sub as_string { shift->message }

    package MyClass;
    use Moose;
    use namespace::autoclean;

    with 'MyRole';

    package main;

    my $i = MyClass->new( message => 'foobar' );
    print $i; # Prints 'foobar'

=head1 DESCRIPTION

MooseX::Role::WithOverloading allows you to write a L<Moose::Role> which
defines overloaded operators and allows those operator overloadings to be
composed into the classes/roles/instances it's compiled to, while plain
L<Moose::Role>s would lose the overloading.

=for Pod::Coverage init_meta

=head1 AUTHORS

=over 4

=item *

Florian Ragwitz <rafl@debian.org>

=item *

Tomas Doran <bobtfish@bobtfish.net>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Florian Ragwitz.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

