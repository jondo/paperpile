package Catalyst::Restarter::Win32;

use Moose;
use Proc::Background;

extends 'Catalyst::Restarter';

has _child => (
    is  => 'rw',
    isa => 'Proc::Background',
);


sub _fork_and_start {
    my $self = shift;

    # This is totally hack-tastic, and is probably much slower, but it
    # does seem to work.
    my @command = ( $^X, map("-I$_", @INC), $0, grep { ! /^\-r/ } @{ $self->argv } );

    my $child = Proc::Background->new(@command);

    $self->_child($child);
}

sub _kill_child {
    my $self = shift;

    return unless $self->_child;

    $self->_child->die;
}

1;

__END__

=head1 NAME

Catalyst::Restarter::Win32 - Uses Proc::Background to manage process restarts

=head1 DESCRIPTION

This class uses L<Proc::Background>, which in turn uses
L<Win32::Process>. The new process is run using the same command-line
as the original script, but without any restart-based options.

This is a big hack, but using forks just does not work on Windows.

=head1 SEE ALSO

L<Catalyst::Restarter>, L<Catalyst>, <File::ChangeNotify>

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
