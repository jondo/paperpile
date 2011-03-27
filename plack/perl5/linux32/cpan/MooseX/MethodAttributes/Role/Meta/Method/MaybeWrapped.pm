package MooseX::MethodAttributes::Role::Meta::Method::MaybeWrapped;
our $VERSION = '0.13';

# ABSTRACT: proxy attributes of wrapped methods if their metaclass supports it

use Moose::Role;
use Moose::Util qw/does_role/;
use MooseX::MethodAttributes::Role::Meta::Method::Wrapped;

use namespace::clean -except => 'meta';

override wrap => sub {
    my $self = super;
    my $original_method = $self->get_original_method;
    if (
        does_role($original_method, 'MooseX::MethodAttributes::Role::Meta::Method')
        || does_role($original_method, 'MooseX::MethodAttributes::Role::Meta::Method::Wrapped')
    ) {
        MooseX::MethodAttributes::Role::Meta::Method::Wrapped->meta->apply($self);
    }
    return $self;
};

1;

__END__
=head1 NAME

MooseX::MethodAttributes::Role::Meta::Method::MaybeWrapped - proxy attributes of wrapped methods if their metaclass supports it

=head1 VERSION

version 0.13

=head1 AUTHORS

  Florian Ragwitz <rafl@debian.org>
  Tomas Doran <bobtfish@bobtfish.net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Florian Ragwitz.

This is free software; you can redistribute it and/or modify it under
the same terms as perl itself.

