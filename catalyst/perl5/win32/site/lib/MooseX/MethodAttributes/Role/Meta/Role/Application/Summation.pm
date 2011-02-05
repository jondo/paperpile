package MooseX::MethodAttributes::Role::Meta::Role::Application::Summation;
BEGIN {
  $MooseX::MethodAttributes::Role::Meta::Role::Application::Summation::AUTHORITY = 'cpan:FLORA';
}
BEGIN {
  $MooseX::MethodAttributes::Role::Meta::Role::Application::Summation::VERSION = '0.24';
}
# ABSTRACT: Role applied to the class responsible for role summation which ensures method attributes propagate from the roles being summed onto the combined role.

use Moose::Role;
use Moose::Util qw/does_role/;
use namespace::clean -except => 'meta';

with 'MooseX::MethodAttributes::Role::Meta::Role::Application';

sub _copy_attributes {
    my ($self, $thing) = @_;
    for my $role (@{ $self->get_roles }) {
        $role->_copy_attributes($thing)
            if does_role($role, 'MooseX::MethodAttributes::Role::Meta::Role');
    }
}

1;

__END__
=pod

=encoding utf-8

=head1 NAME

MooseX::MethodAttributes::Role::Meta::Role::Application::Summation - Role applied to the class responsible for role summation which ensures method attributes propagate from the roles being summed onto the combined role.

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

