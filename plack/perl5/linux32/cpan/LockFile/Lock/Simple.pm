;# $Id
;#
;#  @COPYRIGHT@
;#
;# $Log: Simple.pm,v $
;# Revision 0.3  2007/09/28 19:18:27  jv
;# Track where lock was issued in the code.
;#
;# Revision 0.2.1.1  2000/01/04 21:16:35  ram
;# patch1: track where lock was issued in the code
;#
;# Revision 0.2  1999/12/07 20:51:04  ram
;# Baseline for 0.2 release.
;#

use strict;

########################################################################
package LockFile::Lock::Simple;

require LockFile::Lock;

use vars qw(@ISA);

@ISA = qw(LockFile::Lock);

#
# ->make
#
# Creation routine
#
# Attributes:
#
#	scheme		the LockFile::* object that created the lock
#	file		the locked file
#	format		the format used to create the lockfile
#	filename	where lock was taken
#	line		line in filename where lock was taken
#
sub make {
	my $self = bless {}, shift;
	my ($scheme, $file, $format, $filename, $line) = @_;
	$self->{'file'} = $file;
	$self->{'format'} = $format;
	$self->_lock_init($scheme, $filename, $line);
	return $self;
}

#
# Attribute access
#

sub file	{ $_[0]->{'file'} }
sub format	{ $_[0]->{'format'} }

1;

