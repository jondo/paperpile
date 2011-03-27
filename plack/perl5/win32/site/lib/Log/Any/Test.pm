package Log::Any::Test;
use strict;
use warnings;

# 'use Log::Any::Test' just defines a test version of Log::Any::Adapter.
#
package Log::Any::Adapter;
use Log::Any::Adapter::Test;
use strict;
use warnings;
our $Initialized = 1;

sub get_logger {
    my ( $self, $category ) = @_;
    return Log::Any::Adapter::Test->new( category => $category );
}

1;

=pod

=head1 NAME

Log::Any::Test -- Test what you're logging with Log::Any

=head1 SYNOPSIS

    use Test::More;
    use Log::Any::Test;    # should appear before 'use Log::Any'!
    use Log::Any qw($log);

    # ...
    # call something that logs using Log::Any
    # ...

    # now test to make sure you logged the right things

    $log->contains_ok(qr/good log message/, "good message was logged");
    $log->does_not_contain_ok(qr/unexpected log message/, "unexpected message was not logged");
    $log->empty_ok("no more logs");

    # or

    my $msgs = $log->msgs;
    cmp_deeply($msgs, [{message => 'msg1', level => 'debug'}, ...]);

=head1 DESCRIPTION

C<Log::Any::Test> is a simple module that allows you to test what has been
logged with Log::Any. Most of its API and implementation have been taken from
L<Log::Any::Dispatch|Log::Any::Dispatch>.

Using C<Log::Any::Test> sends all subsequent Log::Any log messages to a single
global in-memory buffer.  It should be used before L<Log::Any|Log::Any>.

=head1 METHODS

The test_name is optional in the *_ok methods; a reasonable default will be
provided.

=over

=item msgs ()

Returns the current contents of the global log buffer as an array reference,
where each element is a hash containing a I<category>, I<level>, and I<message>
key.  e.g.

  {
    category => 'Foo',
    level => 'error',
    message => 'this is an error'
  },
  {
    category => 'Bar::Baz',
    level => 'debug',
    message => 'this is a debug'
  }

=item contains_ok ($regex[, $test_name])

Tests that a message in the log buffer matches I<$regex>. On success, the
message is I<removed> from the log buffer (but any other matches are left
untouched).

=item does_not_contain_ok ($regex[, $test_name])

Tests that no message in the log buffer matches I<$regex>.

=item empty_ok ([$test_name])

Tests that there is no log buffer left. On failure, the log buffer is cleared
to limit further cascading failures.

=item contains_only_ok ($regex[, $test_name])

Tests that there is a single message in the log buffer and it matches
I<$regex>. On success, the message is removed.

=item clear ()

Clears the log buffer.

=back

=head1 SEE ALSO

L<Log::Any|Log::Any>, L<Test::Log::Dispatch|Test::Log::Dispatch>

=head1 AUTHOR

Jonathan Swartz

=head1 COPYRIGHT & LICENSE

Copyright (C) 2009 Jonathan Swartz, all rights reserved.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
