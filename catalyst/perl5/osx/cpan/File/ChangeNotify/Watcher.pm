package File::ChangeNotify::Watcher;

use strict;
use warnings;

use File::ChangeNotify::Event;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Params::Validate qw( pos_validated_list );

has filter =>
    ( is      => 'ro',
      isa     => 'RegexpRef',
      default => sub { qr/.*/ },
    );

my $dir = subtype
       as 'Str'
    => where { -d $_ }
    => message { "$_ is not a valid directory" };

my $array_of_dirs = subtype
       as 'ArrayRef[Str]',
    => where { map { -d } @{$_} }
    => message { "@{$_} is not a list of valid directories" };

coerce $array_of_dirs
    => from $dir
    => via { [ $_ ] };

has directories =>
    ( is       => 'rw',
      writer   => '_set_directories',
      isa      => $array_of_dirs,
      required => 1,
      coerce   => 1,
    );

has follow_symlinks =>
    ( is      => 'ro',
      isa     => 'Bool',
      default => 0,
    );

has event_class =>
    ( is      => 'ro',
      isa     => 'ClassName',
      default => 'File::ChangeNotify::Event',
    );

has sleep_interval =>
    ( is      => 'ro',
      isa     => 'Num',
      default => 2,
    );


sub BUILD
{
    my $self = shift;

    Class::MOP::load_class( $self->event_class() );
}

sub new_events
{
    my $self = shift;

    return $self->_interesting_events();
}

sub _add_directory
{
    my $self = shift;
    my $dir  = shift;

    return if grep { $_ eq $dir } $self->directories();

    push @{ $self->directories() }, $dir;
}

sub _remove_directory
{
    my $self = shift;
    my $dir  = shift;

    $self->_set_directories( [ grep { $_ ne $dir } @{ $self->directories() } ] );
}

no Moose;
no Moose::Util::TypeConstraints;
no MooseX::Params::Validate;

__PACKAGE__->meta()->make_immutable();

1;

__END__

=head1 NAME

File::ChangeNotify::Watcher - Base class for all watchers

=head1 SYNOPSIS

    my $watcher =
        File::ChangeNotify->instantiate_watcher
            ( directories => [ '/my/path', '/my/other' ],
              filter      => qr/\.(?:pm|conf|yml)$/,
            );

    if ( my @events = $watcher->new_events() ) { ... }

    # blocking
    while ( my @events = $watcher->wait_for_events() ) { ... }

=head1 DESCRIPTION

A C<File::ChangeNotify::Watcher> class monitors a directory for
changes made to any file. You can provide a regular expression to
filter out files you are not interested in. It handles the addition of
new subdirectories by adding them to the watch list.

Note that the actual granularity of what each watcher subclass reports
may vary across subclasses. Implementations that hook into some sort
of kernel event interface (Inotify, for example) have much better
knowledge of exactly what changes are happening than one implemented
purely in userspace code (like the Default subclass).

By default, events are returned in the form
L<File::ChangeNotify::Event> objects, but this can be overridden by
providing an "event_class" attribute to the constructor.

The watcher can operate in a blocking/callback style, or you can
simply ask it for a list of new events as needed.

=head1 METHODS

=head2 File::ChangeNotify::Watcher::Subclass->new(...)

This method creates a new watcher. It accepts the following arguments:

=over 4

=item * directories => $path

=item * directories => \@paths

This argument is required. It can be either one or many paths which
should be watched for changes.

=item * regex => qr/.../

This is an optional regular expression that will be used to check if a
file is of interest. This filter is only applied to files, directories
are always included.

By default, all files are included as well.

=item * follow_symlinks => $bool

By default, symlinks are ignored. Set this to true to follow them.

If this symlinks are being followed, symlinks to files and directories
will be followed. Directories will be watched, and changes for
directories and files reported.

=item * sleep_interval => $number

For watchers which call C<sleep> to implement the C<<
$watcher->wait_for_events() >> method, this argument controls how long
it sleeps for. The value is a number in seconds.

The default is 2 seconds.

=item * event_class => $class

This can be used to change the class used to report events. By
default, this is L<File::ChangeNotify::Event>.

=back

=head2 $watcher->wait_for_events()

This method causes the watcher to block until it sees interesting
events, and then return them as a list.

Some watcher subclasses may implement blocking as a sleep loop, while
others may actually block.

=head2 $watcher->new_events()

This method returns a list of any interesting events seen since the
last time the watcher checked.

=head2 $watcher->sees_all_events()

If this is true, the watcher will report on all events.

Some watchers, like the Default subclass, are not smart enough to
track things like a file being created and then immediately deleted,
and can only detect changes between snapshots of the file system.

Other watchers, like the Inotify subclass, see all events that happen
and report on them.

=head1 AUTHOR

Dave Rolsky, E<gt>autarch@urth.orgE<lt>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Dave Rolsky, All Rights Reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
