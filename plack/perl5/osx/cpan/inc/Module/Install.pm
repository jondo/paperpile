package inc::Module::Install;

# This module ONLY loads if the user has manually installed their own
# installation of Module::Install, and are some form of MI author.
#
# It runs from the installed location, and is never bundled
# along with the other bundled modules.
#
# So because the version of this differs from the version that will
# be bundled almost every time, it doesn't have it's own version and
# isn't part of the synchronisation-checking.

use strict;
use vars qw{$VERSION};
BEGIN {
	# While this version will be overwritten when Module::Install
	# loads, it remains so Module::Install itself can detect which
	# version an author currently has installed.
	# This allows it to implement any back-compatibility features
	# it may want or need to.
	$VERSION = '0.91';	
}

if ( -d './inc' ) {
	my $author = $^O eq 'VMS' ? './inc/_author' : './inc/.author';
	if ( -d $author ) {
		$Module::Install::AUTHOR = 1;
		require File::Path;
		File::Path::rmtree('inc');
	}
} else {
	$Module::Install::AUTHOR = 1;
}

unshift @INC, 'inc' unless $INC[0] eq 'inc';
require Module::Install;

1;

__END__

=pod

=head1 NAME

inc::Module::Install - Module::Install configuration system

=head1 SYNOPSIS

  use inc::Module::Install;

=head1 DESCRIPTION

This module first checks whether the F<inc/.author> directory exists,
and removes the whole F<inc/> directory if it does, so the module author
always get a fresh F<inc> every time they run F<Makefile.PL>.  Next, it
unshifts C<inc> into C<@INC>, then loads B<Module::Install> from there.

Below is an explanation of the reason for using a I<loader module>:

The original implementation of B<CPAN::MakeMaker> introduces subtle
problems for distributions ending with C<CPAN> (e.g. B<CPAN.pm>,
B<WAIT::Format::CPAN>), because its placement in F<./CPAN/> duplicates
the real libraries that will get installed; also, the directory name
F<./CPAN/> may confuse users.

On the other hand, putting included, for-build-time-only libraries in
F<./inc/> is a normal practice, and there is little chance that a
CPAN distribution will be called C<Something::inc>, so it's much safer
to use.

Also, it allows for other helper modules like B<Module::AutoInstall>
to reside also in F<inc/>, and to make use of them.

=head1 AUTHORS

Audrey Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2003, 2004 Audrey Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
