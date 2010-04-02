package MooseX::Types::Common::String;

use strict;
use warnings;

our $VERSION = '0.001001';

use MooseX::Types -declare => [
  qw(SimpleStr NonEmptySimpleStr Password StrongPassword NonEmptyStr)
];

use MooseX::Types::Moose qw/Str/;

subtype SimpleStr,
  as Str,
  where { (length($_) <= 255) && ($_ !~ m/\n/) },
  message { "Must be a single line of no more than 255 chars" };

subtype NonEmptySimpleStr,
  as SimpleStr,
  where { length($_) > 0 },
  message { "Must be a non-empty single line of no more than 255 chars" };

# XXX duplicating constraint msges since moose only uses last message
subtype Password,
  as NonEmptySimpleStr,
  where { length($_) > 3 },
  message { "Must be between 4 and 255 chars" };

subtype StrongPassword,
  as Password,
  where { (length($_) > 7) && (m/[^a-zA-Z]/) },
  message {"Must be between 8 and 255 chars, and contain a non-alpha char" };

subtype NonEmptyStr,
  as Str,
  where { length($_) > 0 },
  message { "Must not be empty" };


1;

=head1 NAME

MooseX::Types::Common::String - Commonly used string types

=head1 SYNOPSIS

    use MooseX::Types::Common::String qw/SimpleStr/;
    has short_str => (is => 'rw', isa => SimpleStr);

    ...
    #this will fail
    $object->short_str("string\nwith\nbreaks");

=head1 DESCRIPTION

A set of commonly-used string type constraints that do not ship with Moose by
default.

=over

=item * SimpleStr

A Str with no new-line characters.

=item * NonEmptySimpleStr

Does what it says on the tin.

=item * Password

=item * StrongPassword

=item * NonEmptyStr

=back

=head1 SEE ALSO

=over

=item * L<MooseX::Types::Common::Numeric>

=back

=head1 AUTHORS

Please see:: L<MooseX::Types::Common>

=cut
