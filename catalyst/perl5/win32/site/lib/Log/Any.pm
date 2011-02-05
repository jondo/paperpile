package Log::Any;
use strict;
use warnings;

our $VERSION = '0.11';

# Require rather than use, because it depends on subroutines defined below
#
require Log::Any::Adapter::Null;

# This is accessed in Log::Any::Adapter::Manager::new
#
our %NullAdapters;

sub import {
    my $class  = shift;
    my $caller = caller();

    my @export_params = ( $caller, @_ );
    $class->_export_to_caller(@export_params);
}

sub _export_to_caller {
    my $class  = shift;
    my $caller = shift;

    # Parse parameters passed to 'use Log::Any'
    #
    my @vars;
    foreach my $param (@_) {
        if ( $param eq '$log' ) {
            my $log = $class->get_logger( category => $caller );
            no strict 'refs';
            my $varname = "$caller\::log";
            *$varname = \$log;
        }
        else {
            die "invalid import '$param' - valid imports are '\$log'";
        }
    }
}

sub get_logger {
    my ( $class, %params ) = @_;

    my $category = delete( $params{'category'} );
    if ( !defined($category) ) {
        $category = caller();
    }
    if ($Log::Any::Adapter::Initialized) {
        return Log::Any::Adapter->get_logger( $category, %params );
    }
    else {

        # Record each null adapter that we return, so that we can override
        # them later if and when Log::Any::Adapter->set is called
        #
        $NullAdapters{$category} ||= Log::Any::Adapter::Null->new();
        return $NullAdapters{$category};
    }
}

my ( %log_level_aliases, @logging_methods, @logging_aliases, @detection_methods,
    @detection_aliases, @logging_and_detection_methods );

BEGIN {
    %log_level_aliases = (
        inform => 'info',
        warn   => 'warning',
        err    => 'error',
        crit   => 'critical',
        fatal  => 'critical'
    );
    @logging_methods =
      qw(trace debug info notice warning error critical alert emergency);
    @logging_aliases               = keys(%log_level_aliases);
    @detection_methods             = map { "is_$_" } @logging_methods;
    @detection_aliases             = map { "is_$_" } @logging_aliases;
    @logging_and_detection_methods = ( @logging_methods, @detection_methods );
}

sub log_level_aliases             { %log_level_aliases }
sub logging_methods               { @logging_methods }
sub logging_aliases               { @logging_aliases }
sub detection_methods             { @detection_methods }
sub detection_aliases             { @detection_aliases }
sub logging_and_detection_methods { @logging_and_detection_methods }

# For backward compatibility
sub set_adapter {
    my $class = shift;
    require Log::Any::Adapter;
    Log::Any::Adapter->set(@_);
}

1;

__END__

=pod

=head1 NAME

Log::Any -- Bringing loggers and listeners together

=head1 SYNOPSIS

In a CPAN or other module:

    package Foo;
    use Log::Any qw($log);

    $log->error("an error occurred");
    $log->debugf("arguments are: %s", \@_)
        if $log->is_debug();

    my $log2 = Log::Any->get_logger(category => 'My::Class');

In your application:

    use Log::Any::Adapter;
    
    # Send all logs to Log::Log4perl
    Log::Any::Adapter->set('Log4perl');

    # Send all logs to Log::Dispatch
    my $log = Log::Dispatch->new(outputs => [[ ... ]]);
    Log::Any::Adapter->set( 'Dispatch', dispatcher => $log );

    # See Log::Any::Adapter documentation for more options

=head1 DESCRIPTION

C<Log::Any> allows CPAN modules to safely and efficiently log messages, while
letting the application choose (or decline to choose) a logging mechanism such
as C<Log::Dispatch> or C<Log::Log4perl>.

C<Log::Any> has a very tiny footprint and no dependencies beyond Perl 5.6,
which makes it appropriate for even small CPAN modules to use. It defaults to
'null' logging activity, so a module can safely log without worrying about
whether the application has chosen (or will ever choose) a logging mechanism.

The application, in turn, may choose one or more logging mechanisms via
L<Log::Any::Adapter|Log::Any::Adapter>.

=head1 LOG LEVELS

C<Log::Any> supports the following log levels and aliases, which is meant to be
inclusive of the major logging packages:

     trace
     debug
     info (inform)
     notice
     warning (warn)
     error (err)
     critical (crit, fatal)
     alert
     emergency

Levels are translated as appropriate to the underlying logging mechanism. For
example, log4perl only has six levels, so we translate 'notice' to 'info' and
the top three levels to 'fatal'.

=head1 CATEGORIES

Every logger has a category, generally the name of the class that asked for the
logger. Some logging mechanisms, like log4perl, can direct logs to different
places depending on category.

=head1 PRODUCING LOGS (FOR MODULES)

=head2 Getting a logger

The most convenient way to get a logger in your module is:

    use Log::Any qw($log);

This creates a package variable I<$log> and assigns it to the logger for the
current package. It is equivalent to

    our $log = Log::Any->get_logger(category => __PACKAGE__);

In general, to get a logger for a specified category:

    my $log = Log::Any->get_logger(category => $category)

If no category is specified, the caller package is used.

=head2 Logging

To log a message, use any of the log levels or aliases. e.g.

    $log->error("this is an error");
    $log->warn("this is a warning");
    $log->warning("this is also a warning");

You should B<not> include a newline in your message; that is the responsibility
of the logging mechanism, which may or may not want the newline.

There are also printf-style versions of each of these methods:

    $log->errorf("an error occurred: %s", $@);
    $log->debugf("called with %d params: %s", $param_count, \@params);

The printf-style methods have a few advantages, besides being arguably more
readable:

=over

=item *

Any complex references (like C<\@params> above) are automatically converted to
single-line strings with C<Data::Dumper>.

=item *

Any undefined values are automatically converted to the string "<undef>".

=item *

A logging mechanism could potentially use the unchanging format string (or a
digest thereof) to group related log messages together.

=back

=head2 Log level detection

To detect whether a log level is on, use "is_" followed by any of the log
levels or aliases. e.g.

    if ($log->is_info()) { ... }
    $log->debug("arguments are: " . Dumper(\@_))
        if $log->is_debug();

This is important for efficiency, as you can avoid the work of putting together
the logging message (in the above case, stringifying C<@_>) if the log level is
not active.

Some logging mechanisms don't support detection of log levels. In these cases
the detection methods will always return 1.

In contrast, the default logging mechanism - Null - will return 0 for all
detection methods.

=head2 Testing

L<Log::Any::Test|Log::Any::Test> provides a mechanism to test code that uses
C<Log::Any>.

=head1 CONSUMING LOGS (FOR APPLICATIONS)

To direct logs somewhere - a file, the screen, etc. - you must use
L<Log::Any::Adapter|Log::Any::Adapter>. This is intentionally kept in a
separate distributions to keep C<Log::Any> as simple and unchanging as
possible.

=head1 MOTIVATION

Many modules have something interesting to say. Unfortunately there is no
standard way for them to say it - some output to STDERR, others to C<warn>,
others to custom file logs. And there is no standard way to get a module to
start talking - sometimes you must call a uniquely named method, other times
set a package variable.

This being Perl, there are many logging mechanisms available on CPAN.  Each has
their pros and cons. Unfortunately, the existence of so many mechanisms makes
it difficult for a CPAN author to commit his/her users to one of them. This may
be why many CPAN modules invent their own logging or choose not to log at all.

To untangle this situation, we must separate the two parts of a logging API.
The first, I<log production>, includes methods to output logs (like
C<$log-E<gt>debug>) and methods to inspect whether a log level is activated
(like C<$log-E<gt>is_debug>). This is generally all that CPAN modules care
about. The second, I<log consumption>, includes a way to configure where
logging goes (a file, the screen, etc.) and the code to send it there. This
choice generally belongs to the application.

C<Log::Any> provides a standard log production API for modules.
C<Log::Any::Adapter> allows applications to choose the mechanism for log
consumption.

See http://www.openswartz.com/2007/09/06/standard-logging-api/ for the original
post proposing this module.

=head1 Q & A

=over

=item Isn't Log::Any just yet another logging mechanism?

No. C<Log::Any> does not, and never will, include code that knows how to log to
a particular place (file, screen, etc.) It can only forward logging requests to
another logging mechanism.

=item Why don't you just pick the best logging mechanism, and use and promote it?

Each of the logging mechanisms have their pros and cons, particularly in terms
of how they are configured. For example, log4perl offers a great deal of power
and flexibility but uses a global and potentially heavy configuration, whereas
C<Log::Dispatch> is extremely configuration-light but doesn't handle
categories. There is also the unnamed future logger that may have advantages
over either of these two, and all the custom in-house loggers people have
created and cannot (for whatever reason) stop using.

=item Is it safe for my critical module to depend on Log::Any?

Our intent is to keep C<Log::Any> minimal, and change it only when absolutely
necessary. Most of the "innovation", if any, is expected to occur in
C<Log::Any::Adapter>, which your module should not have to depend on (unless it
wants to direct logs somewhere specific). C<Log::Any> has no module
dependencies other than L<Test::Simple|Test::Simple> for testing.

=item Why doesn't Log::Any use I<insert modern Perl technique>?

To encourage CPAN module authors to adopt and use C<Log::Any>, we aim to have
as few dependencies and chances of breakage as possible. Thus, no C<Moose> or
other niceties.

=back

=head1 AUTHOR

Jonathan Swartz

=head1 SEE ALSO

L<Log::Any::Adapter|Log::Any::Adapter>; the many Log:: modules on CPAN

=head1 COPYRIGHT & LICENSE

Copyright (C) 2009 Jonathan Swartz.

Log::Any is provided "as is" and without any express or implied warranties,
including, without limitation, the implied warranties of merchantibility and
fitness for a particular purpose.

This program is free software; you canredistribute it and/or modify it under
the same terms as Perl itself.

=cut
