package BibTeX::Parser::Defly;

use warnings;
use strict;
use Exporter;
use Encode;
use BibTeX::Parser::EncodingTable;

our @ISA = Exporter::;
our @EXPORT = qw"defly";

our(%allfly, $defly_debug);

sub uchr {
  my($c) = @_;
  encode_utf8(chr($c));
}

sub init {
  %allfly = %BibTeX::Parser::EncodingTable::latex_umlaute_table;

}

sub defly_warn {
  my($s) = join("", @_);
  warn "defly warning: ", $s;
}

our $quickma = qr/\\(?:[\"\'.=^`~]|(?:uchar|H|b|c|d|k|r|t|u|v|AA|AE|DH|DJ|L|NG|O|OE|TH|SS|aa|ae|dh|dj|i|j|l|ng|o|oe|ss|th)(?![a-zA-Z]))/x;

our $extma = qr/(?xs)
	(?#1)(
	(?#2)(\{)? 
	(?:
	\\ (?: (?#3)([\"\'.=^`~]) | (?#4)([Hbcdkrtuv]) (?![a-zA-Z])[ \t]*\s? )
		(?#5)(\{)? (?: 
		 	(?#6)([a-zA-Z]) | 
		 	\\(?#7)([ij])(?![a-zA-Z])[ \t]*\s? | 
		 	(?#8)() 
		) (?(5)\}|)
	|
	\\
		(?#9)(AA|AE|DH|DJ|L|NG|O|OE|TH|SS|aa|ae|dh|dj|i|j|l|ng|o|oe|ss|th|P|S)
		(?![a-zA-Z])[ \t]*\s?
	|
	\\uchar (?![a-zA-Z]) (?: \{ [ \t]*\s?(?:
		(?#10)([0-9]+) | \"(?#11)([0-9a-fA-F]+) | \'(?#12)([0-7]+)
		)[ \t]*\s \} | (?#13)() )
	) 
	(?(2) (?:\{\})? \} | ) 
	(?:{\}|\\(?=\s))?
	)
/;

sub extva {
  my $all    = $1;
  my $trf    = $3 || $4;
  my $bas    = $6 || $7;
  my $seu    = $9;
  my $cod    = defined($11) ? hex($11) : defined($12) ? oct($12) : $10;
  my $baserr = defined($8);
  my $coderr = defined($13);
  $defly_debug and warn "DEBUG defly: ext match: " . do {
    no warnings "uninitialized";
    "all ($all) trf ($trf) bas ($bas) seu ($seu) cod ($cod) baserr ($baserr) coderr ($coderr)";
  };
  my $k;

  if ($baserr) {
    if ( $all ne '\~{}' ) {
      defly_warn "unsupported flying accent format ($all)";
    }
  } elsif ($coderr) {
    defly_warn "unsupported use of \\uchar ($all)";
  } elsif ($trf) {
    $k = "\\" . $trf . "{" . $bas . "}";
  } elsif ($seu) {
    $k = "\\" . $seu;
  } elsif ($cod) {
    return uchr($cod);
  } else {
    defly_warn "bug in flying accent handling code";
  }
  if ( defined($k) ) {
    if ( defined( my $v = $allfly{$k} ) ) {
      return $v;
    } else {
      defly_warn "unknown flying accented letter ($all)";
      # we warn and convert it to the letter in braces
      # otherwise we have the ugly backslash in the name

      if ( $k =~ m/.*\{([a-z])\}$/ ) {
	return $1;
      }
    }
  } else {
    return '\~{}' if ( $all eq '\~{}' );
  }
  return $all;
}

sub defly {
  my ($s) = @_;
  if ( $s =~ /$quickma/ ) {
    $defly_debug and warn "DEBUG defly: quick match on string: ($s)";
    $s =~ s/$extma/extva()/ge;
  }
  return $s;
}


sub defly_test {
  $defly_debug = 1;
  while (<>) {
    print defly($_);
  }
}


init();


1;
