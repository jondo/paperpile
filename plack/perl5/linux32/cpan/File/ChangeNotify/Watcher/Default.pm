package File::ChangeNotify::Watcher::Default;

use strict;
use warnings;

use File::Find qw( finddepth );
use File::Spec;
use Time::HiRes qw( sleep );
# Trying to import this just blows up on Win32, and checking
# Time::HiRes::d_hires_stat() _also_ blows up on Win32.
BEGIN { eval { Time::HiRes->import('stat') } }

use Moose;
use MooseX::SemiAffordanceAccessor;

extends 'File::ChangeNotify::Watcher';

has _map =>
    ( is      => 'rw',
      isa     => 'HashRef',
      default => sub { {} },
    );


sub sees_all_events { 0 }

sub BUILD
{
    my $self = shift;

    $self->_set_map( $self->_build_map() );
}

sub _build_map
{
    my $self = shift;

    my %map;

    finddepth
        ( { wanted      => sub { my $path = $File::Find::name;
                                 my $entry = $self->_entry_for_map($path) or return;
                                 $map{$path} = $entry;
                               },
            follow_fast => ( $self->follow_symlinks() ? 1 : 0 ),
            no_chdir    => 1
          },
          @{ $self->directories() },
       );

    return \%map;
}

sub _entry_for_map
{
    my $self = shift;
    my $path = shift;

    my $is_dir = -d $path ? 1 : 0;

    return if -l $path && ! $is_dir;

    unless ($is_dir)
    {
        my $filter = $self->filter();
        return unless ( File::Spec->splitpath($path) )[2] =~ /$filter/;
    }

    return { is_dir => $is_dir,
             mtime  => _mtime(*_),
             size   => ( $is_dir ? 0 : -s _ ),
           };
}

# It seems that Time::HiRes's stat does not act exactly like the
# built-in, so if I do ( stat _ )[9] it will not work (grr).
sub _mtime
{
    my @stat = stat;

    return $stat[9];
}

sub wait_for_events
{
    my $self = shift;

    while (1)
    {
        my @events = $self->_interesting_events();
        return @events if @events;

        sleep $self->sleep_interval();
    }
}

sub _interesting_events
{
    my $self = shift;

    my @interesting;

    my $old_map = $self->_map();
    my $new_map = $self->_build_map();

    for my $path ( sort keys %{ $old_map } )
    {
        if ( ! exists $new_map->{$path} )
        {
            if ( $old_map->{$path}{is_dir} )
            {
                $self->_remove_directory($path);
            }

            push @interesting,
                $self->event_class()->new( path => $path,
                                           type => 'delete',
                                         );
        }
        elsif (    ! $old_map->{$path}{is_dir}
                && (    $old_map->{$path}{mtime} != $new_map->{$path}{mtime}
                     || $old_map->{$path}{size} != $new_map->{$path}{size} )
              )
        {
            push @interesting,
                $self->event_class()->new( path => $path,
                                           type => 'modify',
                                         );
        }
    }

    for my $path ( sort grep { ! exists $old_map->{$_} } keys %{ $new_map } )
    {
        if ( -d $path )
        {
            push @interesting,
                $self->event_class()->new( path => $path,
                                           type => 'create',
                                         ),
        }
        else
        {
            push @interesting,
                $self->event_class()->new( path => $path,
                                           type => 'create',
                                         );
        }
    }

    $self->_set_map($new_map);

    return @interesting;
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__

=head1 NAME

File::ChangeNotify::Watcher::Default - Fallback default watcher subclass

=head1 DESCRIPTION

This class implements watching by comparing two snapshopts of the
filesystem tree. It if inefficient and dumb, and so it is the subclass
of last resort.

Its C<< $watcher->wait_for_events() >> method sleeps between
comparisons of the filesystem snapshot it takes.

=head1 AUTHOR

Dave Rolsky, E<gt>autarch@urth.orgE<lt>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Dave Rolsky, All Rights Reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
