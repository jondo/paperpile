package BibTeX::Parser::EncodingTable;

use strict;
use warnings;
use Encode;

our @latex_umlaute = qw(
  \"A 00c4
  \"E 00cb
  \"I 00cf
  \"O 00d6
  \"U 00dc
  \"Y 0178
  \"\i 00ef
  \"a 00e4
  \"e 00eb
  \"o 00f6
  \"u 00fc
  \"y 00ff
  \"{A} c4
  \"{E} cb
  \"{I} cf
  \"{O} d6
  \"{U} dc
  \"{Y} 178
  \"{a} e4
  \"{e} eb
  \"{i} ef
  \"{o} f6
  \"{u} fc
  \"{y} ff
  \"{} 00a8
  \'{A} c1
  \'{C} 106
  \'{E} c9
  \'{I} cd
  \'{L} 139
  \'{N} 143
  \'{O} d3
  \'{R} 154
  \'{S} 15a
  \'{U} da
  \'{Y} dd
  \'{Z} 179
  \'{a} e1
  \'{c} 107
  \'{e} e9
  \'{i} ed
  \'{l} 13a
  \'{n} 144
  \'{o} f3
  \'{r} 155
  \'{s} 15b
  \'{u} fa
  \'{y} fd
  \'{z} 17a
  \.E 0116
  \.G 0120
  \.I 0130
  \.e 0117
  \.g 0121
  \.{C} 10a
  \.{E} 116
  \.{G} 120
  \.{I} 130
  \.{Z} 17b
  \.{c} 10b
  \.{e} 117
  \.{g} 121
  \.{z} 17c
  \.{} 02d9
  \=A 0100
  \=E 0112
  \=I 012a
  \=O 014c
  \=\i 012b
  \=a 0101
  \=e 0113
  \=o 014d
  \={A} 100
  \={E} 112
  \={I} 12a
  \={O} 14c
  \={U} 16a
  \={a} 101
  \={e} 113
  \={i} 12b
  \={o} 14d
  \={u} 16b
  \={} 00af
  \AA c5
  \AE c6
  \DH d0
  \DJ 110
  \H{O} 150
  \H{U} 170
  \H{o} 151
  \H{u} 171
  \H{} 02dd
  \L 141
  \NG 14a
  \O d8
  \OE 152
  \P b6
  \S a7
  \TH de
  \^A 00c2
  \^E 00ca
  \^G 011c
  \^H 0124
  \^I 00ce
  \^J 0134
  \^O 00d4
  \^U 00db
  \^\i 00ee
  \^\j 0135
  \^a 00e2
  \^e 00ea
  \^g 011d
  \^h 0125
  \^o 00f4
  \^u 00fb
  \^{A} c2
  \^{C} 108
  \^{E} ca
  \^{G} 11c
  \^{H} 124
  \^{I} ce
  \^{J} 134
  \^{O} d4
  \^{S} 15c
  \^{U} db
  \^{W} 174
  \^{Y} 176
  \^{a} e2
  \^{c} 109
  \^{e} ea
  \^{g} 11d
  \^{h} 125
  \^{i} ee
  \^{j} 135
  \^{o} f4
  \^{s} 15d
  \^{u} fb
  \^{w} 175
  \^{y} 177
  \`A 00c0
  \`E 00c8
  \`I 00cc
  \`O 00d2
  \`U 00d9
  \`\i 00ec
  \`a 00e0
  \`e 00e8
  \`o 00f2
  \`u 00f9
  \`{A} c0
  \`{E} c8
  \`{I} cc
  \`{O} d2
  \`{U} d9
  \`{a} e0
  \`{e} e8
  \`{i} ec
  \`{o} f2
  \`{u} f9
  \aa e5
  \ae e6
  \c{A} 0104
  \c{C} c7
  \c{E} 0118
  \c{G} 122
  \c{I} 012e
  \c{K} 136
  \c{L} 13b
  \c{N} 145
  \c{R} 156
  \c{S} 15e
  \c{T} 162
  \c{a} 0105
  \c{c} e7
  \c{e} 0119
  \c{g} 123
  \c{i} 012f
  \c{k} 137
  \c{l} 13c
  \c{n} 146
  \c{r} 157
  \c{s} 15f
  \c{t} 163
  \c{} 02db
  \dh f0
  \dj 111
  \i 131
  \k{A} 104
  \k{E} 118
  \k{I} 12e
  \k{U} 172
  \k{a} 105
  \k{e} 119
  \k{i} 12f
  \k{u} 173
  \l 142
  \ng 14b
  \o f8
  \oe 153
  \r{U} 16e
  \r{u} 16f
  \ss df
  \th fe
  \u\i 012d
  \u{A} 102
  \u{E} 114
  \u{G} 11e
  \u{I} 12c
  \u{O} 14e
  \u{U} 16c
  \u{a} 103
  \u{e} 115
  \u{g} 11f
  \u{i} 12d
  \u{o} 14f
  \u{u} 16d
  \u{} 02d8
  \v{C} 10c
  \v{D} 10e
  \v{E} 11a
  \v{L} 13d
  \v{N} 147
  \v{R} 158
  \v{S} 160
  \v{T} 164
  \v{Z} 17d
  \v{c} 10d
  \v{d} 10f
  \v{e} 11b
  \v{l} 13e
  \v{n} 148
  \v{r} 159
  \v{s} 161
  \v{t} 165
  \v{z} 17e
  \v{} 02c7
  \~A 00c3
  \~I 0128
  \~N 00d1
  \~O 00d5
  \~\i 0129
  \~a 00e3
  \~n 00f1
  \~o 00f5
  \~{A} c3
  \~{I} 128
  \~{N} d1
  \~{O} d5
  \~{U} 168
  \~{a} e3
  \~{i} 129
  \~{n} f1
  \~{o} f5
  \~{u} 169
);

our @latex_math_symbols = qw(
  \Delta 0394
  \Gamma 0393
  \Lambda 039b
  \Leftrightarrow 21D4
  \Omega 03a9
  \Phi 03a6
  \Pi 03a0
  \Psi 03a8
  \Rightarrow 21D2
  \Sigma 03a3
  \Theta 0398
  \Upsilon 03a5
  \Xi 039e
  \alpha 03b1
  \approx 2248
  \beta 03b2
  \bot 22A5
  \cap 2229
  \cdot 22C5
  \chi 03c7
  \cup 222A
  \delta 03b4
  \div 00f7
  \emptyset 2205
  \epsilon 03b5
  \equiv 2261
  \eta 03b7
  \exists 2203
  \forall 2200
  \gamma 03b3
  \geq 2265
  \in 2208
  \infty 221E
  \int 222B
  \iota 03b9
  \kappa 03ba
  \lambda 03bb
  \leftarrow 2190
  \leq 2264
  \mathrm{A} 0391
  \mathrm{B} 0392
  \mathrm{E} 0395
  \mathrm{H} 0397
  \mathrm{I} 0399
  \mathrm{K} 039a
  \mathrm{M} 039c
  \mathrm{N} 039d
  \mathrm{O} 039f
  \mathrm{R} 03a1
  \mathrm{T} 03a4
  \mathrm{X} 03a7
  \mathrm{Z} 0396
  \mu 03bc
  \nabla 2207
  \neg 00ac
  \neq 2260
  \not\in 2209
  \nu 03bd
  \omega 03c9
  \partial 2202
  \phi 03c6
  \pi 03c0
  \pm 00B1
  \prod 220F
  \psi 03c8
  \rho 03c1
  \rightarrow 2192
  \sigma 03c3
  \subset 2282
  \sum 2211
  \supset 2283
  \surd 221A
  \tau 03c4
  \theta 03b8
  \times 00d7
  \to 2192
  \upsilon 03c5
  \vee 2228
  \wedge 2227
  \xi 03be
  \zeta 03b6
  < 3c
  > 3e
);

#   \- 00ad
#   \^{} 02c6
#   \~{} 02dc
#   ^1 00b9
#   ^2 00b2
#   ^3 00b3
#   ^\circ 00b0
#   o 03bf

our @latex_other_symbols = (
  '\%',              '25', '\$',               '24', '\&',          '26',
  '\#',              '23', '\_',               '5f', '\pounds',     'a3',
  '\texttimes',      'd7', '?`',               'bf', '!`',          'a1',
  '\S',              'a7', '\texttildelow',    '7e', '\textdollar', '24',
  '\textunderscore', '5f', '\textbackslash',   '5c', '\backslash',  '5c',
  '\copyright',      'a9', '\textasciimacron', 'af',
  '\textcent',       'a2', '\textregistered',  'ae'

);

our (
  %latex_umlaute_table,       %latex_math_symbols_table, $latex_math_symbols_string,
  %latex_other_symbols_table, $latex_other_symbols_string
);

sub init {
  for my $n ( 0 .. @latex_umlaute / 2 - 1 ) {
    my ( $k, $v ) = @latex_umlaute[ 2 * $n, 1 + 2 * $n ];
    $latex_umlaute_table{$k} = encode_utf8( chr( hex($v) ) );
  }

  for my $n ( 0 .. @latex_math_symbols / 2 - 1 ) {
    my ( $k, $v ) = @latex_math_symbols[ 2 * $n, 1 + 2 * $n ];
    $latex_math_symbols_table{$k} = $v;
  }

  $latex_math_symbols_string = join( '|', sort keys %latex_math_symbols_table );
  $latex_math_symbols_string =~ s/\\/\\\\/g;

  for my $n ( 0 .. @latex_other_symbols / 2 - 1 ) {
    my ( $k, $v ) = @latex_other_symbols[ 2 * $n, 1 + 2 * $n ];
    $latex_other_symbols_table{$k} = $v;
  }

  $latex_other_symbols_string = join( '|', sort keys %latex_other_symbols_table );
  $latex_other_symbols_string =~ s/\\/\\\\/g;
  $latex_other_symbols_string =~ s/\!/\\\!/g;
  $latex_other_symbols_string =~ s/\?/\\\?/g;
  $latex_other_symbols_string =~ s/\$/\\\$/g;
  $latex_other_symbols_string =~ s/#/\\#/g;
}

init();

1;
