package File::ChangeNotify;
BEGIN {
  $File::ChangeNotify::VERSION = '0.19';
}

use strict;
use warnings;

use Carp qw( confess );
use Class::MOP;
# We load this up front to make sure that the prereq modules are installed.
use File::ChangeNotify::Watcher::Default;
use Module::Pluggable::Object;

sub instantiate_watcher {
    my $class = shift;

    for my $class ( $class->usable_classes() ) {
        if ( _try_load($class) ) {
            return $class->new(@_);
        }
    }

    return File::ChangeNotify::Watcher::Default->new(@_);
}

{
    my @usable_classes = ();

    sub usable_classes {
        my $class = shift;

        return @usable_classes if @usable_classes;
        return @usable_classes
            = grep { _try_load($_) } $class->_all_classes();
    }
}

{
    my %tried;

    sub _try_load {
        my $class = shift;

        return $tried{$class}
            if exists $tried{$class};

        eval { Class::MOP::load_class($class) };

        my $e = $@;
        die $e if $e && $e !~ /Can\'t locate|did not return a true value/;

        return $tried{$class} = $e ? 0 : 1;
    }
}

my $finder = Module::Pluggable::Object->new(
    search_path => 'File::ChangeNotify::Watcher' );

sub _all_classes {
    return
        sort grep { $_ ne 'File::ChangeNotify::Watcher::Default' }
        $finder->plugins();
}

1;

# ABSTRACT: Watch for changes to files, cross-platform style



=pod

=head1 NAME

File::ChangeNotify - Watch for changes to files, cross-platform style

=head1 VERSION

version 0.19

=head1 SYNOPSIS

    use File::ChangeNotify;

    my $watcher =
        File::ChangeNotify->instantiate_watcher
            ( directories => [ '/my/path', '/my/other' ],
              filter      => qr/\.(?:pm|conf|yml)$/,
            );

    if ( my @events = $watcher->new_events() ) { ... }

    # blocking
    while ( my @events = $watcher->wait_for_events() ) { ... }

=head1 DESCRIPTION

This module provides an API for creating a
L<File::ChangeNotify::Watcher> subclass that will work on your
platform.

Most of the documentation for this distro is in
L<File::ChangeNotify::Watcher>.

=head1 METHODS

This class provides the following methods:

=head2 File::ChangeNotify->instantiate_watcher(...)

This method looks at each available subclass of
L<File::ChangeNotify::Watcher> and instantiates the first one it can
load, using the arguments you provided.

It always tries to use the L<File::ChangeNotify::Watcher::Default>
class last, on the assumption that any other class that is available
is a better option.

=head2 File::ChangeNotify->usable_classes()

Returns a list of all the loadable L<File::ChangeNotify::Watcher>
subclasses.

=head1 BUGS

Please report any bugs or feature requests to
C<bug-file-changenotify@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 DONATIONS

If you'd like to thank me for the work I've done on this module,
please consider making a "donation" to me via PayPal. I spend a lot of
free time creating free software, and would appreciate any support
you'd care to offer.

Please note that B<I am not suggesting that you must do this> in order
for me to continue working on this particular software. I will
continue to do so, inasmuch as I have in the past, for as long as it
interests me.

Similarly, a donation made in this way will probably not make me work
on this software much more, unless I get so many donations that I can
consider working on free software full time, which seems unlikely at
best.

To donate, log into PayPal and send money to autarch@urth.org or use
the button on this page:
L<http://www.urth.org/~autarch/fs-donation.html>

=head1 AUTHOR

Dave Rolsky <autarch@urth.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2010 by Dave Rolsky.

This is free software, licensed under:

  The Artistic License 2.0

=cut


__END__

