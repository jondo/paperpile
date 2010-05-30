package BibTeX::Parser::Defly;

use warnings;
use strict;
use Exporter;
use Encode;

our @ISA = Exporter::;
our @EXPORT = qw"defly";

our(%allfly, $defly_debug);

sub uchr {
	my($c) = @_;
	encode_utf8(chr($c));
}

sub init {
	my @a = allsrc();
	0 == @a % 2 or die "odd number of elements in allraw";
	for my $n (0 .. @a/2 - 1) {
		my($k, $v) = @a[2 * $n, 1 + 2 * $n];
		$allfly{$k} = uchr(hex($v));
	}
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
		(?#9)(AA|AE|DH|DJ|L|NG|O|OE|TH|SS|aa|ae|dh|dj|i|j|l|ng|o|oe|ss|th)
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
	my $all = $1;
	my $trf = $3 || $4;
	my $bas = $6 || $7;
	my $seu = $9;
	my $cod = defined($11) ? hex($11) : defined($12) ? oct($12) : $10;
	my $baserr = defined($8);
	my $coderr = defined($13);
	$defly_debug and warn "DEBUG defly: ext match: " . do {
		no warnings "uninitialized"; "all ($all) trf ($trf) bas ($bas) seu ($seu) cod ($cod) baserr ($baserr) coderr ($coderr)"; 
	};
	my $k;
	#print "$all $trf $bas $seu $cod $baserr $coderr\n";
	if ($baserr) {
		defly_warn "unsupported flying accent format ($all)";
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
	if (defined($k)) {
		if (defined(my $v = $allfly{$k})) {
			return $v;
		} else {
			defly_warn "unknown flying accented letter ($all)";
		}
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
;

sub defly_test {
  $defly_debug = 1;
  while (<>) {
    print defly($_);
  }
}
;

init();

sub allsrc {
  qw(
    \`{A} c0
    \'{A} c1
    \^{A} c2
    \~{A} c3
    \"{A} c4
    \AA c5
    \AE c6
    \c{C} c7
    \`{E} c8
    \'{E} c9
    \^{E} ca
    \"{E} cb
    \`{I} cc
    \'{I} cd
    \^{I} ce
    \"{I} cf
    \DH d0
    \~{N} d1
    \`{O} d2
    \'{O} d3
    \^{O} d4
    \~{O} d5
    \"{O} d6
    \O d8
    \`{U} d9
    \'{U} da
    \^{U} db
    \"{U} dc
    \'{Y} dd
    \TH de
    \ss df
    \`{a} e0
    \'{a} e1
    \^{a} e2
    \~{a} e3
    \"{a} e4
    \aa e5
    \ae e6
    \c{c} e7
    \`{e} e8
    \'{e} e9
    \^{e} ea
    \"{e} eb
    \`{i} ec
    \'{i} ed
    \^{i} ee
    \"{i} ef
    \dh f0
    \~{n} f1
    \`{o} f2
    \'{o} f3
    \^{o} f4
    \~{o} f5
    \"{o} f6
    \o f8
    \`{u} f9
    \'{u} fa
    \^{u} fb
    \"{u} fc
    \'{y} fd
    \th fe
    \"{y} ff
    \={A} 100
    \={a} 101
    \u{A} 102
    \u{a} 103
    \k{A} 104
    \k{a} 105
    \'{C} 106
    \'{c} 107
    \^{C} 108
    \^{c} 109
    \.{C} 10a
    \.{c} 10b
    \v{C} 10c
    \v{c} 10d
    \v{D} 10e
    \v{d} 10f
    \DJ 110
    \dj 111
    \={E} 112
    \={e} 113
    \u{E} 114
    \u{e} 115
    \.{E} 116
    \.{e} 117
    \k{E} 118
    \k{e} 119
    \v{E} 11a
    \v{e} 11b
    \^{G} 11c
    \^{g} 11d
    \u{G} 11e
    \u{g} 11f
    \.{G} 120
    \.{g} 121
    \c{G} 122
    \c{g} 123
    \^{H} 124
    \^{h} 125
    \~{I} 128
    \~{i} 129
    \={I} 12a
    \={i} 12b
    \u{I} 12c
    \u{i} 12d
    \k{I} 12e
    \k{i} 12f
    \.{I} 130
    \i 131
    \^{J} 134
    \^{j} 135
    \c{K} 136
    \c{k} 137
    \'{L} 139
    \'{l} 13a
    \c{L} 13b
    \c{l} 13c
    \v{L} 13d
    \v{l} 13e
    \L 141
    \l 142
    \'{N} 143
    \'{n} 144
    \c{N} 145
    \c{n} 146
    \v{N} 147
    \v{n} 148
    \NG 14a
    \ng 14b
    \={O} 14c
    \={o} 14d
    \u{O} 14e
    \u{o} 14f
    \H{O} 150
    \H{o} 151
    \OE 152
    \oe 153
    \'{R} 154
    \'{r} 155
    \c{R} 156
    \c{r} 157
    \v{R} 158
    \v{r} 159
    \'{S} 15a
    \'{s} 15b
    \^{S} 15c
    \^{s} 15d
    \c{S} 15e
    \c{s} 15f
    \v{S} 160
    \v{s} 161
    \c{T} 162
    \c{t} 163
    \v{T} 164
    \v{t} 165
    \~{U} 168
    \~{u} 169
    \={U} 16a
    \={u} 16b
    \u{U} 16c
    \u{u} 16d
    \r{U} 16e
    \r{u} 16f
    \H{U} 170
    \H{u} 171
    \k{U} 172
    \k{u} 173
    \^{W} 174
    \^{w} 175
    \^{Y} 176
    \^{y} 177
    \"{Y} 178
    \'{Z} 179
    \'{z} 17a
    \.{Z} 17b
    \.{z} 17c
    \v{Z} 17d
    \v{z} 17e
  );
}

1;
