package Test::LongString;

use strict;
use vars qw($VERSION @ISA @EXPORT $Max $Context $LCSS);

$VERSION = '0.14';

use Test::Builder;
my $Tester = new Test::Builder();

use Exporter;
@ISA    = ('Exporter');
@EXPORT = qw( is_string is_string_nows like_string unlike_string
    contains_string lacks_string );

# Maximum string length displayed in diagnostics
$Max = 50;

# Amount of context provided when starting displaying a string in the middle
$Context = 10;

# Boolean: should we show LCSS context ?
$LCSS = 1;

sub import {
    (undef, my %args) = @_;
    $Max = $args{max} if defined $args{max};
    $LCSS = $args{lcss} if defined $args{lcss};
    @_ = $_[0];
    goto &Exporter::import;
}

# _display($string, [$offset = 0])
# Formats a string for display. Begins at $offset minus $Context.
# This function ought to be configurable, à la od(1).

sub _display {
    my $s = shift;
    if (!defined $s) { return 'undef'; }
    if (length($s) > $Max) {
	my $offset = shift || 0;
	if (defined $Context) {
	    $offset -= $Context;
	    $offset < 0 and $offset = 0;
	}
	else {
	    $offset = 0;
	}
	$s = sprintf(qq("%.${Max}s"...), substr($s, $offset));
	$s = "...$s" if $offset;
    }
    else {
	$s = qq("$s");
    }
    $s =~ s/([\0-\037\200-\377])/sprintf('\x{%02x}',ord $1)/eg;
    return $s;
}

sub _common_prefix_length {
    my ($str1, $str2) = @_;
    my $diff = $str1 ^ $str2;
    my ($pre) = $diff =~ /^(\000*)/;
    return length $pre;
}

sub contains_string($$;$) {
    my ($str,$sub,$name) = @_;

    my $ok;
    if (!defined $str) {
        $Tester->ok($ok = 0, $name);
        $Tester->diag("String to look in is undef");
    } elsif (!defined $sub) {
        $Tester->ok($ok = 0, $name);
        $Tester->diag("String to look for is undef");
    } else {
        my $index = index($str, $sub);
        $ok = ($index >= 0) ? 1 : 0;
        $Tester->ok($ok, $name);
        if (!$ok) {
            my ($g, $e) = (_display($str), _display($sub));

            $Tester->diag(<<DIAG);
    searched: $g
  can't find: $e
DIAG

            if ($LCSS) {
                # if _lcss() returned the actual substring,
                # all we'd have to do is:
                # my $l = _display( _lcss($str, $sub) );

                my ($off, $len) = _lcss($str, $sub);
                my $l = _display( substr($str, $off, $len) );

                $Tester->diag(<<DIAG);
        LCSS: $l
DIAG
                # if there's room left, show some surrounding context
                if ($len < $Max) {
                    my $available = int( ($Max - $len) / 2 );
                    my $begin = ($off - ($available*2) > 0) ? $off - ($available*2) 
                    : ($off - $available > 0) ? $off - $available : 0;
                    my $c = _display( substr($str, $begin, $Max) );

                    $Tester->diag("LCSS context: $c");
                }
            }
        }
    }
    return $ok;
}

sub _lcss($$) {
    my ($S, $T) = (@_);
    my @L;
    my ($offset, $length) = (0,0);

    # prevent us from having to zero a $ix$j matrix
    no warnings 'uninitialized';

    # now the actual LCSS algorithm
    foreach my $i (0 .. length($S) ) {
        foreach my $j (0 .. length($T)) {
            if (substr($S, $i, 1) eq substr($T, $j, 1)) {
                if ($i == 0 or $j == 0) {
                    $L[$i][$j] = 1;
                }
                else {
                    $L[$i][$j] = $L[$i-1][$j-1] + 1;
                }
                if ($L[$i][$j] > $length) {
                    $length = $L[$i][$j];
                    $offset = $i - $length + 1;
                }
            }
        }
    }

    # if you want to display just the lcss:
    # return substr($S, $offset, $length);

    # but to display the surroundings, we need to:
    return ($offset, $length);
}


sub lacks_string($$;$) {
    my ($str,$sub,$name) = @_;

    my $ok;
    if (!defined $str) {
        $Tester->ok($ok = 0, $name);
        $Tester->diag("String to look in is undef");
    } elsif (!defined $sub) {
        $Tester->ok($ok = 0, $name);
        $Tester->diag("String to look for is undef");
    } else {
        my $index = index($str, $sub);
        $ok = ($index < 0) ? 1 : 0;
        $Tester->ok($ok, $name);
        if (!$ok) {
            my ($g, $e) = (_display($str), _display($sub));
            $Tester->diag(<<DIAG);
    searched: $g
   and found: $e
 at position: $index
DIAG
        }
    }
    return $ok;
}

sub is_string ($$;$) {
    my ($got, $expected, $name) = @_;
    if (!defined $got || !defined $expected) {
	my $ok = !defined $got && !defined $expected;
	$Tester->ok($ok, $name);
	if (!$ok) {
	    my ($g, $e) = (_display($got), _display($expected));
	    $Tester->diag(<<DIAG);
         got: $g
    expected: $e
DIAG
	}
	return $ok;
    }
    if ($got eq $expected) {
	$Tester->ok(1, $name);
	return 1;
    }
    else {
	$Tester->ok(0, $name);
	my $common_prefix = _common_prefix_length($got,$expected);
	my ($g, $e) = (
	    _display($got, $common_prefix),
	    _display($expected, $common_prefix),
	);
	$Tester->diag(<<DIAG);
         got: $g
      length: ${\(length $got)}
    expected: $e
      length: ${\(length $expected)}
    strings begin to differ at char ${\($common_prefix + 1)}
DIAG
	return 0;
    }
}

sub is_string_nows ($$;$) {
    my ($got, $expected, $name) = @_;
    if (!defined $got || !defined $expected) {
	my $ok = !defined $got && !defined $expected;
	$Tester->ok($ok, $name);
	if (!$ok) {
	    my ($g, $e) = (_display($got), _display($expected));
	    $Tester->diag(<<DIAG);
         got: $g
    expected: $e
DIAG
	}
	return $ok;
    }
    s/\s+//g for (my $got_nows = $got), (my $expected_nows = $expected);
    if ($got_nows eq $expected_nows) {
	$Tester->ok(1, $name);
	return 1;
    }
    else {
	$Tester->ok(0, $name);
	my $common_prefix = _common_prefix_length($got_nows,$expected_nows);
	my ($g, $e) = (
	    _display($got_nows, $common_prefix),
	    _display($expected_nows, $common_prefix),
	);
	$Tester->diag(<<DIAG);
after whitespace removal:
         got: $g
      length: ${\(length $got_nows)}
    expected: $e
      length: ${\(length $expected_nows)}
    strings begin to differ at char ${\($common_prefix + 1)}
DIAG
	return 0;
    }
}

sub like_string ($$;$) {
    _like($_[0],$_[1],'=~',$_[2]);
}

sub unlike_string ($$;$) {
    _like($_[0],$_[1],'!~',$_[2]);
}

# mostly from Test::Builder::_regex_ok
sub _like {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my ($got, $regex, $cmp, $name) = @_;
    my $ok = 0;
    my $usable_regex = $Tester->maybe_regex($regex);
    unless (defined $usable_regex) {
	$ok = $Tester->ok( 0, $name );
	$Tester->diag("    '$regex' doesn't look much like a regex to me.");
	return $ok;
    }
    {
	local $^W = 0;
	my $test = $got =~ /$usable_regex/ ? 1 : 0;
	$test = !$test if $cmp eq '!~';
	$ok = $Tester->ok( $test, $name );
    }
    unless( $ok ) {
	my $g = _display($got);
	my $match = $cmp eq '=~' ? "doesn't match" : "matches";
	my $l = defined $got ? length $got : '-';
	$Tester->diag(sprintf(<<DIAGNOSTIC, $g, $match, $regex));
         got: %s
      length: $l
    %13s '%s'
DIAGNOSTIC
    }
    return $ok;
}

1;

__END__

=head1 NAME

Test::LongString - tests strings for equality, with more helpful failures

=head1 SYNOPSIS

    use Test::More tests => 1;
    use Test::LongString;
    like_string( $html, qr/(perl|cpan)\.org/ );

    #     Failed test (html-test.t at line 12)
    #          got: "<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Trans"...
    #       length: 58930
    #     doesn't match '(?-xism:(perl|cpan)\.org)'

=head1 DESCRIPTION

This module provides some drop-in replacements for the string
comparison functions of L<Test::More>, but which are more suitable
when you test against long strings.  If you've ever had to search
for text in a multi-line string like an HTML document, or find
specific items in binary data, this is the module for you.

=head1 FUNCTIONS

=head2 is_string( $string, $expected [, $label ] )

C<is_string()> is equivalent to C<Test::More::is()>, but with more
helpful diagnostics in case of failure.

=over

=item *

It doesn't print the entire strings in the failure message.

=item *

It reports the lengths of the strings that have been compared.

=item *

It reports the length of the common prefix of the strings.

=item *

In the diagnostics, non-ASCII characters are escaped as C<\x{xx}>.

=back

For example:

    is_string( $soliloquy, $juliet );

    #     Failed test (soliloquy.t at line 15)
    #          got: "To be, or not to be: that is the question:\x{0a}Whether"...
    #       length: 1490
    #     expected: "O Romeo, Romeo,\x{0a}wherefore art thou Romeo?\x{0a}Deny thy"...
    #       length: 154
    #     strings begin to differ at char 1

=head2 is_string_nows( $string, $expected [, $label ] )

Like C<is_string()>, but removes whitepace (in the C<\s> sense) from the
arguments before comparing them.

=head2 like_string( $string, qr/regex/ [, $label ] )

=head2 unlike_string( $string, qr/regex/ [, $label ] )

C<like_string()> and C<unlike_string()> are replacements for
C<Test::More:like()> and C<unlike()> that only print the beginning
of the received string in the output.  Unfortunately, they can't
print out the position where the regex failed to match.

    like_string( $soliloquy, qr/Romeo|Juliet|Mercutio|Tybalt/ );

    #     Failed test (soliloquy.t at line 15)
    #          got: "To be, or not to be: that is the question:\x{0a}Whether"...
    #       length: 1490
    #     doesn't match '(?-xism:Romeo|Juliet|Mercutio|Tybalt)'

=head2 contains_string( $string, $substring [, $label ] )

C<contains_string()> searches for I<$substring> in I<$string>.  It's
the same as C<like_string()>, except that it's not a regular
expression search.

    contains_string( $soliloquy, "Romeo" );

    #     Failed test (soliloquy.t at line 10)
    #         searched: "To be, or not to be: that is the question:\x{0a}Whether"...
    #   and can't find: "Romeo"

As of version 0.12, C<contains_string()> will also report the Longest Common
SubString (LCSS) found in I<$string> and, if the LCSS is short enough, the
surroundings will also be shown under I<LCSS Context>. This should help debug
tests for really long strings like HTML output, so you'll get something like:

   contains_string( $html, '<div id="MainContent">' );
   #   Failed test at t/foo.t line 10.
   #     searched: "<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Stric"...
   #   can't find: "<div id="MainContent">"
   #         LCSS: "ainContent""
   # LCSS context: "dolor sit amet</span>\x{0a}<div id="mainContent" class="

You can turn off LCSS reporting by setting C<$Test::LongString::LCSS> to 0,
or by specifying an argument to C<use>:

    use Test::LongString lcss => 0;

=head2 lacks_string( $string, $substring [, $label ] )

C<lacks_string()> makes sure that I<$substring> does NOT exist in
I<$string>.  It's the same as C<like_string()>, except that it's not a
regular expression search.

    lacks_string( $soliloquy, "slings" );

    #     Failed test (soliloquy.t at line 10)
    #         searched: "To be, or not to be: that is the question:\x{0a}Whether"...
    #        and found: "slings"
    #      at position: 147

=head1 CONTROLLING OUTPUT

By default, only the first 50 characters of the compared strings
are shown in the failure message.  This value is in
C<$Test::LongString::Max>, and can be set at run-time.

You can also set it by specifying an argument to C<use>:

    use Test::LongString max => 100;

When the compared strings begin to differ after a large prefix,
Test::LongString will not print them from the beginning, but will start at the
middle, more precisely at C<$Test::LongString::Context> characters before the
first difference. By default this value is 10 characters. If you want
Test::LongString to always print the beginning of compared strings no matter
where they differ, undefine C<$Test::LongString::Context>.

=head1 AUTHOR

Written by Rafael Garcia-Suarez. Thanks to Mark Fowler (and to Joss Whedon) for
the inspirational L<Acme::Test::Buffy>. Thanks to Andy Lester for lots of patches.

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

A git repository for this module is available at

    git://github.com/rgs/Test-LongString.git

=head1 SEE ALSO

L<Test::Builder>, L<Test::Builder::Tester>, L<Test::More>.

=cut
