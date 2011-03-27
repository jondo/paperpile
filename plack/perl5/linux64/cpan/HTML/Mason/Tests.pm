package HTML::Mason::Tests;

use strict;
use warnings;

use Cwd;

use File::Path;
use File::Spec;

use HTML::Mason;
use HTML::Mason::Compiler::ToObject;

use Getopt::Long;

use Test::Builder ();

use vars qw($VERBOSE $DEBUG @SHARED);

my $Test = Test::Builder->new;

$VERBOSE = $ENV{MASON_DEBUG} || $ENV{MASON_VERBOSE} || $ENV{TEST_VERBOSE};
$DEBUG = $ENV{MASON_DEBUG};

$| = 1;

@SHARED = ( { path => '/shared/check_error',
              component => <<'EOF',
<% ($error) ? "Error: $error" : "No error!?" %>
<%init>
if ($error) {
  my @lines = split("\n",$error);
  $error = join("\n",@lines[0..$lines-1]);
  $error =~ s{\s+at .*}{}g;
}
</%init>
<%args>
$error
$lines=>1
</%args>
EOF
            },
            { path => '/shared/display_comp_obj',
              component => <<'EOF',
Declared args:
% my %decl = %{$comp->declared_args};
% foreach (sort keys %decl) {
<% $_ %><% (defined($decl{$_}->{default})) ? "=>".$decl{$_}->{default} : "" %>
% }

I am <% $comp->is_subcomp ? '' : 'not ' %>a subcomponent.
I am <% $comp->is_method ? '' : 'not ' %>a method.
I am <% $comp->is_file_based ? '' : 'not ' %>file-based.
% if (defined($comp->name)) {
My short name is <% $comp->name =~ /anon/ ? '[anon something]' : $comp->name %>.
% }
% if ($comp->is_subcomp and defined($comp->owner)) {
My parent component is <% $comp->owner->title %>.
% }
% if (defined($comp->dir_path)) {
My directory is <% $comp->dir_path %>.
% }
% my @subkeys = sort keys(%{$comp->subcomps});
I have <% scalar(@subkeys) %> subcomponent(s).
% if (@subkeys) {
Including one called <% $comp->subcomps($subkeys[0])->name %>.
% }
My title is <% $comp->title =~ /anon/ ? '[anon something]' : $comp->title %>.

% if (defined($comp->path)) {
My path is <% $comp->path %>.
% }
% if (defined($comp->comp_id)) {
My comp_id is <% $comp->comp_id =~ /anon/ ? '[anon something]' : $comp->comp_id %>.
% }
<%args>
$comp
</%args>
EOF
            },
            { path => '/shared/display_req_obj',
              component => <<'EOF',
My depth is <% $m->depth %>.

I <% $m->is_subrequest ? 'am' : 'am not' %> a subrequest.

The top-level component is <% $m->request_comp->title %>.

My stack looks like:
-----
% foreach my $comp ($m->callers) {
<% $comp->title %>
% }
-----

EOF
            },
          );

#
# Get command options here so that we read tests_class before user
# calls new().
#
my %cmd_options;
GetOptions( 'create' => \$cmd_options{create},
            'tests-to-run=s' => \$cmd_options{tests_to_run},
            'tests-to-skip=s' => \$cmd_options{tests_to_skip},
            'tests-class=s' => \$cmd_options{tests_class},
            );

#
# Allow options to be passed in the environment as well.
#
$cmd_options{tests_to_run} = $ENV{MASON_TESTS_TO_RUN}
    if !defined($cmd_options{tests_to_run}) and defined($ENV{MASON_TESTS_TO_RUN});
$cmd_options{tests_to_skip} = $ENV{MASON_TESTS_TO_SKIP}
    if !defined($cmd_options{tests_to_skip}) and defined($ENV{MASON_TESTS_TO_SKIP});
$cmd_options{tests_class} = $ENV{MASON_TESTS_CLASS}
    if !defined($cmd_options{tests_class}) and defined($ENV{MASON_TESTS_CLASS});

# If user specifies tests_class, load that package; otherwise,
# default it to this package.
if (defined($cmd_options{tests_class})) {
    eval "use $cmd_options{tests_class}";
    die $@ if $@;
} else {
    $cmd_options{tests_class} = __PACKAGE__;
}

my %tests_to_run;
if ($cmd_options{tests_to_run}) {
    for ($cmd_options{tests_to_run}) { s/^\s+//; s/\s+$// }
    my @tests_to_run = split(/\s*,\s*/, $cmd_options{tests_to_run});
    if (grep { /[^0-9]/ } @tests_to_run) {
        @tests_to_run = sort { $a cmp $b } @tests_to_run;
    } else {
        @tests_to_run = sort { $a <=> $b } @tests_to_run;
    }
    %tests_to_run = map { ($_, 1) } @tests_to_run;
    $Test->diag(sprintf("Running only test%s %s\n", @tests_to_run == 1 ? "" : "s", join(", ", @tests_to_run)))
}

my %tests_to_skip;
if ($cmd_options{tests_to_skip}) {
    for ($cmd_options{tests_to_skip}) { s/^\s+//; s/\s+$// }
    my @tests_to_skip = split(/\s*,\s*/, $cmd_options{tests_to_skip});
    %tests_to_skip = map { ($_, 1) } @tests_to_skip;
    $Test->diag(printf ("Skipping test%s %s\n", @tests_to_skip == 1 ? "" : "s", join(", ", @tests_to_skip)));
}

sub new
{
    my $class = shift;
    my %p = (@_, %cmd_options);

    die "No group name provided\n"
        unless exists $p{name};

    die "No description for test group provided\n"
        unless exists $p{description};

    $p{pre_test_cleanup} = 1
        unless exists $p{pre_test_cleanup};

    return bless {
                  %p,
                  support => [],
                  tests => [],
                 }, $class;
}

# Returns the tests class to use for class methods - defaults to this package.
sub tests_class
{
    return $cmd_options{tests_class};
}

sub add_support
{
    my $self = shift;
    my %p = @_;

    die "'support' key array member contains no 'path' key\n"
        unless exists $p{path};

    die "'support' key array member contains no 'component' key\n"
        unless exists $p{component};

    push @{ $self->{support} }, \%p;
}

sub add_test
{
    my $self = shift;
    my %p = @_;

    die "no name provided for test\n"
        unless exists $p{name};

    unless ( exists $p{path} )
    {
        $p{path} = $p{call_path} || $p{name};
    }

    my $call_path = "/$self->{name}";
    if ( exists $p{call_path} )
    {
        $call_path .= '/' unless substr( $p{call_path}, 0, 1 ) eq '/';
        $call_path .= $p{call_path};
    }
    else
    {
        $call_path .= '/' . $p{name};
    }
    $p{call_path} = $call_path;

    if ( ref($p{call_args}) eq 'HASH' )
    {
        my @lst = %{$p{call_args}};
        $p{call_args} = \@lst;
    }
    elsif ( !exists($p{call_args}) ) {
        $p{call_args} = [];
    }

    die "'$p{name}' test has no description\n"
        unless exists $p{description};

    die "'$p{name}' test has no component\n"
        unless exists $p{component} || $p{skip_component};

    die "'$p{name}' test has no 'expect' or 'expect_error' key\n"
        unless exists $p{expect} || exists $p{expect_error} || $p{skip_expect} || $self->{create};

    foreach ( qw( interp_params ) )
    {
        die "$_ must be a hash reference"
            if exists $p{$_} && ! UNIVERSAL::isa( $p{$_}, 'HASH' );
    }

    push @{ $self->{tests} }, \%p;
}

sub run
{
    my $self = shift;

    die "No tests exist in this group"
        unless @{ $self->{tests} };

    if ($DEBUG)
    {
        $Test->diag( "Will " . ( $self->{create} ? '' : 'not ' ) . "create 'expect' files\n" );
    }

    eval
    {
        # 1 indicates to be silent on missing directories
        $self->_cleanup(1) if $self->{pre_test_cleanup};
        $self->_make_dirs;
        $self->_write_shared_comps;
        $self->_write_support_comps;
        $self->_run_tests;
    };

    $self->_cleanup unless $ENV{MASON_NO_CLEANUP};

    die $@ if $@;
}

sub _make_dirs
{
    my $self = shift;

    my $comp_root = $self->comp_root;
    my $data_dir = $self->data_dir;

    unless ( -d $self->comp_root )
    {
        $Test->diag( "Making comp_root directory: $comp_root\n" ) if $DEBUG;
        mkpath( $self->comp_root, 0, 0755 )
            or die "Unable to make base test directory '$comp_root': $!";
    }

    unless ( -d $self->data_dir )
    {
        $Test->diag( "Making data_dir directory: $data_dir\n" ) if $DEBUG;
        mkpath( $self->data_dir, 0, 0755 )
            or die "Unable to make base test directory '$data_dir': $!";
    }
}

sub base_path
{
    my $proto = shift;

    if (ref $proto)
    {
        $proto->{base_path} ||= File::Spec->catdir( cwd(), 'mason_tests' );
        return $proto->{base_path};
    }
    else
    {
        return File::Spec->catdir( cwd(), 'mason_tests' );
    }
}

sub comp_root
{
    my $proto = shift;

    return File::Spec->catdir( $proto->base_path, 'comps' );
}

sub data_dir
{
    my $proto = shift;

    return File::Spec->catdir( $proto->base_path, 'data' );
}

sub _write_shared_comps
{
    my $self = shift;

    return unless @SHARED;

    foreach my $comp ( @SHARED )
    {
        my @path = split m(/), $comp->{path};
        my $file = pop @path;

        my $dir = File::Spec->catdir( $self->comp_root, @path );

        $self->write_comp( $comp->{path}, $dir, $file, $comp->{component} );
    }
}

sub _write_support_comps
{
    my $self = shift;

    unless ( @{ $self->{support} } )
    {
        $Test->diag( "No support comps to create\n" ) if $DEBUG;
        return;
    }

    foreach my $supp ( @{ $self->{support} } )
    {
        my @path = split m(/), $supp->{path};
        my $file = pop @path;

        my $dir = File::Spec->catdir( $self->comp_root, $self->{name}, @path );

        $self->write_comp( $supp->{path}, $dir, $file, $supp->{component} );
    }
}

sub _write_test_comp
{
    my $self = shift;
    my $test = $self->{current_test};

    my @path = split m(/), $test->{path};
    my $file = pop @path;

    my $dir = File::Spec->catdir( $self->comp_root, $self->{name}, @path );
    unless ( -d $dir )
    {
        $Test->diag( "Making dir: $dir\n" ) if $DEBUG;
        mkpath( $dir, 0, 0755 )
            or die "Unable to create directory '$dir': $!";
    }

    $self->write_comp( $test->{path}, $dir, $file, $test->{component} );
}

sub write_comp
{
    my $self = shift;
    my ($path, $dir, $file, $component) = @_;

    unless (-d $dir)
    {
        $Test->diag( "Making dir: $dir\n" ) if $DEBUG;
        mkpath( $dir, 0, 0755 )
            or die "Unable to create directory '$dir': $!";
    }

    my $real_file = File::Spec->catfile( $dir, $file );

    $Test->diag( "Making component $path at $real_file\n" )
        if $DEBUG;

    open my $fh, ">$real_file"
        or die "Unable to write to '$real_file': $!";
    print $fh $component
        or die "Unable to write to '$real_file': $!";
    close $fh
        or die "Unable to write to '$real_file': $!";
}

sub _run_tests
{
    my $self = shift;

    my $count = scalar @{ $self->{tests} };
    $Test->plan( tests => $count );

    if ($VERBOSE)
    {
        $Test->diag( "Running $self->{name} tests ($count tests): $self->{description}\n" );
    }

    my $x = 1;
    foreach my $test ( @{ $self->{tests} } )
    {
        $self->{current_test} = $test;

        #
        # If tests_to_run or tests_to_skip were specified in the
        # environment or command line, check them to see whether to
        # run the test.
        #
        if (%tests_to_run or %tests_to_skip) {

            # Look for any of the specs [test_file_name:](test_number|test_name|*)
            my $wildcard_name = join(":", $self->{name}, "*");
            my $full_name = join(":", $self->{name}, $test->{name});
            my $full_number = join(":", $self->{name}, $x);
            my @all_specs = ($x, $test->{name}, $full_name, $full_number, $wildcard_name);

            # If our test isn't mentioned in %tests_to_run or is
            # mentioned in %tests_to_skip, skip it.
            #
            if ((%tests_to_run and !(grep { $tests_to_run{$_} } @all_specs))
                or (%tests_to_skip and (grep { $tests_to_skip{$_} } @all_specs))) {

                # Use presence of PERL_DL_NONLAZY to decide if we are
                # running inside "make test", and if so, actually
                # print the appropriate skip response to comply with the
                # Test::Harness standard. If the user is running the
                # test by hand, this would just be clutter.
                #
                # Checking PERL_DL_NONLAZY is a hack but I don't
                # know of a better detection method.
                #
                $self->_skip if ($ENV{PERL_DL_NONLAZY});
                $x++;
                next;
            }
        }
        $Test->diag( "Running $test->{name} (#$x): $test->{description}\n" ) if $VERBOSE;
        $self->_make_component unless $test->{skip_component};
        $self->_run_test;
        $x++;
    }
}

sub _make_component
{
    my $self = shift;
    my $test = $self->{current_test};
    $self->_write_test_comp;
}

sub _make_main_interp
{
    my $self = shift;
    my $test = $self->{current_test};
    return $test->{interp} if $test->{interp};

    my %interp_params = ( exists $test->{interp_params} ?
                          %{ $test->{interp_params} } :
                          () );

    if ($DEBUG && %interp_params)
    {
        $Test->diag( "Interp params:\n" );
        while ( my ($k, $v) = each %interp_params)
        {
            $Test->diag( "  $k => $v\n" );
        }
    }

    return $self->_make_interp ( comp_root => $self->comp_root,
                                 data_dir  => $self->data_dir,
                                 %interp_params );
}

sub _make_interp
{
    my ($class, %interp_params) = @_;

    return HTML::Mason::Interp->new( %interp_params );
}

sub _run_test
{
    my $self = shift;
    my $test = $self->{current_test};

    $self->{buffer} = '';
    my $interp = $self->_make_main_interp;
    $interp->out_method( sub { for (@_) { $self->{buffer} .= $_ if defined $_ } } );

    my $warnings = '';
    local $SIG{__WARN__} = sub { $warnings .= $_ for @_ };
    eval {
        # Run pre_code if test has it - pass in interp
        if ($test->{pre_code}) {
            $test->{pre_code}->($interp);
        }
        $self->_execute($interp);
    };

    return $self->check_result($@, $warnings);
}

sub _execute
{
    my ($self, $interp) = @_;
    my $test = $self->{current_test};

    $Test->diag( "Calling $test->{name} test with path: $test->{call_path}\n" ) if $DEBUG;
    $test->{pretest_code}->() if $test->{pretest_code};
    $interp->exec( $test->{call_path}, @{$test->{call_args}} );
}

sub check_result {
    my ($self, $error, $warnings) = @_;
    my $test = $self->{current_test};

    local $HTML::Mason::Tests::TODO = $self->{current_test}{todo}
        if exists $self->{current_test}{todo};
    $Test->todo if exists $self->{current_test}{todo};

    if ($error)
    {
        if ( $test->{expect_error} )
        {
            if ( $error =~ /$test->{expect_error}/ )
            {
                return $self->_success
            }
            else
            {
                if ($VERBOSE)
                {
                    $Test->diag( "Got error:\n$error\n...but expected something matching:\n$test->{expect_error}\n" );
                }
                return $self->_fail;
            }
        }
        else
        {
            $Test->diag( "Unexpected error running $test->{name}:\n$error" ) if $VERBOSE;
            return $self->_fail;
        }

    }
    elsif ( $test->{expect_error} )
    {
        $Test->diag( "Expected an error matching '$test->{expect_error}' but no error occurred - got successful output:\n$self->{buffer}\n" ) if $VERBOSE;
        return $self->_fail;
    }

    if ($self->{create})
    {
        $Test->diag( "Results for $test->{name}:\n$self->{buffer}\n" );
        return;
    }

    my $success =
        ( $test->{skip_expect} ?
          1 :
          $self->check_output( actual => $self->{buffer}, expect => $test->{expect} )
        );

    if ( $test->{expect_warnings} )
    {
        unless ( $warnings =~ /$test->{expect_warnings}/ )
        {
            $Test->diag( "Got warnings:\n$warnings\n...but expected something matching:\n$test->{expect_warnings}\n" );
            $success = 0;
        }
    }

    $Test->diag( "Got warnings: $warnings" ) if $warnings && ( ! $test->{expect_warnings} || $VERBOSE );
    $success = 0 if $test->{no_warnings} && $warnings;

    $success ? $self->_success : $self->_fail;
}

sub check_output
{
    my ($self, %p) = @_;

    my $same;

    # Allow a regex for $p{expect}
    if (ref $p{expect}) {
        $same = ($p{actual} =~ /$p{expect}/);

    } else {
        # Whitespace at end can vary.  (Or rather, it is varying in the tests, and
        # should be made not to vary, but I don't have time to fix it yet.)

        for ($p{actual}, $p{expect}) {  s/\s+$//  }
        $same = ($p{actual} eq $p{expect});
    }

    if (!$same and $VERBOSE) {
        $Test->diag( "Got ...\n-----\n$p{actual}\n-----\n   ... but expected ...\n-----\n$p{expect}\n-----\n" );
    }
    return $same;
}

sub _fail
{
    my $self = shift;
    my $test = $self->{current_test};

    $Test->ok( 0, $test->{name} );
}

sub _success
{
    my $self = shift;
    my $test = $self->{current_test};

    $Test->ok( 1, $test->{name} );
}

sub _skip
{
    my $self = shift;
    my $test = $self->{current_test};

    $Test->skip;
}

#
# We use our own rm_tree, rather than File::Path::rmtree, so that we
# can silently fail to entirely remove directories. On some systems
# .nfs files prevent total removal of directories but should not
# otherwise interfere with tests.
#
sub rm_tree {
    my ($path, $debug, $silent) = @_;
    $path =~ s#/$##;
    if (-d $path) {
        local *DIR;
        opendir DIR, $path or warn "Can't open $path: $!";
        while (defined(my $file = readdir DIR)) {
            next if $file eq '.' or $file eq '..';
            rm_tree("$path/$file");
        }
        closedir DIR;
        rmdir $path;
    } elsif (-f $path) {
        unlink $path;
    } else {
        $Test->diag( "Can't find $path to remove" )
            unless $silent;
    }
}

sub _cleanup
{
    my $self = shift;

    rm_tree( $self->base_path, $DEBUG, @_ );
}

1;

__END__

=head1 NAME

HTML::Mason::Tests - Test harness for testing Mason

=head1 SYNOPSIS

 use HTML::Mason::Tests;

 my $group = HTML::Mason::Tests->new( name => 'name of group', description => 'tests something' );
 $group->add_test( name => 'foo',
                   description => 'tests foo',
                   component => <<'EOF'
 <%args>
 $foo => 1
 </%args>
 <% $foo %>
 EOF
                   expect => <<'EOF',
 1
 EOF
                 );

 $group->run;

=head1 DESCRIPTION

This module is designed to automate as much as possible of the Mason
test suite.  It does tasks like write component files to disk, call
them, compare the actual results to the expected results, and more.
In addition, it also is capable of printing out useful information
about test failures when run in verbose mode.  See the ADDITIONAL RUN
MODES section for more information.

It also makes sure that any given group of tests provides all the
information needed to run them (test names, components and results,
etc.).

Now you have no excuse for writing new tests (and that goes double for
me!).

=head1 METHODS

=head2 new

Takes the following parameters:

=over 4

=item * name (required)

The name of the entire group of tests.

=item * description (required)

What this group tests.

=item * pre_test_cleanup (optional, default=1)

If this is true (the default), the component root and data directory
will be deleted both before and after running tests.

=back

=head2 add_support

Takes the following parameters:

=over 4

=item * path (required)

The path that other components will expect this component to be
reachable at.  All paths are prepended with the group name.  So '/bar'
as a support component in the 'foo' group's ultimate path would be
'/foo/bar'.

=item * component

Text of the support component.  This parameter must have a value
unless the skip_component parameter is true.

=item * skip_component

If true, then the test harness will not write a component to disk for
this test.

=back

=head2 add_test

Takes the following parameters:

=over 4

=item * name (required)

The name of this test.

=item * description (required)

What this test is testing.

=item * component (required)

Text of the component.

=item * path (optional)

The path that this component should written to.  As with support
components, this path is prepended with the group's name.  If no path
is given, it uses call_path, if given, otherwise it uses the name
parameter.

=item * call_path (optional)

The path that should be used to call the component.  If none is given,
it will be /<group name>/<test name>.  If a value is given, it is
still prepended by /<group name>/.

=item * call_args (optional)

The arguments that should be passed to the component, in list or hash
reference form. If none is given, no arguments are passed.

=item * compiler_params

This is a hash reference of parameters to be passed to the Compiler->new
method.

=item * interp_params

This is a hash reference of parameters to be passed to the Interp->new
method.

=item * interp

Provide an HTML::Mason::Interp object to be used for the test.

=item * todo

If this is given, the test will be treated as a todo test, so it will
be expected to fail.  This should be a string.

=back

One of the following three options is required:

=over 4

=item * expect

The text expected as a result of calling the component.  This
parameter is _not_ required when running in L<Create mode|"ADDITIONAL
RUN MODES">.

=item * expect_error

A regex that will be matched against the error returned from the
component execution.

=item * no_warnings

If true, this means that the test expects to run without generating
any warnings.  If warnings are generated, the test fails.

=item * expect_warnings

A regex that will be matched against any warnings output when running
the component.

=item * skip_expect

This causes the component to be run but its output is ignored.
However, if the component execution causes an error this will cause
the test to fail.  This is used in a few situations where it is
necessary to just run a component as part the preparation for another
test.

=back

=head2 run

Run the tests in the group.

=head2 Class methods

These methods are provided since some tests may need to know these
values.

=head2 base_path

The base path under which the component root and data directory for
the tests are created.

=head2 comp_root

Returns the component root directory.

=head2 data_dir

Return the data directory

=head2 check_output ( actual => $actual_output, expect => $expected_output )

Given the parameters shown above, this method will check to see if the
two are equal.  If they're not equal, it will print out an error
message attempting to highlight the difference.

=head1 ADDITIONAL RUN MODES

The following additional modes are available for running tests.

=head2 Verbose mode

To turn this on, set the environment variables MASON_VERBOSE or
MASON_DEBUG as true or run the tests as 'make test TEST_VERBOSE=1'.
In this mode, the C<run> method will output information about tests as
they are run.  If a test fails, then it will also show the cause of
the failure.

=head2 Debug mode

To turn this on, set the MASON_DEBUG environment variable to a true
value.  In this mode, the C<run> method will print detailed
information of its actions.  This mode includes the output printed in
VERBOSE mode.

=head2 No cleanup mode

Setting the MASON_NO_CLEANUP environment variable will tell the module
to not clean up generated data from running the tests.  This includes
the components written to disk and the data directory used during
testing.  This can be useful when debugging.

=head2 Create mode

If the individual tests are run from the command line with the
'--create' flag, then instead of checking the output of a component,
the test harness will simply output its results.  This allows you to
cut and paste these results back into the test file (assuming they are
correct!).

=head2 Running and/or skipping selected tests

You can run just some of a test file with the '--tests-to-run' flag or
the MASON_TESTS_TO_RUN environment variable. Similarly you can skip
specific tests with the '--tests-to-skip' flag or the
MASON_TESTS_TO_SKIP environment variable.

The value of either flag is a comma-separated list of one or more of

   [test_file_name:](test_number|test_name|*)

e.g.

    perl ./01-syntax.t --tests-to-run=3,5
    MASON_TESTS_TO_SKIP=fake_percent,empty_percents perl ./01-syntax.t
    MASON_TESTS_TO_RUN="misc:autohandler, request:*, interp:private1" make test

=head2 Subclassing this module

You can run tests with your own Tests.pm subclass using the
'--tests-class' flag or the MASON_TESTS_CLASS environment variable.
The value is a fully qualified package name that will be loaded before
each test file is run.  e.g.

    perl ./01-syntax.t --tests-class=HTML::Mason::Tests::MyTests
    MASON_TESTS_CLASS=HTML::Mason::Tests::MyTests make test

For example, if you have created your own lexer subclass and want
to make sure that tests still pass with it, create a Tests subclass
that overrides the _make_interp method to use your subclass:

    sub _make_interp
    {
        my ($self, %interp_params) = @_;

        return HTML::Mason::Interp->new
            ( lexer_class => HTML::Mason::MyLexer,
              %interp_params );
    }

=head1 SEE ALSO

L<HTML::Mason|HTML::Mason>

=cut
