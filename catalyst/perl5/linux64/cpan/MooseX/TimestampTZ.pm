
package MooseX::TimestampTZ;

=head1 NAME

MooseX::Timestamp - simple timestamp type for Moose, with Time Zone

=head1 SYNOPSIS

 # specify importing, specifying
 use MooseX::TimestampTZ qw(:all);

 print zone 0;       # +0000
 print zone 0, 1;    # Z
 print zone 12*3600; # +1200

 print offset_s "Z";     # 0
 print offset_s "+1200"; # 43200   (= 12 * 3600)

 # local times
 print timestamptz;   # 2007-12-06 23:23:22+1300
 print timestamptz 0; # 1970-01-01 12:00:00+1200

 # UTC times
 print gmtimestamptz;     # 2007-12-06 10:23:22+0000
 print gmtimestamptz 0;   # 1970-01-01 00:00:00+0000

 # conversion the other way
 print epoch "1970-01-01 00:00:00+0000"; # 0
 print epoch "1970-01-01 12:00:00+1200"; # 0

 print for epochtz "1970-01-01 12:00:00+1200"; # 0, 43200

 # you can get these ISO forms if you want, too.  functions
 # that take a timestamptz accept either
 package SomewhereElse;
 use MooseX::TimestampTZ gmtimestamptz => { use_z => 1 };
 print gmtimestamptz 0;   # 1970-01-01 00:00:00Z

 package MyClass;
 use Moose;
 has 'stamp' =>
         isa => "Timestamp",
         is => "rw",
         coerce => 1;

 package main;
 my $obj = MyClass->new(stamp => "2007-01-02 12:00:12"); # ok
 $obj->stamp("2007-01-02 12:01");
 $obj->stamp("2007-01-02 12");
 $obj->stamp("2007-01-02 12:00:00Gibbons");  #fail

=head1 DESCRIPTION

This module provides floating dates on the Gregorian calendar without
much code.  It operates in (one particular variant of) ISO-8601 date
format with time zone, and epoch times.  Sub-second resolution is not
yet supported.

=cut

use strict;
use warnings;
use Carp;
use MooseX::Timestamp qw(:all);
use Moose::Util::TypeConstraints;

sub _curry {
	my $class = shift;
	my $name = shift;
	my $arg_h = shift;
	my $col_h = shift;

	if ( defined $arg_h->{use_z} or defined $col_h->{defaults}{use_z} ) {
		my $use_z = defined $arg_h->{use_z} ?
			$arg_h->{use_z} : $col_h->{defaults}{use_z};
		my $code = \&$name;
		sub { $code->($_[0], $use_z) };
	}
	else {
		\&$name;
	}
}

use Sub::Exporter -setup =>
	{ exports =>
	  [ qw(offset_s epoch timestamp posixtime epochtz),
	    map { ($_ => \&_curry) } qw(zone timestamptz gmtimestamptz),
	  ],
	  groups =>
	  { default => [ qw(timestamptz gmtimestamptz epoch) ] },
	  collectors => { defaults => sub {
				  1;
			  } },
	};

subtype "TimestampTZ"
	=> as "Str"
	=> where {
		m{^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:[\-+]\d{4}|Z)$}
			and do {
				my $x;
				eval { $x = epoch($_) };
				warn "Error: $@ on $_" if $@;
				!$@
			};
	};

use Time::Local;
use Memoize;
memoize qw(zone);
sub zone {
	my $offset_s = shift;
	my $use_z = shift;
	if ( $use_z and $offset_s == 0 ) {
		"Z";
	}
	else {
		my $hh = sprintf("%.2d", int(abs($offset_s)/3600));
		my $mm = sprintf("%.2d", int((abs($offset_s)-$hh*3600)/60));
		my $s = ( $offset_s >= 0 ? "+" : "-" );
		"$s$hh$mm";
	}
}

sub offset_s {
	my $zone = shift or croak "no zone passed to offset_s!";
	if ( $zone eq "Z" ) {
		return 0;
	}
	elsif ( $zone =~ m{^([\-+])(\d{2}):?(\d{2})?$}) {
		return ( ($1 eq "-" ? -1 : 1) *
			 (($2 * 60) + ($3||0)) * 60 );
	}
	else {
		croak "no timezone on '$zone'";
	}
}

sub timestamptz {
	my $time = shift;
	defined($time)||($time = time);
	my $use_z = shift;
	my @lt = localtime($time);
	my $offset_s = timegm(@lt) - $time;
	timestamp(@lt).zone($offset_s, $use_z);
}

sub gmtimestamptz {
	my $time = shift;
	defined($time)||($time = time);
	my $use_z = shift;
	my @gt = gmtime($time);
	timestamp(@gt).zone(0, $use_z);
}

sub epochtz {
	my $timestamptz = shift || timestamptz;
	my ($timestamp, $zone) =
		($timestamptz =~ m{^(.*)([\-+]\d{2}(?::?\d{2})?|Z)$}x)
		or die "bad TimestampTZ passed to epoch: '$timestamptz'";
	my @wct = posixtime($timestamp);
	my $offset_s = offset_s($zone);
	(timegm(@wct) - $offset_s, $offset_s);
}

sub epoch {
	return time unless @_;
	return (epochtz(@_))[0];
}

subtype 'time_t'
	=> as "Int";

sub _looks_like_timestamp {
	my $epoch;
	if ( eval { defined($epoch = epoch($_)) } and !$@ ) {
		$epoch;
	}
	elsif ( eval { valid_posixtime(posixtime($_)) } and !$@ ) {
		timelocal(posixtime($_));
	}
	else {
		croak "bad TimestampTZ $_";
	}
}

coerce 'time_t'
	=> from "Int"
	=> via { $_ },
	=> from "TimestampTZ"
	=> via { epoch($_) }
	=> from "Str"
	=> via \&_looks_like_timestamp;

coerce 'Timestamp'
	=> from "TimestampTZ"
	=> via { timestamp(localtime(epoch($_))) };

# traditionally, coercing a timestamp to one with time zone and back
# uses the local time, with the resultant ambiguities
coerce 'TimestampTZ'
	=> from "TimestampTZ"
	=> via { $_ },
	=> from "time_t"
	=> via { timestamptz($_) }
	=> from "Timestamp"
	=> via { timestamptz(timelocal(posixtime($_))) },
	=> from "Str"
	=> via { timestamptz _looks_like_timestamp };

=head1 FUNCTIONS

The following functions are available for import.  If you want to
import them all, use the C<:all> import group, as below:

  use MooseX::TimestampTZ qw(:all);

=head2 zone(Int $offset, Bool $use_z = false)

Returns the timezone of the given offset.  Pass $use_z to select
returning "Z" as a timezone if the offset is 0.

=head2 offset_s(Str)

Returns the offset corresponding to the given timezone.  Does NOT
accept nicknames like "EST", etc (which EST did you mean, US or
Australian Eastern Standard Time?).

=head2 timestamptz(time_t $time_t = time(), Bool $use_z = false)

Returns the passed epoch time as a valid TimestampTZ, according to the
local time zone rules in effect.  C<$use_z> functions as with C<zone>.

=head2 gmtimestamptz(time_t $time_t = time(), Bool $use_z = false)

Returns the passed epoch time as a valid TimestampTZ, corresponding to
the time in UTC.  C<$use_z> functions as with C<zone>, and if passed
this function will always return TimestampTZs ending with C<Z>.

=head2 epoch()

Synonym for the built-in C<time()>.

=head2 epoch(TimestampTZ)

Converts the passed TimestampTZ value to an epoch time.  Does B<not>
perform any coercion - the passed value must already have a time zone
on it.  You may omit any part of the time, specify the time zone in
hours or with a C<Z>, and optionally separate your time from your date
with a C<T>.  Single digit values for fields are accepted.

Example valid forms:

  2007-12-07 16:34:02+1200
  2007-12-07 16:34+12
  2007-12-07 04Z
  2007-12-7T4Z
  2007-12-7+12
  2007120704:12:32    # Date::Manip format

Examples of ISO-8601 valid forms which are not currently accepted:

  07-12-07Z
  071207Z
  20071207Z           # seperators required
  2007120704Z
  -12-07Z             # no year specified

No locale-specific date forms, such as C</> delimited dates, are
accepted.

=head2 epochtz(...)

Just like C<epoch()>, except returns the timezone as well.

=head1 TYPES AND COERCIONS

The following subtypes are defined by this module:

=head2 TimestampTZ

This is a subtype of C<Str> which conforms to one of the two
normalized forms of a TimestampTZ (either with a Z, or without).

Rules exist to coerce C<Str>, C<Timestamp> and C<time_t> to this type,
and are available by using the C<coerce =E<gt> 1> flag on a Moose
attribute declaration:

  package Widget;
  use MooseX::TimestampTZ;
  has 'created' =>
          isa => TimestampTZ,
          is => "rw",
          coerce => 1;

With the above, if you set C<created> to a time_t value, it will
automatically get converted into a TimestampTZ in the current time
zone.

=head2 time_t

C<time_t> is a nicer way of writing an epoch time.  If you set
C<coerce =E<gt> 1> on your accessors, then you can happily pass in
timestamps.

=head1 EXPORTS

The default exporting action of this module is to export the
C<timestamptz>, C<gmtimestamptz> and C<epoch> methods.  To avoid this,
pass an empty argument list to the use statement:

  use MooseX::TimestampTZ ();

=head2 ISO-8601 "Z" TIMEZONE

Several of the functions which return a timezone may be told to return
"Z" if the offset is 0, that is, the time is in UTC.  To select this,
pass a true second argument to any of the three functions (C<zone>,
C<timestamptz> and C<gmtimestamptz>), or curry them on import;

 use MooseX::TimestampTZ qw(:default), defaults => { use_z => 1 };

You can also curry individual functions like this:

 use MooseX::TimestampTZ zone => { use_z => 1 };

=cut

=head1 BUGS

This module is relatively slow, as conversions and calls to C<timegm>
and friends happen far too often, really - especially with coercion.

=head1 AUTHOR AND LICENSE

Sam Vilain, <samv@cpan.org>

Copyright 2007, Sam Vilain.  All Rights Reserved.  This program is
Free Software; you may use it and/or redistribute it under the terms
of Perl itself.

=cut

1;
