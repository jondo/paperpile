package MooseX::SemiAffordanceAccessor::Role::Attribute;

use strict;
use warnings;

use Moose::Role;


before '_process_options' => sub
{
    my $class   = shift;
    my $name    = shift;
    my $options = shift;

    if ( exists $options->{is} &&
         ! ( exists $options->{reader} || exists $options->{writer} ) )
    {
        if ( $options->{is} eq 'ro' )
        {
            $options->{reader} = $name;
            delete $options->{is};
        }
        elsif ( $options->{is} eq 'rw' )
        {
            $options->{reader} = $name;

            my $prefix = 'set';
            if ( $name =~ s/^_// )
            {
                $prefix = '_set';
            }

            $options->{writer} = $prefix . q{_} . $name;
            delete $options->{is};
        }
    }
};

no Moose::Role;

1;

=head1 NAME

MooseX::SemiAffordanceAccessor::Role::Attribute - Names accessors in a semi-affordance style

=head1 SYNOPSIS

  Moose::Util::MetaRole::apply_metaclass_roles
      ( for_class => $p{for_class},
        attribute_metaclass_roles =>
        ['MooseX::SemiAffordanceAccessor::Role::Attribute'],
      );

=head1 DESCRIPTION

This role applies a method modifier to the C<_process_options()>
method, and tweaks the reader and writer parameters so that they
follow the semi-affordance naming style.

=head1 AUTHOR

Dave Rolsky, C<< <autarch@urth.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007-2008 Dave Rolsky, All Rights Reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

