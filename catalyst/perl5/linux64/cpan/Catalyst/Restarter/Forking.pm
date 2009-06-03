package Catalyst::Restarter::Forking;

use Moose;

extends 'Catalyst::Restarter';

has _child => (
    is  => 'rw',
    isa => 'Int',
);


sub _fork_and_start {
    my $self = shift;

    if ( my $pid = fork ) {
        $self->_child($pid);
    }
    else {
        $self->start_sub->();
    }
}

sub _kill_child {
    my $self = shift;

    return unless $self->_child;

    return unless kill 0, $self->_child;

    local $SIG{CHLD} = 'IGNORE';
    die "Cannot send INT signal to ", $self->_child, ": $!"
        unless kill 'INT', $self->_child;
}

1;

__END__

=head1 NAME

Catalyst::Restarter::Forking - Forks and restarts the child process

=head1 DESCRIPTION

This class forks and runs the server in a child process. When it needs
to restart, it kills the child and creates a new one.

=head1 SEE ALSO

L<Catalyst::Restarter>, L<Catalyst>, <File::ChangeNotify>

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
