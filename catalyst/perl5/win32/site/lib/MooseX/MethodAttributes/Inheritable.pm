package MooseX::MethodAttributes::Inheritable;
BEGIN {
  $MooseX::MethodAttributes::Inheritable::AUTHORITY = 'cpan:FLORA';
}
BEGIN {
  $MooseX::MethodAttributes::Inheritable::VERSION = '0.24';
}
# ABSTRACT: inheritable code attribute introspection


# Ensure trait is registered
use MooseX::MethodAttributes::Role::Meta::Role ();

use Moose;

use namespace::clean -except => 'meta';

with 'MooseX::MethodAttributes::Role::AttrContainer::Inheritable';

__PACKAGE__->meta->make_immutable;


__END__
=pod

=encoding utf-8

=head1 NAME

MooseX::MethodAttributes::Inheritable - inheritable code attribute introspection

=head1 SYNOPSIS

    package BaseClass;
    use base qw/MooseX::MethodAttributes::Inheritable/;

    package SubClass;
    use base qw/BaseClass/;

    sub foo : Bar {}

    my $attrs = SubClass->meta->get_method('foo')->attributes; # ["Bar"]

=head1 DESCRIPTION

This module does the same as C<MooseX::MethodAttributes>, except that classes
inheriting from other classes using it don't need to do anything special to get
their code attributes captured.

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

