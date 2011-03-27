package TAP::Formatter::JUnit::Session;

use strict;
use warnings;
use base qw(TAP::Formatter::Console::Session);
use Class::Field qw(field);
use Storable qw(dclone);
use File::Path qw(mkpath);
use IO::File;

field 'testcases'   => [];
field 'system_out'  => '';
field 'system_err'  => '';
field 'passing_todo_ok' => 0;

###############################################################################
# Subroutine:   _initialize($arg_for)
###############################################################################
# Custom initializer, so we can accept a new "passing_todo_ok" argument at
# instantiation time.
sub _initialize {
    my ($self, $arg_for) = @_;
    $arg_for ||= {};

    my $passing_todo_ok = delete $arg_for->{passing_todo_ok};
    $self->passing_todo_ok($passing_todo_ok);

    return $self->SUPER::_initialize($arg_for);
}

###############################################################################
# Subroutine:   result($result)
###############################################################################
# Called by the harness for each line of TAP it receives.
#
# Internally, all of the TAP is added to a queue until we hit the start of the
# "next" test (at which point we flush the queue.  This allows us to capture any
# error output or diagnostic info that comes after a test failure.
sub result {
    my ($self, $result) = @_;

    # add the raw output
    $self->{system_out} .= $result->raw() . "\n";

    # when we get the next test process the previous one
    $self->_flush_queue if ($result->is_test && $self->{_junit_queue});

    # except for a few things we don't want to process as a "test case", add
    # the test result to the queue.
    unless (    ($result->raw() =~ /^# Looks like you failed \d+ tests? of \d+/)
             || ($result->raw() =~ /^# Looks like you planned \d+ tests? but ran \d+/)
             || ($result->raw() =~ /^# Looks like your test died before it could output anything/)
           ) {
        push @{$self->{_junit_queue} ||= []}, $result;
    }

    # track the last time we saw a test/plan, so we can calculate how long it
    # takes to run individual tests.
    if ($result->is_test || $result->is_plan) {
        $self->{_junit_t_last_test} = $self->get_time();
    }
}

###############################################################################
# Subroutine:   close_test()
###############################################################################
# Called to close the test session.
#
# Flushes the queue if we've got anything left in it, dumps the JUnit to disk
# (if necessary), and adds the XML for this test suite to our formatter.
sub close_test {
    my $self   = shift;
    my $xml    = $self->xml();
    my $parser = $self->parser();

    # flush out the queue, in case we've got more test results to add
    $self->_flush_queue;

    # if the test died unexpectedly, make note of that
    my $die_msg;
    my $exit = $parser->exit();
    if ($exit) {
        my $sys_err = $self->system_err;
        my $wstat   = $parser->wait();
        my $status  = sprintf( "%d (wstat %d, 0x%x)", $exit, $wstat, $wstat );
        $die_msg  = "Dubious, test returned $status";
        $sys_err .= "$die_msg\n";
        $self->system_err($sys_err);
    }

    # add system-out/system-err data, as raw CDATA
    my $sys_out = 'system-out';
    $sys_out = $xml->$sys_out($self->system_out() ? $self->_cdata($self->system_out) : undef);

    my $sys_err = 'system-err';
    $sys_err = $xml->$sys_err($self->system_err() ? $self->_cdata($self->system_err) : undef);

    # update the testsuite with aggregate info on this test suite
    #
    # tests     - total number of tests run
    # time      - wallclock time taken for test run (floating point)
    # failures  - number of tests that we detected as failing
    # errors    - number of errors:
    #               - passing TODOs
    #               - if a plan was provided, mismatch between that and the
    #                 number of actual tests that were run
    #               - either "no plan was issued" or "test died" (a dying test
    #                 may not have a plan issued, but should still be considered
    #                 a single error condition)
    my $testsrun = $parser->tests_run() || 0;
    my $time     = $self->formatter->timer ? $self->_time_taken() : undef;
    my $failures = $parser->failed();

    my $noplan   = $parser->plan() ? 0 : 1;
    my $planned  = $parser->tests_planned() || 0;

    my $num_errors = 0;
    $num_errors += $parser->todo_passed() unless $self->passing_todo_ok();
    $num_errors += abs($testsrun - $planned) if ($planned);

    my $suite_err;
    if ($die_msg) {
        $suite_err = $xml->error( { message => $die_msg } );
        $num_errors ++;
    }
    elsif ($noplan) {
        $suite_err = $xml->error( { message => 'No plan in TAP output' } );
        $num_errors ++;
    }
    elsif ($planned && ($testsrun != $planned)) {
        $suite_err = $xml->error( { message => "Looks like you planned $planned tests but ran $testsrun." } );
    }

    my @tests = @{$self->testcases()};
    my %attrs = (
        'name'      => _get_testsuite_name($self),
        'tests'     => $testsrun,
        (defined $time ? ('time'=>$time) : ()),
        'failures'  => $failures,
        'errors'    => $num_errors,
    );
    my $testsuite = $xml->testsuite(\%attrs, @tests, $sys_out, $sys_err, $suite_err);
    $self->formatter->add_testsuite($testsuite);
    $self->dump_junit_xml($testsuite);
}

###############################################################################
# Subroutine:   dump_junit_xml($testsuite)
###############################################################################
# Dumps the JUnit for the given XML '$testsuite', to the directory specified by
# 'PERL_TEST_HARNESS_DUMP_TAP'.
sub dump_junit_xml {
    my ($self, $testsuite) = @_;
    if (my $spool_dir = $ENV{PERL_TEST_HARNESS_DUMP_TAP}) {
        my $spool = File::Spec->catfile($spool_dir, $self->name() . '.junit.xml');

        # clone the testsuite; XML::Generator only lets us auto-vivify the
        # CDATA sections *ONCE*.
        $testsuite = dclone($testsuite);

        # create target dir
        my ($vol, $dir, undef) = File::Spec->splitpath($spool);
        my $path = File::Spec->catpath($vol, $dir, '');
        mkpath($path);

        # create JUnit XML, and dump to disk
        my $junit = $self->xml->xml($self->xml->testsuites($testsuite) );
        my $fout  = IO::File->new( $spool, '>:utf8' )
            || die "Can't write $spool ( $! )\n";
        $fout->print($junit);
        $fout->close();
    }
}

###############################################################################
# Subroutine:   add_testcase($case)
###############################################################################
# Adds an XML test '$case' to the list of testcases we've run in this session.
sub add_testcase {
    my ($self, $case) = @_;
    push @{$self->{testcases}}, $case;
}

###############################################################################
# Subroutine:   xml()
###############################################################################
# Returns a new 'XML::Generator' to generate XML output.  This is simply a
# shortcut to '$self->formatter->xml()'.
sub xml {
    my $self = shift;
    return $self->formatter->xml();
}

###############################################################################
# Subroutine:   xml_unescape()
###############################################################################
# Returns a new 'XML::Generator' to generate unescaped XML output.  This is
# simply a shortcut to '$self->formatter->xml_unescape()'.
sub xml_unescape {
    my $self = shift;
    return $self->formatter->xml_unescape();
}

###############################################################################
# Calculate the time taken to parse the current test session.
sub _time_taken {
    my $self = shift;
    my $t_st = $self->parser->start_time();
    my $t_en = $self->parser->end_time();
    my $t_diff = $t_en - $t_st;
    return $t_diff;
}

###############################################################################
# Calculate the time taken since the last test was seen in the TAP output.
sub _time_since_last_test {
    my $self = shift;
    my $t_st = $self->{_junit_t_last_test} || $self->parser->start_time();
    my $t_en = $self->get_time();
    my $diff = $t_en - $t_st;
    my $ret  = $self->{_junit_t_since_last_test} || 0;
    $self->{_junit_t_since_last_test} = $diff;
    return $ret;
}

###############################################################################
# Flushes the queue of test results, item by item.
sub _flush_queue {
    my $self = shift;
    my $queue = $self->{_junit_queue} ||= [];
    $self->_flush_item while @$queue;
}

###############################################################################
# Flushes a single test result item.
#
# If the item being flushed is a "test", grab everything that comes after it as
# context or errors related to that test.
sub _flush_item {
    my $self = shift;
    my $queue = $self->{_junit_queue};

    # get the result
    my $result = shift @$queue;

    # add result to XML
    my $xml = $self->xml();
    if ($result->is_test) {
        my %attrs = (
            'name' => _get_testcase_name($result),
            ($self->formatter->timer ? ('time'=>$self->_time_since_last_test) : ()),
            );

        # slurp in all the content up to the next test
        my @content = $result->as_string();
        while (@{$queue}) {
            my $followup = shift @{$queue};
            push @content, $followup->as_string();
        }

        # check for bogosity
        my $bogosity;
        if ($result->todo_passed() && !$self->passing_todo_ok()) {
            $bogosity = {
                level   => 'error',
                type    => 'TodoTestSucceeded',
                message => $result->explanation(),
            };
        }
        elsif ($result->is_unplanned()) {
            $bogosity = {
                level   => 'error',
                type    => 'UnplannedTest',
                message => $result->as_string(),
            };
        }
        elsif (not $result->is_ok()) {
            $bogosity = {
                level   => 'failure',
                type    => 'TestFailed',
                message => $result->as_string(),
            };
        }

        # create a failure/error element if the test was bogus
        my $failure;
        if ($bogosity) {
            my $cdata = $self->_cdata( join "\n", @content );
            my $level = $bogosity->{level};
            $failure  = $xml->$level( {
                type    => $bogosity->{type},
                message => $bogosity->{message},
                }, $cdata );
        }

        # create the testcase element and add it to the suite.
        my $testcase = $xml->testcase(\%attrs, $failure);
        $self->add_testcase($testcase);
    }
    else {
        # some sort of non-test output; ignore for now.
        #
        # we do, however, need to track the time since the last test, so that
        # timings get calculated properly
        $self->_time_since_last_test();
    }
}

###############################################################################
# Generates the name for a test case.
sub _get_testcase_name {
    my $test = shift;
    my $name = join(' ', $test->number(), _clean_test_description($test));
    $name =~ s/\s+$//;
    return $name;
}

###############################################################################
# Generates the name for the entire test suite.
sub _get_testsuite_name {
    my $self = shift;
    my $name = $self->name;
    $name =~ s{^\./}{};
    $name =~ s{^t/}{};
    return _clean_to_java_class_name($name);
}

###############################################################################
# Cleans up the given string, removing any characters that aren't suitable for
# use in a Java class name.
sub _clean_to_java_class_name {
    my $str = shift;
    $str =~ s/[^-:_A-Za-z0-9]+/_/gs;
    return $str;
}

###############################################################################
# Cleans up the description of the given test.
sub _clean_test_description {
    my $test = shift;
    my $desc = $test->description();
    return _squeaky_clean($desc);
}

###############################################################################
# Creates a CDATA block for the given data (which is made squeaky clean first,
# so that JUnit parsers like Hudson's don't choke).
sub _cdata {
    my ($self, $data) = @_;
    $data = _squeaky_clean($data);
    return $self->xml->xmlcdata($data);
}

###############################################################################
# Clean a string to the point that JUnit can't possibly have a problem with it.
sub _squeaky_clean {
    my $string = shift;
    # control characters (except CR and LF)
    $string =~ s/([\x00-\x09\x0b\x0c\x0e-\x1f])/"^".chr(ord($1)+64)/ge;
    # high-byte characters
    $string =~ s/([\x7f-\xff])/'[\\x'.sprintf('%02x',ord($1)).']'/ge;
    return $string;
}

1;

=head1 NAME

TAP::Formatter::JUnit::Session - Harness output delegate for JUnit output

=head1 DESCRIPTION

C<TAP::Formatter::JUnit::Session> provides JUnit output formatting for
C<TAP::Harness>.

=head1 METHODS

=over

=item B<_initialize($arg_for)>

Over-ridden private initializer, so we can accept a new "passing_todo_ok"
argument at instantiation time.

=item B<result($result)>

Called by the harness for each line of TAP it receives.

Internally, all of the TAP is added to a queue until we hit the start of
the "next" test (at which point we flush the queue. This allows us to
capture any error output or diagnostic info that comes after a test
failure.

=item B<close_test()>

Called to close the test session.

Flushes the queue if we've got anything left in it, dumps the JUnit to disk
(if necessary), and adds the XML for this test suite to our formatter.

=item B<dump_junit_xml($testsuite)>

Dumps the JUnit for the given XML C<$testsuite>, to the directory specified
by C<PERL_TEST_HARNESS_DUMP_TAP>.

=item B<add_testcase($case)>

Adds an XML test C<$case> to the list of testcases we've run in this
session.

=item B<xml()>

Returns a new C<XML::Generator> to generate XML output. This is simply a
shortcut to C<$self-E<gt>formatter-E<gt>xml()>.

=item B<xml_unescape()>

Returns a new C<XML::Generator> to generate unescaped XML output. This is
simply a shortcut to C<$self-E<gt>formatter-E<gt>xml_unescape()>.

=back

=head1 AUTHOR

Graham TerMarsch <cpan@howlingfrog.com>

=head1 COPYRIGHT

Copyright 2008-2010, Graham TerMarsch.  All Rights Reserved.

This is free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=head1 SEE ALSO

L<TAP::Formatter::JUnit>.

=cut
