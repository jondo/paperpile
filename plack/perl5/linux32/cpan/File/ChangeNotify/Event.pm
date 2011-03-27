package File::ChangeNotify::Event;

use strict;
use warnings;

use Moose;
use Moose::Util::TypeConstraints;

has path =>
    ( is       => 'ro',
      isa      => 'Str',
      required => 1,
    );

has type =>
    ( is       => 'ro',
      isa      => enum( [ qw( create modify delete unknown ) ] ),
      required => 1,
    );

no Moose;
no Moose::Util::TypeConstraints;

__PACKAGE__->meta()->make_immutable();

1;

__END__

=head1 NAME

File::ChangeNotify::Event - Class for file change events

=head1 SYNOPSIS

    for my $event ( $watcher->new_events() )
    {
        print $event->path(), ' - ', $event->type(), "\n";
    }

=head1 DESCRIPTION

This class provides information about a change to a specific file or
directory.

=head1 METHODS

=head2 File::ChangeNotify::Event->new(...)

This method creates a new event. It accepts the following arguments:

=over 4

=item * path => $path

The full path to the file or directory that changed.

=item * type => $type

The type of event. This must be one of "create", "modify", "delete", or
"unknown".

=back

=head2 $event->path()

Returns the path of the changed file or directory.

=head2 $event->type()

Returns the type of event.

=head1 AUTHOR

Dave Rolsky, E<gt>autarch@urth.orgE<lt>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Dave Rolsky, All Rights Reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
