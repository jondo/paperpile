package MooseX::Getopt::OptionTypeMap;
BEGIN {
  $MooseX::Getopt::OptionTypeMap::AUTHORITY = 'cpan:STEVAN';
}
BEGIN {
  $MooseX::Getopt::OptionTypeMap::VERSION = '0.33';
}
# ABSTRACT: Storage for the option to type mappings

use Moose 'confess', 'blessed';
use Moose::Util::TypeConstraints 'find_type_constraint';

my %option_type_map = (
    'Bool'     => '!',
    'Str'      => '=s',
    'Int'      => '=i',
    'Num'      => '=f',
    'ArrayRef' => '=s@',
    'HashRef'  => '=s%',
);

sub has_option_type {
    my (undef, $type_or_name) = @_;

    if (blessed($type_or_name)
        && $type_or_name->isa('Moose::Meta::TypeConstraint::Union')) {
        foreach my $union_type (@{$type_or_name->type_constraints}) {
            return 1
                if __PACKAGE__->has_option_type($union_type);
        }
        return 0;
    }

    return 1 if exists $option_type_map{blessed($type_or_name) ? $type_or_name->name : $type_or_name};

    my $current = blessed($type_or_name) ? $type_or_name : find_type_constraint($type_or_name);

    (defined $current)
        || confess "Could not find the type constraint for '$type_or_name'";

    while (my $parent = $current->parent) {
        return 1 if exists $option_type_map{$parent->name};
        $current = $parent;
    }

    return 0;
}

sub get_option_type {
    my (undef, $type_or_name) = @_;

    if (blessed($type_or_name)
        && $type_or_name->isa('Moose::Meta::TypeConstraint::Union')) {
        foreach my $union_type (@{$type_or_name->type_constraints}) {
            my $option_type = __PACKAGE__->get_option_type($union_type);
            return $option_type
                if defined $option_type;
        }
        return;
    }

    my $name = blessed($type_or_name) ? $type_or_name->name : $type_or_name;

    return $option_type_map{$name} if exists $option_type_map{$name};

    my $current = ref $type_or_name ? $type_or_name : find_type_constraint($type_or_name);

    (defined $current)
        || confess "Could not find the type constraint for '$type_or_name'";

    while ( $current = $current->parent ) {
        return $option_type_map{$current->name}
            if exists $option_type_map{$current->name};
    }

    return;
}

sub add_option_type_to_map {
    my (undef, $type_name, $option_string) = @_;
    (defined $type_name && defined $option_string)
        || confess "You must supply both a type name and an option string";

    if ( blessed($type_name) ) {
        $type_name = $type_name->name;
    } else {
        (find_type_constraint($type_name))
            || confess "The type constraint '$type_name' does not exist";
    }

    $option_type_map{$type_name} = $option_string;
}

no Moose::Util::TypeConstraints;
no Moose;

1;


__END__
=pod

=encoding utf-8

=head1 NAME

MooseX::Getopt::OptionTypeMap - Storage for the option to type mappings

=head1 DESCRIPTION

See the I<Custom Type Constraints> section in the L<MooseX::Getopt> docs
for more info about how to use this module.

=head1 METHODS

=head2 B<has_option_type ($type_or_name)>

=head2 B<get_option_type ($type_or_name)>

=head2 B<add_option_type_to_map ($type_name, $option_spec)>

=head1 AUTHORS

=over 4

=item *

Stevan Little <stevan@iinteractive.com>

=item *

Brandon L. Black <blblack@gmail.com>

=item *

Yuval Kogman <nothingmuch@woobling.org>

=item *

Ryan D Johnson <ryan@innerfence.com>

=item *

Drew Taylor <drew@drewtaylor.com>

=item *

Tomas Doran <bobtfish@bobtfish.net>

=item *

Florian Ragwitz <rafl@debian.org>

=item *

Dagfinn Ilmari Mannsåker <ilmari@ilmari.org>

=item *

Ævar Arnfjörð Bjarmason <avar@cpan.org>

=item *

Chris Prather <perigrin@cpan.org>

=item *

Karen Etheridge <ether@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Infinity Interactive, Inc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

