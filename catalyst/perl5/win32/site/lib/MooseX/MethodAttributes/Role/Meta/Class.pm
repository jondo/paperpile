package MooseX::MethodAttributes::Role::Meta::Class;
BEGIN {
  $MooseX::MethodAttributes::Role::Meta::Class::AUTHORITY = 'cpan:FLORA';
}
BEGIN {
  $MooseX::MethodAttributes::Role::Meta::Class::VERSION = '0.24';
}
# ABSTRACT: metaclass role for storing code attributes

use Moose::Role;
use Moose::Util qw/find_meta does_role/;

use namespace::clean -except => 'meta';

with qw/
    MooseX::MethodAttributes::Role::Meta::Map
/;


sub get_method_with_attributes_list {
    my ($self) = @_;
    my @methods = map { $self->get_method($_) } $self->get_method_list;
    my %order;

    {
        my $i = 0;
        $order{$_} = $i++ for @{ $self->_method_attribute_list };
    }

    return map {
        $_->[1]
    } sort {
        $order{ $a->[0] } <=> $order{ $b->[0] }
    } map {
        my $addr = 0 + $_->_get_attributed_coderef;
        exists $self->_method_attribute_map->{$addr}
        ? [$addr, $_]
        : ()
    } grep {
        $_->can('_get_attributed_coderef')
    } @methods;
}


sub get_all_methods_with_attributes {
    my ($self) = @_;
    my %seen;

    return reverse grep {
        !$seen{ $_->name }++
    } reverse map {
        my $meth;
        my $meta = find_meta($_);
        ($meta && ($meth = $meta->can('get_method_with_attributes_list')))
            ? $meta->$meth
            : ()
    } reverse $self->linearized_isa;
}


sub get_nearest_methods_with_attributes {
    my ($self) = @_;
    my @list = map {
        my $m = $self->find_method_by_name($_->name);
        my $meth = $m->can('attributes');
        my $attrs = $meth ? $m->$meth() : [];
        scalar @{ $attrs } ? ( $m ) : ( );
    } $self->get_all_methods_with_attributes;
    return @list;
}

foreach my $type (qw/after before around/) {
    around "add_${type}_method_modifier" => sub {
        my $orig = shift;
        my $meta = shift;
        my ($method_name) = @_;

        my $code = $meta->$orig(@_);
        my $method = $meta->get_method($method_name);
        if (
            does_role($method->get_original_method, 'MooseX::MethodAttributes::Role::Meta::Method')
            || does_role($method->get_original_method, 'MooseX::MethodAttributes::Role::Meta::Method::Wrapped')
        ) {
            MooseX::MethodAttributes::Role::Meta::Method::Wrapped->meta->apply($method);
        }
        return $code;
    }
}

1;


__END__
=pod

=encoding utf-8

=head1 NAME

MooseX::MethodAttributes::Role::Meta::Class - metaclass role for storing code attributes

=head1 METHODS

=head2 get_method_with_attributes_list

Gets the list of meta methods for local methods of this class that have
attributes in the order they have been registered.

=head2 get_all_methods_with_attributes

Gets the list of meta methods of local and inherited methods of this class,
that have attributes. Baseclass methods come before subclass methods. Methods
of one class have the order they have been declared in.

=head2 get_nearest_methods_with_attributes

The same as get_all_methods_with_attributes, except that methods from parent classes
are not included if there is an attributeless method in a child class.

For example, given:

    package BaseClass;

    sub foo : Attr {}

    sub bar : Attr {}

    package SubClass;
    use base qw/BaseClass/;

    sub foo {}

    after bar => sub {}

C<< SubClass->meta->get_all_methods_with_attributes >> will return
C<< BaseClass->meta->get_method('foo') >> for the above example, but
this method will not, and will return the wrapped bar method, wheras
C<< get_all_methods_with_attributes >> will return the original method.

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

