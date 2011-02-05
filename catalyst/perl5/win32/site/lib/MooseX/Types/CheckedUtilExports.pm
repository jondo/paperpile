=head1 NAME

MooseX::Types::CheckedUtilExports - Wrap L<Moose::Util::TypeConstraints> to be
safer for L<MooseX::Types>

=cut

package MooseX::Types::CheckedUtilExports;
our $VERSION = "0.25";

use strict;
use warnings;
use Moose::Util::TypeConstraints ();
use Moose::Exporter;
use Sub::Name;
use Carp;

use namespace::clean -except => 'meta';

my $StringFoundMsg =
q{WARNING: String found where Type expected (did you use a => instead of a , ?)};

my @exports = qw/type subtype maybe_type duck_type enum coerce from as/;

=head1 DESCRIPTION

Prevents errors like:

    subtype Foo =>
    ...

Which should be written as:

    subtype Foo,
    ...

When using L<MooseX::Types>. Exported by that module.

Exports checked versions of the following subs:

C<type> C<subtype> C<maybe_type> C<duck_type> C<enum> C<coerce> C<from> C<as>

While C<class_type> and C<role_type> will also register the type in the library.

From L<Moose::Util::TypeConstraints>. See that module for syntax.

=cut

for my $export (@exports) {
    no strict 'refs';

    *{$export} = sub {
        my $caller = shift;

        local $Carp::CarpLevel = $Carp::CarpLevel + 1;

        carp $StringFoundMsg
            unless ref($_[0]) ||
                $_[0] =~ /\b::\b/ || # qualified type
                $caller->get_registered_class_type($_[0]) ||
                $caller->get_registered_role_type($_[0]);

        goto &{"Moose::Util::TypeConstraints::$export"};
    }
}

Moose::Exporter->setup_import_methods(
    with_caller => [ @exports, 'class_type', 'role_type' ]
);

sub class_type {
    my $caller = shift;

    $caller->register_class_type(
        Moose::Util::TypeConstraints::class_type(@_)
    );
}

sub role_type ($;$) {
    my ($caller, $name, $opts) = @_;

    $caller->register_role_type(
        Moose::Util::TypeConstraints::role_type($name, $opts)
    );
}

=head1 SEE ALSO

L<MooseX::Types>

=head1 AUTHOR

See L<MooseX::Types/AUTHOR>.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the same terms as perl itself.

=cut

1;
