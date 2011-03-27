package File::ChangeNotify::Watcher::KQueue;
BEGIN {
  $File::ChangeNotify::Watcher::KQueue::VERSION = '0.19';
}

use strict;
use warnings;
use namespace::autoclean;

use Moose;

use File::Find ();
use IO::KQueue;

extends 'File::ChangeNotify::Watcher';

has 'absorb_delay' => (
    is      => 'ro',
    isa     => 'Int',
    default => 100,
);

has '_kqueue' => (
    is       => 'ro',
    isa      => 'IO::KQueue',
    default  => sub { IO::KQueue->new },
    init_arg => undef,
);

# We need to keep hold of filehandles for all the directories *and* files in the
# tree. KQueue events will be automatically deleted when the filehandles go out
# of scope.
has '_files' => (
    is       => 'ro',
    isa      => 'HashRef',
    default  => sub { {} },
    init_arg => undef,
);

sub sees_all_events {0}

sub BUILD {
    my ($self) = @_;
    $self->_watch_dir($_) for @{ $self->directories };
}

sub wait_for_events {
    my ($self) = @_;

    while (1) {
        my @events = $self->_get_events;
        return @events if @events;
    }
}

sub new_events {
    my ($self) = @_;
    my @events = $self->_get_events(0);
}

sub _get_events {
    my ( $self, $timeout ) = @_;

    my @kevents = $self->_kqueue->kevent( $timeout || () );

    # Events come in groups, wait for a short period to absorb any extra ones
    # that might happen immediately after the ones we've detected.
    push @kevents, $self->_kqueue->kevent( $self->absorb_delay )
        if $self->absorb_delay;

    my @events;
    foreach my $kevent (@kevents) {

        my $path  = $kevent->[KQ_UDATA];
        my $flags = $kevent->[KQ_FFLAGS];

        # Delete - this works reasonably well with KQueue
        if ( $flags & NOTE_DELETE ) {
            delete $self->_files->{$path};
            push @events, $self->_event( $path, 'delete' );
        }

        # Rename - represented as deletes and creates
        elsif ( $flags & NOTE_RENAME ) {

            # Renamed dirs
            # Use the stored filehandle (it survives renaming) to identify a dir
            # and remove any filehandles we're storing to its contents
            my $fh = $self->_files->{$path};
            if ( -d $fh ) {
                foreach my $stored_path ( keys %{ $self->_files } ) {
                    next unless index( $stored_path, $path ) == 0;
                    delete $self->_files->{$stored_path};
                    push @events, $self->_event( $stored_path, 'delete' );
                }
            }

            # Renamed files
            else {
                delete $self->_files->{$path};
                push @events, $self->_event( $path, 'delete' );
            }
        }

        # Modify/Create - writes to files indicate modification, but we get
        # writes to dirs too, which indicates a file (or dir) was created or
        # removed from the dir. Deletes are picked up by delete events, but to
        # find created files we have to scan the dir again.
        elsif ( $flags & NOTE_WRITE ) {

            if ( -f $path ) {
                push @events, $self->_event( $path, 'modify' );
            }
            elsif ( -d $path ) {
                push @events,
                    map { $self->_event( $_, 'create' ) }
                    $self->_watch_dir($path);
            }
        }
    }

    return @events;
}

sub _event {
    my ( $self, $path, $type ) = @_;
    return $self->event_class->new( path => $path, type => $type );
}

sub _watch_dir {
    my ( $self, $dir ) = @_;

    my @new_files;

    # use find(), finddepth() doesn't support pruning
    $self->_find(
        $dir,
        sub {
            my $path = $File::Find::name;

            # Don't monitor anything below excluded dirs
            return $File::Find::prune = 1
                if $self->_path_is_excluded($path);

            # Skip file names that don't match the filter
            return unless $self->_is_included_file($path);

            # Skip if we're watching it already
            return if $self->_files->{$path};

            $self->_watch_file($path);
            push @new_files, $path;
        }
    );

    return @new_files;
}

sub _is_included_file {
    my ( $self, $path ) = @_;

    return 1 if -d $path;

    my $filter   = $self->filter;
    my $filename = ( File::Spec->splitpath($path) )[2];
    return 1 if $filename =~ m{$filter};
}

sub _find {
    my ( $self, $dir, $wanted ) = @_;
    File::Find::find(
        {
            wanted      => $wanted,
            no_chdir    => 1,
            follow_fast => ( $self->follow_symlinks ? 1 : 0 ),,
            follow_skip => 2,
        },
        $dir,
    );
}

sub _watch_file {
    my ( $self, $file ) = @_;

    # Don't panic if we can't open a file
    open my $fh, '<', $file or warn "Can't open '$file': $!";
    return unless $fh;

    # Store this filehandle (this will automatically nuke any existing events
    # assigned to the file)
    $self->_files->{$file} = $fh;

    # Watch it for changes
    $self->_kqueue->EV_SET(
        fileno($fh),
        EVFILT_VNODE,
        EV_ADD | EV_CLEAR,
        NOTE_DELETE | NOTE_WRITE | NOTE_RENAME | NOTE_REVOKE,
        0,
        $file,
    );
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

File::ChangeNotify::Watcher::KQueue - KQueue-based watcher subclass

=head1 DESCRIPTION

This class implements watching using L<IO::KQueue>, which must be installed
for it to work. This is a BSD alternative to Linux's Inotify and similar
event-based systems.

=head1 CAVEATS

Although this watcher is more efficient and accurate than the
C<File::ChangeNotify::Watcher::Default> class, in order to monitor files and
directories, it must open filehandles to each of them. Because many BSD
systems have relatively low defaults for the maximum number of files each
process can open, you may find you run out of file descriptors.

On FreeBSD, you can check (and alter) your system's settings with C<sysctl> if
necessary. The important keys are: C<kern.maxfiles> and
C<kern.maxfilesperproc>.  You can see how many files your system current has
open with C<kern.openfiles>.

=head1 SUPPORT

I (Dave Rolsky) cannot test this class, as I have no BSD systems. Reasonable
patches will be applied as-is, and when possible I will consult with Dan
Thomas or other BSD users before releasing.

=head1 AUTHOR

Dan Thomas, E<lt>dan@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2010 by Dave Rolsky.

This is free software, licensed under:

  The Artistic License 2.0

=cut
