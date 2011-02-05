package MooseX::MethodAttributes::Role::Meta::Role::Application;
BEGIN {
  $MooseX::MethodAttributes::Role::Meta::Role::Application::AUTHORITY = 'cpan:FLORA';
}
BEGIN {
  $MooseX::MethodAttributes::Role::Meta::Role::Application::VERSION = '0.24';
}
# ABSTRACT: generic role for applying a role with method attributes to something

use Moose::Role;
use Moose::Util qw/find_meta/;
use MooseX::MethodAttributes ();
use MooseX::MethodAttributes::Role ();
use namespace::clean -except => 'meta';

requires qw/
    _copy_attributes
    apply
/;


around 'apply' => sub {
    my ($orig, $self, $thing, %opts) = @_;
    $thing = $self->_apply_metaclasses($thing);

    my $ret = $self->$orig($thing, %opts);

    $self->_copy_attributes($thing);

    return $ret;
};

sub _apply_metaclasses {
    my ($self, $thing) = @_;
    if ($thing->isa('Moose::Meta::Class')) {
        $thing = MooseX::MethodAttributes->init_meta( for_class => $thing->name );
    }
    elsif ($thing->isa('Moose::Meta::Role')) {
        $thing = MooseX::MethodAttributes::Role->init_meta( for_class => $thing->name );
    }
    else {
        croak("Composing " . __PACKAGE__ . " onto instances is unsupported");
    }

    # Note that the metaclass instance we started out with may have been turned
    # into lies by the metatrait role application process, so we explicitly
    # re-fetch it here.

    return find_meta($thing->name);
}

1;

__END__
=pod

=encoding utf-8

=head1 NAME

MooseX::MethodAttributes::Role::Meta::Role::Application - generic role for applying a role with method attributes to something

=head1 METHODS

=head2 apply

The apply method is wrapped to ensure that the correct metaclasses to hold and propagate
method attribute data are present on the target for role application, delegates to
the original method to actually apply the role, then ensures that any attributes from
the role are copied to the target class.

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

