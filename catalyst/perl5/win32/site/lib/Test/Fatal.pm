use strict;
use warnings;
package Test::Fatal;
BEGIN {
  $Test::Fatal::VERSION = '0.003';
}
# ABSTRACT: incredibly simple helpers for testing code with exceptions


use Carp ();
use Try::Tiny 0.07;

use Exporter 5.59 'import';

our @EXPORT    = qw(exception);
our @EXPORT_OK = qw(exception success);


sub exception (&) {
  my ($code) = @_;

  return try {
    $code->();
    return undef;
  } catch {
    return $_ if $_;

    my $problem = defined $_ ? 'false' : 'undef';
    Carp::confess("$problem exception caught by Test::Fatal::exception");
  };
}


sub success (&) {
  my ($code) = @_;
  return finally {
    return if @_; # <-- only run on success
    $code->();
  }
}

1;

__END__
=pod

=head1 NAME

Test::Fatal - incredibly simple helpers for testing code with exceptions

=head1 VERSION

version 0.003

=head1 SYNOPSIS

  use Test::More;
  use Test::Fatal;

  use System::Under::Test qw(might_die);

  is(
    exception { might_die; },
    undef
    "the code lived",
  );

  isnt(
    exception { might_die; },
    undef,
    "the code died",
  );

  isa_ok(
    exception { might_die; },
    'Exception::Whatever',
    'the thrown exception',
  );

=head1 DESCRIPTION

Test::Fatal is an alternative to the popular L<Test::Exception>.  It does much
less, but should allow greater flexibility in testing exception-throwing code
with about the same amount of typing.

It exports one routine by default: C<exception>.

=head1 FUNCTIONS

=head2 exception

  my $exception = exception { ... };

C<exception> takes a bare block of code and returns the exception thrown by
that block.  If no exception was thrown, it returns undef.

B<ACHTUNG!>  If the block results in a I<false> exception, such as 0 or the
empty string, Test::Fatal itself will die.  Since either of these cases
indicates a serious problem with the system under testing, this behavior is
considered a I<feature>.  If you must test for these conditions, you should use
L<Try::Tiny>'s try/catch mechanism.  (Try::Tiny is the underlying exception
handling system of Test::Fatal.)

Note that there is no TAP assert being performed.  In other words, no "ok" or
"not ok" line is emitted.  It's up to you to use the rest of C<exception> in an
existing test like C<ok>, C<isa_ok>, C<is>, et cetera.

C<exception> does I<not> alter the stack presented to the called block, meaning
that if the exception returned has a stack trace, it will include some frames
between the code calling C<exception> and the thing throwing the exception.
This is considered a I<feature> because it avoids the occasionally twitchy
C<Sub::Uplevel> mechanism.

=head2 success

  try {
    should_live;
  } catch {
    fail("boo, we died");
  } success {
    pass("hooray, we lived");
  };

C<success>, exported only by request, is a L<Try::Tiny> helper with semantics
identical to L<C<finally>|Try::Tiny/finally>, but the body of the block will
only be run if the C<try> block ran without error.

Although almost any needed exception tests can be performed with C<exception>,
success blocks may sometimes help organize complex testing.

=head1 AUTHOR

Ricardo Signes <rjbs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Ricardo Signes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

