
package MooseX::Getopt::Strict;
use Moose::Role;

with 'MooseX::Getopt';

around '_compute_getopt_attrs' => sub {
    my $next = shift;
    my ( $class, @args ) = @_;
    grep { 
        $_->isa("MooseX::Getopt::Meta::Attribute") 
    } $class->$next(@args);
};

1;

__END__

=pod

=head1 NAME

MooseX::Getopt::Strict - only make options for attrs with the Getopt metaclass
    
=head1 DESCRIPTION

This is an stricter version of C<MooseX::Getopt> which only processes the 
attributes if they explicitly set as C<Getopt> attributes. All other attributes
are ignored by the command line handler.
    
=head1 METHODS

=over 4

=item meta

=back

=head1 BUGS

All complex software has bugs lurking in it, and this module is no 
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 AUTHOR

Stevan Little E<lt>stevan@iinteractive.comE<gt>

Yuval Kogman  C<< <nuffin@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright 2007-2008 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
