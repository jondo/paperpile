;# $Id$
;#
;#  @COPYRIGHT@
;#
;# $Log: Simple.pm,v $
;# Revision 0.4  2007/09/28 19:22:05  jv
;# Bump version.
;#
;# Revision 0.3  2007/09/28 19:19:41  jv
;# Revision 0.2.1.5  2000/09/18 19:55:07  ram
;# patch5: fixed computation of %F and %D when no '/' in file name
;# patch5: fixed OO example of lock to emphasize check on returned value
;# patch5: now warns when no lockfile is found during unlocking
;#
;# Revision 0.2.1.4  2000/08/15 18:41:43  ram
;# patch4: updated version number, grrr...
;#
;# Revision 0.2.1.3  2000/08/15 18:37:37  ram
;# patch3: fixed non-working "-wfunc => undef" due to misuse of defined()
;# patch3: check for stale lock while we wait for it
;# patch3: untaint pid before running kill() for -T scripts
;#
;# Revision 0.2.1.2  2000/03/02 22:35:02  ram
;# patch2: allow "undef" in -efunc and -wfunc to suppress logging
;# patch2: documented how to force warn() despite Log::Agent being there
;#
;# Revision 0.2.1.1  2000/01/04 21:18:10  ram
;# patch1: logerr and logwarn are autoloaded, need to check something real
;# patch1: forbid re-lock of a file we already locked
;# patch1: force $\ to be undef prior to writing the PID to lockfile
;# patch1: track where lock was issued in the code
;#
;# Revision 0.2.1.5  2000/09/18 19:55:07  ram
;# patch5: fixed computation of %F and %D when no '/' in file name
;# patch5: fixed OO example of lock to emphasize check on returned value
;# patch5: now warns when no lockfile is found during unlocking
;#
;# Revision 0.2.1.4  2000/08/15 18:41:43  ram
;# patch4: updated version number, grrr...
;#
;# Revision 0.2.1.3  2000/08/15 18:37:37  ram
;# patch3: fixed non-working "-wfunc => undef" due to misuse of defined()
;# patch3: check for stale lock while we wait for it
;# patch3: untaint pid before running kill() for -T scripts
;#
;# Revision 0.2.1.2  2000/03/02 22:35:02  ram
;# patch2: allow "undef" in -efunc and -wfunc to suppress logging
;# patch2: documented how to force warn() despite Log::Agent being there
;#
;# Revision 0.2.1.1  2000/01/04 21:18:10  ram
;# patch1: logerr and logwarn are autoloaded, need to check something real
;# patch1: forbid re-lock of a file we already locked
;# patch1: force $\ to be undef prior to writing the PID to lockfile
;# patch1: track where lock was issued in the code
;#
;# Revision 0.2  1999/12/07 20:51:05  ram
;# Baseline for 0.2 release.
;#

use strict;

########################################################################
package LockFile::Simple;

#
# This package extracts the simple locking logic used by mailagent-3.0
# into a standalone Perl module to be reused in other applications.
#

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Sys::Hostname;
require Exporter;
require LockFile::Lock::Simple;
eval "use Log::Agent";

@ISA = qw(Exporter);
@EXPORT = ();
@EXPORT_OK = qw(lock trylock unlock);
$VERSION = '0.207';

my $LOCKER = undef;			# Default locking object

#
# ->make
#
# Create a file locking object, responsible for holding the locking
# parameters to be used by all the subsequent locks requested from
# this locking object.
#
# Configuration attributes:
#
#	autoclean		keep track of locks and release pending one at END time
#   max				max number of attempts
#	delay			seconds to wait between attempts
#	format			how to derive lockfile from file to be locked
#	hold			max amount of seconds before breaking lock (0 for never)
#	ext				lock extension
#	nfs				true if lock must "work" on top of NFS
#	stale			try to detect stale locks via SIGZERO and delete them
#	warn			flag to turn warnings on
#	wmin			warn once after that many waiting seconds
#	wafter			warn every that many seconds after first warning
#	wfunc			warning function to be called
#	efunc			error function to be called
#
# Additional attributes:
#
#	manager			lock manager, used when autoclean
#	lock_by_file	returns lock by filename
#
# The creation routine first and sole argument is a "hash table list" listing
# all the configuration attributes. Missing attributes are given a default
# value. A call to ->configure can alter the configuration parameters of
# an existing object.
#
sub make {
	my $self = bless {}, shift;
	my (@hlist) = @_;

	# Set configuration defaults, then override with user preferences
	$self->{'max'} = 30;
	$self->{'delay'} = 2;
	$self->{'hold'} = 3600;
	$self->{'ext'} = '.lock';
	$self->{'nfs'} = 0;
	$self->{'stale'} = 0;
	$self->{'warn'} = 1;
	$self->{'wmin'} = 15;
	$self->{'wafter'} = 20;
	$self->{'autoclean'} = 0;
	$self->{'lock_by_file'} = {};

	# The logxxx routines are autoloaded, so need to check for @EXPORT
	$self->{'wfunc'} = defined(@Log::Agent::EXPORT) ? \&logwarn : \&core_warn;
	$self->{'efunc'} = defined(@Log::Agent::EXPORT) ?  \&logerr  : \&core_warn;

	$self->configure(@hlist);		# Will init "manager" if necessary
	return $self;
}

#
# ->locker		-- "once" function
#
# Compute the default locking object.
#
sub locker {
	return $LOCKER || ($LOCKER = LockFile::Simple->make('-warn' => 1));
}

#
# ->configure
#
# Extract known configuration parameters from the specified hash list
# and use their values to change the object's corresponding parameters.
#
# Parameters are specified as (-warn => 1, -ext => '.lock') for instance.
#
sub configure {
	my $self = shift;
	my (%hlist) = @_;
	my @known = qw(
		autoclean
		max delay hold format ext nfs warn wfunc wmin wafter efunc stale
	);

	foreach my $attr (@known) {
		$self->{$attr} = $hlist{"-$attr"} if exists $hlist{"-$attr"};
	}

	$self->{'wfunc'} = \&no_warn unless defined $self->{'wfunc'};
	$self->{'efunc'} = \&no_warn unless defined $self->{'efunc'};

	if ($self->autoclean) {
		require LockFile::Manager;
		# Created via "once" function
		$self->{'manager'} = LockFile::Manager->manager(
			$self->wfunc, $self->efunc);
	}
}

#
# Attribute access
#

sub max				{ $_[0]->{'max'} }
sub delay			{ $_[0]->{'delay'} }
sub format			{ $_[0]->{'format'} }
sub hold			{ $_[0]->{'hold'} }
sub nfs				{ $_[0]->{'nfs'} }
sub stale			{ $_[0]->{'stale'} }
sub ext				{ $_[0]->{'ext'} }
sub warn			{ $_[0]->{'warn'} }
sub wmin			{ $_[0]->{'wmin'} }
sub wafter			{ $_[0]->{'wafter'} }
sub wfunc			{ $_[0]->{'wfunc'} }
sub efunc			{ $_[0]->{'efunc'} }
sub autoclean		{ $_[0]->{'autoclean'} }
sub lock_by_file	{ $_[0]->{'lock_by_file'} }
sub manager			{ $_[0]->{'manager'} }

#
# Warning and error reporting -- Log::Agent used only when available
#

sub core_warn	{ CORE::warn(@_) }
sub no_warn		{ return }

#
# ->lock
#
# Lock specified file, possibly using alternate file "format".
# Returns whether file was locked or not at the end of the configured
# blocking period by providing the LockFile::Lock instance if successful.
#
# For quick and dirty scripts wishing to use locks, create the locking
# object if not invoked as a method, turning on warnings.
#
sub lock {
	my $self = shift;
	unless (ref $self) {			# Not invoked as a method
		unshift(@_, $self);
		$self = locker();
	}
	my ($file, $format) = @_;		# File to be locked, lock format
	return $self->take_lock($file, $format, 0);
}

#
# ->trylock
#
# Attempt to lock specified file, possibly using alternate file "format".
# If the file is already locked, don't block and return undef. The
# LockFile::Lock instance is returned upon success.
#
# For quick and dirty scripts wishing to use locks, create the locking
# object if not invoked as a method, turning on warnings.
#
sub trylock {
	my $self = shift;
	unless (ref $self) {			# Not invoked as a method
		unshift(@_, $self);
		$self = locker();
	}
	my ($file, $format) = @_;		# File to be locked, lock format
	return $self->take_lock($file, $format, 1);
}

#
# ->take_lock
#
# Common code for ->lock and ->trylock.
# Returns a LockFile::Lock object on success, undef on failure.
#
sub take_lock {
	my $self = shift;
	my ($file, $format, $tryonly) = @_;

	#
	# If lock was already taken by us, it's an error when $tryonly is 0.
	# Otherwise, simply fail to get the lock.
	#

	my $lock = $self->lock_by_file->{$file};
	if (defined $lock) {
		my $where = $lock->where;
		&{$self->efunc}("file $file already locked at $where") unless $tryonly;
		return undef;
	}

	my $locked = $self->_acs_lock($file, $format, $tryonly);
	return undef unless $locked;

	#
	# Create LockFile::Lock object
	#

	my ($package, $filename, $line) = caller(1);
	$lock = LockFile::Lock::Simple->make($self, $file, $format,
		$filename, $line);
	$self->manager->remember($lock) if $self->autoclean;
	$self->lock_by_file->{$file} = $lock;

	return $lock;
}

#
# ->unlock
#
# Unlock file.
# Returns true if file was unlocked.
#
sub unlock {
	my $self = shift;
	unless (ref $self) {			# Not invoked as a method
		unshift(@_, $self);
		$self = locker();
	}
	my ($file, $format) = @_;		# File to be unlocked, lock format

	if (defined $format) {
		require Carp;
		Carp::carp("2nd argument (format) is no longer needed nor used");
	}

	#
	# Retrieve LockFile::Lock object
	#

	my $lock = $self->lock_by_file->{$file};

	unless (defined $lock) {
		&{$self->efunc}("file $file not currently locked");
		return undef;
	}

	return $self->release($lock);
}

#
# ->release			-- not exported (i.e. not documented)
#
# Same a unlock, but we're passed a LockFile::Lock object.
# And we MUST be called as a method (usually via LockFile::Lock, not user code).
#
# Returns true if file was unlocked.
#
sub release {
	my $self = shift;
	my ($lock) = @_;
	my $file = $lock->file;
	my $format = $lock->format;
	$self->manager->forget($lock) if $self->autoclean;
	delete $self->lock_by_file->{$file};
	return $self->_acs_unlock($file, $format);
}

#
# ->lockfile
#
# Return the name of the lockfile, given the file name to lock and the custom
# string provided by the user. The following macros are substituted:
#	%D: the file dir name
#   %f: the file name (full path)
#   %F: the file base name (last path component)
#   %p: the process's pid
#   %%: a plain % character
#
sub lockfile {
	my $self = shift;
	my ($file, $format) = @_;
	local $_ = defined($format) ? $format : $self->format;
	s/%%/\01/g;				# Protect double percent signs
	s/%/\02/g;				# Protect against substitutions adding their own %
	s/\02f/$file/g;			# %f is the full path name
	s/\02D/&dir($file)/ge;	# %D is the dir name
	s/\02F/&base($file)/ge;	# %F is the base name
	s/\02p/$$/g;			# %p is the process's pid
	s/\02/%/g;				# All other % kept as-is
	s/\01/%/g;				# Restore escaped % signs
	$_;
}

# Return file basename (last path component)
sub base {
	my ($file) = @_;
	my ($base) = $file =~ m|^.*/(.*)|;
	return ($base eq '') ? $file : $base;
}

# Return dirname
sub dir {
	my ($file) = @_;
	my ($dir) = $file =~ m|^(.*)/.*|;
	return ($dir eq '') ? '.' : $dir;
}

#
# _acs_lock			-- private
#
# Internal locking routine.
#
# If $try is true, don't wait if the file is already locked.
# Returns true if the file was locked.
#
sub _acs_lock {		## private
	my $self = shift;
	my ($file, $format, $try) = @_;
	my $max = $self->max;
	my $delay = $self->delay;
	my $stamp = $$;

	# For NFS, we need something more unique than the process's PID
	$stamp .= ':' . hostname if $self->nfs;

	# Compute locking file name -- hardwired default format is "%f.lock"
	my $lockfile = $file . $self->ext;
	$format = $self->format unless defined $format;
	$lockfile = $self->lockfile($file, $format) if defined $format;

	# Detect stale locks or break lock if held for too long
	$self->_acs_stale($file, $lockfile) if $self->stale;
	$self->_acs_check($file, $lockfile) if $self->hold;

	my $waited = 0;					# Amount of time spent sleeping
	my $lastwarn = 0;				# Last time we warned them...
	my $warn = $self->warn;
	my ($wmin, $wafter, $wfunc);
	($wmin, $wafter, $wfunc) = 
		($self->wmin, $self->wafter, $self->wfunc) if $warn;
	my $locked = 0;
	my $mask = umask(0333);			# No write permission
	local *FILE;

	while ($max-- > 0) {
		if (-f $lockfile) {
			next unless $try;
			umask($mask);
			return 0;				# Already locked
		}

		# Attempt to create lock
		if (open(FILE, ">$lockfile")) {
			local $\ = undef;
			print FILE "$stamp\n";
			close FILE;
			open(FILE, $lockfile);	# Check lock
			my $l;
			chop($l = <FILE>);
			$locked = $l eq $stamp;
			$l = <FILE>;			# Must be EOF
			$locked = 0 if defined $l; 
			close FILE;
			last if $locked;		# Lock seems to be ours
		} elsif ($try) {
			umask($mask);
			return 0;				# Already locked, or cannot create lock
		}
	} continue {
		sleep($delay);				# Busy: wait
		$waited += $delay;

		# Warn them once after $wmin seconds and then every $wafter seconds
		if (
			$warn &&
				((!$lastwarn && $waited > $wmin) ||
				($waited - $lastwarn) > $wafter)
		) {
			my $waiting  = $lastwarn ? 'still waiting' : 'waiting';
			my $after  = $lastwarn ? 'after' : 'since';
			my $s = $waited == 1 ? '' : 's';
			&$wfunc("$waiting for $file lock $after $waited second$s");
			$lastwarn = $waited;
		}

		# While we wait, existing lockfile may become stale or too old
		$self->_acs_stale($file, $lockfile) if $self->stale;
		$self->_acs_check($file, $lockfile) if $self->hold;
	}

	umask($mask);
	return $locked;
}

#
# ->_acs_unlock		-- private
#
# Unlock file. If lock format is specified, it must match the one used
# at lock time.
#
# Return true if file was indeed locked by us and is now properly unlocked.
#
sub _acs_unlock {	## private
	my $self = shift;
	my ($file, $format) = @_;		# Locked file, locking format
	my $stamp = $$;
	$stamp .= ':' . hostname if $self->nfs;

	# Compute locking file name -- hardwired default format is "%f.lock"
	my $lockfile = $file . $self->ext;
	$format = $self->format unless defined $format;
	$lockfile = $self->lockfile($file, $format) if defined $format;

	local *FILE;
	my $unlocked = 0;

	if (-f $lockfile) {
		open(FILE, $lockfile);
		my $l;
		chop($l = <FILE>);
		close FILE;
		if ($l eq $stamp) {			# Pid (plus hostname possibly) is OK
			$unlocked = 1;
			unless (unlink $lockfile) {
				$unlocked = 0;
				&{$self->efunc}("cannot unlock $file: $!");
			}
		} else {
			&{$self->efunc}("cannot unlock $file: lock not owned");
		}
	} else {
		&{$self->wfunc}("no lockfile found for $file");
	}

	return $unlocked;				# Did we successfully unlock?
}

#
# ->_acs_check
#
# Make sure lock lasts only for a reasonable time. If it has expired,
# then remove the lockfile.
#
# This is not enabled by default because there is a race condition between
# the time we stat the file and the time we unlink the lockfile.
#
sub _acs_check {
	my $self = shift;
	my ($file, $lockfile) = @_;

	my $mtime = (stat($lockfile))[9];
	return unless defined $mtime;	# Assume file does not exist
	my $hold = $self->hold;

	# If file too old to be considered stale?
	if ((time - $mtime) > $hold) {

		# RACE CONDITION -- shall we lock the lockfile?

		unless (unlink $lockfile) {
			&{$self->efunc}("cannot unlink $lockfile: $!");
			return;
		}

		if ($self->warn) {
			my $s = $hold == 1 ? '' : 's';
			&{$self->wfunc}("UNLOCKED $file (lock older than $hold second$s)");
		}
	}
}

#
# ->_acs_stale
#
# Detect stale locks and remove them. This works by sending a SIGZERO to
# the pid held in the lockfile. If configured for NFS, only processes
# on the same host than the one holding the lock will be able to perform
# the check.
#
# Stale lock detection is not enabled by default because there is a race
# condition between the time we check for the pid, and the time we unlink
# the lockfile: we could well be unlinking a new lockfile created inbetween.
#
sub _acs_stale {
	my $self = shift;
	my ($file, $lockfile) = @_;

	local *FILE;
	open(FILE, $lockfile) || return;
	my $stamp;
	chop($stamp = <FILE>);
	close FILE;

	my ($pid, $hostname);

	if ($self->nfs) {
		($pid, $hostname) = $stamp =~ /^(\d+):(\S+)/;
		my $local = hostname;
		return if $local ne $hostname;
		return if kill 0, $pid;
		$hostname = " on $hostname";
	} else {
		($pid) = $stamp =~ /^(\d+)$/;		# Untaint $pid for kill()
		$hostname = '';
		return if kill 0, $pid;
	}

	# RACE CONDITION -- shall we lock the lockfile?

	unless (unlink $lockfile) {
		&{$self->efunc}("cannot unlink stale $lockfile: $!");
		return;
	}

	&{$self->wfunc}("UNLOCKED $file (stale lock by PID $pid$hostname)");
}

1;

########################################################################

=head1 NAME

LockFile::Simple - simple file locking scheme

=head1 SYNOPSIS

 use LockFile::Simple qw(lock trylock unlock);

 # Simple locking using default settings
 lock("/some/file") || die "can't lock /some/file\n";
 warn "already locked\n" unless trylock("/some/file");
 unlock("/some/file");

 # Build customized locking manager object
 $lockmgr = LockFile::Simple->make(-format => '%f.lck',
	-max => 20, -delay => 1, -nfs => 1);

 $lockmgr->lock("/some/file") || die "can't lock /some/file\n";
 $lockmgr->trylock("/some/file");
 $lockmgr->unlock("/some/file");

 $lockmgr->configure(-nfs => 0);

 # Using lock handles
 my $lock = $lockmgr->lock("/some/file");
 $lock->release;

=head1 DESCRIPTION

This simple locking scheme is not based on any file locking system calls
such as C<flock()> or C<lockf()> but rather relies on basic file system
primitives and properties, such as the atomicity of the C<write()> system
call. It is not meant to be exempt from all race conditions, especially over
NFS. The algorithm used is described below in the B<ALGORITHM> section.

It is possible to customize the locking operations to attempt locking
once every 5 seconds for 30 times, or delete stale locks (files that are
deemed too ancient) before attempting the locking.

=head1 ALGORITHM

The locking alogrithm attempts to create a I<lockfile> using a temporarily
redefined I<umask> (leaving only read rights to prevent further create
operations). It then writes the process ID (PID) of the process and closes
the file. That file is then re-opened and read. If we are able to read the
same PID we wrote, and only that, we assume the locking is successful.

When locking over NFS, i.e. when the one of the potentially locking processes
could access the I<lockfile> via NFS, then writing the PID is not enough.
We also write the hostname where locking is attempted to ensure the data
are unique.

=head1 CUSTOMIZING

Customization is only possible by using the object-oriented interface,
since the configuration parameters are stored within the object. The
object creation routine C<make> can be given configuration parmeters in
the form a "hash table list", i.e. a list of key/value pairs. Those
parameters can later be changed via C<configure> by specifying a similar
list of key/value pairs.

To benefit from the bareword quoting Perl offers, all the parameters must
be prefixed with the C<-> (minus) sign, as in C<-format> for the I<format>
parameter..  However, when querying the object, the minus must be omitted,
as in C<$obj-E<gt>format>.

Here are the available configuration parmeters along with their meaning,
listed in alphabetical order:

=over 4

=item I<autoclean>

When true, all locks are remembered and pending ones are automatically
released when the process exits normally (i.e. whenever Perl calls the
END routines).

=item I<delay>

The amount of seconds to wait between locking attempts when the file appears
to be already locked. Default is 2 seconds.

=item I<efunc>

A function pointer to dereference when an error is to be reported. By default,
it redirects to the logerr() routine if you have Log::Agent installed,
to Perl's warn() function otherwise.

You may set it explicitely to C<\&LockFile::Simple::core_warn> to force the
use of Perl's warn() function, or to C<undef> to suppress logging.

=item I<ext>

The locking extension that must be added to the file path to be locked to
compute the I<lockfile> path. Default is C<.lock> (note that C<.> is part
of the extension and can therefore be changed). Ignored when I<format> is
also used.

=item I<format>

Using this parmeter supersedes the I<ext> parmeter. The formatting string
specified is run through a rudimentary macro expansion to derive the
I<lockfile> path from the file to be locked. The following macros are
available:

    %%	A real % sign
    %f	The full file path name
    %D	The directory where the file resides
    %F	The base name of the file
    %p	The process ID (PID)

The default is to use the locking extension, which itself is C<.lock>, so
it is as if the format used was C<%f.lock>, but one could imagine things
like C</var/run/%F.%p>, i.e. the I<lockfile> does not necessarily lie besides
the locked file (which could even be missing).

When locking, the locking format can be specified to supersede the object
configuration itself.

=item I<hold>

Maximum amount of seconds we may hold a lock. Past that amount of time,
an existing I<lockfile> is removed, being taken for a stale lock. Default
is 3600 seconds. Specifying 0 prevents any forced unlocking.

=item I<max>

Amount of times we retry locking when the file is busy, sleeping I<delay>
seconds between attempts. Defaults to 30.

=item I<nfs>

A boolean flag, false by default. Setting it to true means we could lock
over NFS and therefore the hostname must be included along with the process
ID in the stamp written to the lockfile.

=item I<stale>

A boolean flag, false by default. When set to true, we attempt to detect
stale locks and break them if necessary.

=item I<wafter>

Stands for I<warn after>. It is the number of seconds past the first
warning during locking time after which a new warning should be emitted.
See I<warn> and I<wmin> below. Default is 20.

=item I<warn>

A boolean flag, true by default. To suppress any warning, set it to false.

=item I<wfunc>

A function pointer to dereference when a warning is to be issued. By default,
it redirects to the logwarn() routine if you have Log::Agent installed,
to Perl's warn() function otherwise.

You may set it explicitely to C<\&LockFile::Simple::core_warn> to force the
use of Perl's warn() function, or to C<undef> to suppress logging.

=item I<wmin>

The minimal amount of time when waiting for a lock after which a first
warning must be emitted, if I<warn> is true. After that, a warning will
be emitted every I<wafter> seconds. Defaults to 15.

=back

Each of those configuration attributes can be queried on the object directly:

    $obj = LockFile::Simple->make(-nfs => 1);
    $on_nfs = $obj->nfs;

Those are pure query routines, i.e. you cannot say:

    $obj->nfs(0);                  # WRONG
    $obj->configure(-nfs => 0);    # Right

to turn of the NFS attribute. That is because my OO background chokes
at having querying functions with side effects.

=head1 INTERFACE

The OO interface documented below specifies the signature and the
semantics of the operations. Only the C<lock>, C<trylock> and
C<unlock> operation can be imported and used via a non-OO interface,
with the exact same signature nonetheless.

The interface contains all the attribute querying routines, one for
each configuration parmeter documented in the B<CUSTOMIZING> section
above, plus, in alphabetical order:

=over 4

=item configure(I<-key =E<gt> value, -key2 =E<gt> value2, ...>)

Change the specified configuration parameters and silently ignore
the invalid ones.

=item lock(I<file>, I<format>)

Attempt to lock the file, using the optional locking I<format> if
specified, otherwise using the default I<format> scheme configured
in the object, or by simply appending the I<ext> extension to the file.

If the file is already locked, sleep I<delay> seconds before retrying,
repeating try/sleep at most I<max> times. If warning is configured,
a first warning is emitted after waiting for I<wmin> seconds, and
then once every I<wafter> seconds, via  the I<wfunc> routine.

Before the first attempt, and if I<hold> is non-zero, any existing
I<lockfile> is checked for being too old, and it is removed if found
to be stale. A warning is emitted via the I<wfunc> routine in that
case, if allowed.

Likewise, if I<stale> is non-zero, a check is made to see whether
any locking process is still around (only if the lock holder is on the
same machine when NFS locking is configured). Should the locking
process be dead, the I<lockfile> is declared stale and removed.

Returns a lock handle if the file has been successfully locked, which
does not necessarily needs to be kept around. For instance:

    $obj->lock('ppp', '/var/run/ppp.%p');
    <do some work>
    $obj->unlock('ppp');

or, using OO programming:

    my $lock = $obj->lock('ppp', '/var/run/ppp.%p') ||;
        die "Can't lock for ppp\n";
    <do some work>
    $lock->relase;   # The only method defined for a lock handle

i.e. you don't even have to know which file was locked to release it, since
there is a lock handle right there that knows enough about the lock parameters.

=item lockfile(I<file>, I<format>)

Simply compute the path of the I<lockfile> that would be used by the
I<lock> procedure if it were passed the same parameters.

=item make(I<-key =E<gt> value, -key2 =E<gt> value2, ...>)

The creation routine for the simple lock object. Returns a blessed hash
reference.

=item trylock(I<file>, I<format>)

Same as I<lock> except that it immediately returns false and does not
sleep if the to-be-locked file is busy, i.e. already locked. Any
stale locking file is removed, as I<lock> would do anyway.

Returns a lock hande if the file has been successfully locked.

=item unlock(I<file>)

Unlock the I<file>.

=back

=head1 BUGS

The algorithm is not bullet proof.  It's only reasonably safe.  Don't bet
the integrity of a mission-critical database on it though.

The sysopen() call should probably be used with the C<O_EXCL|O_CREAT> flags
to be on the safer side. Still, over NFS, this is not an atomic operation
anyway.

B<BEWARE>: there is a race condition between the time we decide a lock is
stale or too old and the time we unlink it. Don't use C<-stale> and set
C<-hold> to 0 if you can't bear with that idea, but recall that this race
only happens when something is already wrong. That does not make it right,
nonetheless. ;-)

=head1 AUTHOR

Raphael Manfredi F<E<lt>Raphael_Manfredi@pobox.comE<gt>>

=head1 SEE ALSO

File::Flock(3).

=cut

