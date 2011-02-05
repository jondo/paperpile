
package MooseX::Timestamp;

our $VERSION = '0.07';

=head1 NAME

MooseX::Timestamp - simple timestamp type for Moose

=head1 SYNOPSIS

 use MooseX::Timestamp;

 print timestamp;          # 2007-12-06 23:15:42
 print timestamp 0;        # 1970-01-01 12:00:00
 print timestamp 0.0001;   # 1970-01-01 12:00:00.0001
 print timestamp gmtime 0; # 1970-01-01 00:00:00

 use POSIX qw(strftime);
 print strftime("%a", posixtime "2007-12-06 23:15"); # Thu

 #...

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

This module provides a timestamp type as a Str subtype for Moose.
This is a much more lightweight format than, say, L<DateTime>, with
the disadvantage that it does not support native operations on the
dates.

This module provides floating dates on the Gregorian calendar without
much code.  It operates in (one or two particular variants of)
ISO-8601 date format, and POSIX-style 6-number lists.

Note: you probably want the functions provided by MooseX::TimestampTZ
most of the time, as they deal in unix epoch times.

=cut

use Moose::Util::TypeConstraints;
my @exports;
use Sub::Exporter -setup =>
	{ exports => [ qw(timestamp posixtime valid_posixtime) ],
	  groups => { default => [qw(timestamp posixtime)] },
	};
use Carp;

#use MooseX::Timestamp::__version;

subtype Timestamp
    => as Str
    => where {
	    m{^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(\.\d+)?$} and
		    eval { valid_posixtime(posixtime($_)) };
    };

use POSIX qw(strftime);
sub timestamp {
	if ( @_ == 0 ) {
		@_ = time;
	}
	if ( @_ == 1 ) {
		my $time = shift;
		my $frac = $time - int($time);
		@_ = localtime(int($time));
		$_[0] += $frac;
	}
	valid_posixtime(@_);
	if ( int($_[0]) == $_[0] ) {
		strftime("%Y-%m-%d %H:%M:%S", @_ ),
	}
	else {
		# microseconds only.  Any more and you start seeing FP
		# precision weirdness a lot more than you'd expect.
		my $sec = sprintf("%.6f", $_[0]);
		$sec =~ s{0+$}{};
		join(
			"",
			strftime("%Y-%m-%d %H:%M:", @_ ),
			($_[0]<10)?("0"):(),
			$sec,
		       );
	}
}

my @short = qw(0 1 0 1 0 1 0 0 1 0 1 0);
sub valid_posixtime {
	my @lt = @_;
	croak "invalid month ".($lt[4]+1) if $lt[4]<0 or $lt[4]>11;
	croak "invalid day $lt[3]" if !$lt[3] or $lt[3]>31 or
		(($lt[3]==31 and $short[$lt[4]]) or
		 ($lt[3] > 28 and $lt[4] == 1 and
		  !($lt[3] == 29 and
		    (($lt[5]%4) == 0 and
		     ($lt[5]%100 != 0 or ($lt[5]+300)%400 == 0)))));
	croak "invalid hour $lt[2]" if $lt[2]<0 or $lt[2]>23;
	croak "invalid minute $lt[1]" if $lt[1]<0 or $lt[1]>59;
	croak "invalid second $lt[0]"
		if ($lt[0]<0 or $lt[0]>=61 or ($lt[0]>=60 and $lt[1]!=59));
	1;
}

sub posixtime {
	return localtime time unless @_;
	my @lt = ($_[0] =~ m{^(\d{4})(-\d{1,2}|\d{2})(-\d{1,2}|\d{2})T?
			     \s*(?:(\d{1,2})
				     (?::(\d{2})
					     (?::(\d{2}(?:\.\d+)?))?
				     )?
			     )?$}x)
		or croak "bad timestamp '$_[0]'";
	$lt[1]=abs($lt[1]);
	$lt[2]=abs($lt[2]);
	$lt[0]-=1900;
	$lt[1]--;
	$_ ||= 0 for (@lt[3..5]);
	reverse(@lt);
}

coerce Timestamp
	=> from Timestamp
	=> via { $_ },
	=> from Str
	=> via { timestamp posixtime $_ };

=head1 FUNCTIONS

The following functions are available for import.  If you want to
import them all, use the C<:all> import group, as below:

  use MooseX::Timestamp qw(:all);

=head2 timestamp(time_t $time = time())

=head2 timestamp(@posixtime)

Converts from a POSIX-style array of time components, or an epoch
time, into a Timestamp.  If an epoch time is passed, the local
timezone rules are used for conversion into a wallclock time.  See
L<TimestampTZ/timestamptz> for a version which returns the time zone
as well.

=head2 posixtime()

Alias for the built-in C<localtime>; this will not return a hi-res
time unless one is passed in.

=head2 posixtime(Timestamp)

Converts a Timestamp into a POSIX-style array of time components.
They are B<NOT> guaranteed to be valid.

This accepts a similar set of input values to C<TimestampTZ::epoch>;
see its documentation (L<TimestampTZ/epoch>) for a list.  The defining
difference is that Timestamps passed into this function MUST NOT have
a time zone (or "Z") attached.

=head2 valid_posixtime(@posixtime)

This function croaks with an error if the passed POSIX-style array of
time components are found to be out of range in any way.  This
function contains leap year rules and passes through leap seconds.

=head1 TYPES AND COERCIONS

One type is defined by this module.

=head2 Timestamp

This is a subtype of C<Str> which conforms to the normalized form of a
Timestamp.

Rules exist to coerce C<Str> objects to this type, and are available
by using the C<coerce =E<gt> 1> flag on a Moose attribute declaration:

  package Widget;
  use MooseX::Timestamp;
  has 'created' => (
          isa => Timestamp,
          is => "rw",
          coerce => 1,
          );

  package main;
  my $widget = new Widget;
  $widget->created("2007-12-07");
  print $widget->created;  # 2007-12-07 00:00:00

With the above, if you set C<created> to a value such as automatically
get converted into a Timestamp in the current time zone.

Timestamps may contain fractional components, but the results of
conversions from floating point are truncated at the microsecond
level.

=head2 EXPORTS

The default exporting action of this module is to export the
C<posixtime> and C<timestamp> methods.  To avoid this, pass an empty
argument list to the use statement:

  use MooseX::Timestamp ();

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
