package TAP::Formatter::JUnit;

use strict;
use warnings;
use XML::Generator;
use TAP::Formatter::JUnit::Session;
use base qw(TAP::Formatter::Console);
use Class::Field qw(field);

our $VERSION = '0.08';

field 'testsuites'  => [];

###############################################################################
# Subroutine:   open_test($test, $parser)
###############################################################################
# Over-ridden 'open_test()' method.
#
# Creates a 'TAP::Formatter::JUnit::Session' session, instead of a console
# formatter session.
sub open_test {
    my ($self, $test, $parser) = @_;
    my $session = TAP::Formatter::JUnit::Session->new( {
        name        => $test,
        formatter   => $self,
        parser      => $parser,
        passing_todo_ok => $ENV{ALLOW_PASSING_TODOS} ? 1 : 0,
    } );
    return $session;
}

###############################################################################
# Subroutine:   summary($aggregate)
###############################################################################
# Prints the summary report (in JUnit) after all tests are run.
sub summary {
    my ($self, $aggregate) = @_;
    return if $self->silent();

    my @suites = @{$self->testsuites};
    print { $self->stdout } $self->xml->testsuites( @suites );
}

###############################################################################
# Subroutine:   xml()
###############################################################################
# Returns a new 'XML::Generator', to generate XML output.
sub xml {
    my $self = shift;
    unless ($self->{xml}) {
        $self->{xml} = XML::Generator->new(
            ':pretty',
            ':std',
            'escape'   => 'always,high-bit,even-entities',
            'encoding' => 'UTF-8',
        );
    }
    return $self->{xml};
}

###############################################################################
# Subroutine:   xml_unescape()
###############################################################################
# Returns a new 'XML::Generator', to generate unescaped XML output.
sub xml_unescape {
    my $self = shift;
    unless ($self->{xml_unescape}) {
        $self->{xml_unescape} = XML::Generator->new(
            ':pretty',
            ':std',
            'escape'   => 'unescaped',
            'encoding' => 'UTF-8'
        );
    }
    return $self->{xml_unescape};
}

###############################################################################
# Subroutine:   add_testsuite($suite)
###############################################################################
# Adds the given XML test '$suite' to the list of test suites that we've
# executed and need to summarize.
sub add_testsuite {
    my ($self, $suite) = @_;
    push @{$self->testsuites}, $suite;
}

1;

=head1 NAME

TAP::Formatter::JUnit - Harness output delegate for JUnit output

=head1 SYNOPSIS

On the command line, with F<prove>:

  prove --formatter TAP::Formatter::JUnit ...

Or, in your own scripts:

  use TAP::Harness;
  my $harness = TAP::Harness->new( {
      formatter_class => 'TAP::Formatter::JUnit',
      merge => 1,
  } );
  $harness->runtests(@tests);

=head1 DESCRIPTION

B<This code is currently in alpha state and is subject to change.>

C<TAP::Formatter::JUnit> provides JUnit output formatting for C<TAP::Harness>.

By default (e.g. when run with F<prove>), the I<entire> test suite is gathered
together into a single JUnit XML document, which is then displayed on C<STDOUT>.
You can, however, have individual JUnit XML files dumped for each individual
test, by setting c<PERL_TEST_HARNESS_DUMP_TAP> to a directory that you would
like the JUnit XML dumped to.  Note, that this will B<also> cause
C<TAP::Harness> to dump the original TAP output into that directory as well (but
IMHO that's ok as you've now got the data in two parsable formats).

Timing information is included in the JUnit XML, I<if> you specified C<--timer>
when you ran F<prove>.

In standard use, "passing TODOs" are treated as failure conditions (and are
reported as such in the generated JUnit).  If you wish to treat these as a
"pass" and not a "fail" condition, setting C<ALLOW_PASSING_TODOS> in your
environment will turn these into pass conditions.

The JUnit output generated is partial to being grokked by Hudson
(L<http://hudson.dev.java.net/>).  That's the build tool I'm using at the
moment and needed to be able to generate JUnit output for.

=head1 METHODS

=over

=item B<open_test($test, $parser)>

Over-ridden C<open_test()> method.

Creates a C<TAP::Formatter::JUnit::Session> session, instead of a console
formatter session.

=item B<summary($aggregate)>

Prints the summary report (in JUnit) after all tests are run.

=item B<xml()>

Returns a new C<XML::Generator>, to generate XML output.

=item B<xml_unescape()>

Returns a new C<XML::Generator>, to generate unescaped XML output.

=item B<add_testsuite($suite)>

Adds the given XML test C<$suite> to the list of test suites that we've
executed and need to summarize.

=back

=head1 AUTHOR

Graham TerMarsch <cpan@howlingfrog.com>

Many thanks to Andy Armstrong et al. for the B<fabulous> set of tests in
C<Test::Harness>; they became the basis for the unit tests here.

Other thanks go out to those that have provided feedback, comments, or patches:

  Mark Aufflick
  Joe McMahon
  Michael Nachbaur
  Marc Abramowitz
  Colin Robertson
  Phillip Kimmey

=head1 COPYRIGHT

Copyright 2008-2010, Graham TerMarsch.  All Rights Reserved.

This is free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=head1 SEE ALSO

L<TAP::Formatter::Console>,
L<TAP::Formatter::JUnit::Session>,
L<http://hudson.dev.java.net/>,
L<http://jra1mw.cvs.cern.ch:8180/cgi-bin/jra1mw.cgi/org.glite.testing.unit/config/JUnitXSchema.xsd?view=markup&content-type=text%2Fvnd.viewcvs-markup&revision=HEAD>,
L<http://confluence.atlassian.com/display/BAMBOO/JUnit+parsing+in+Bamboo>.

=cut
