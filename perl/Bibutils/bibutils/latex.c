/* 
 * latex.c
 *
 * convert between latex special chars and unicode
 *
 * Copyright (c) Chris Putnam 2004-2009
 *
 * Source code released under the GPL
 *
 */
#include <stdio.h>
#include <string.h>
#include "latex.h"

struct latex_chars {
	unsigned int unicode;
	char *bib1, *bib2, *bib3;
};

static struct latex_chars latex_chars[] = { 

   {  35, "\\#",     "",   ""        }, /* Number/pound/hash sign */
   {  36, "\\$",     "",   ""        }, /* Dollar Sign */
   {  37, "\\%",     "",   ""        }, /* Percent Sign */
   {  38, "\\&",     "",   ""        }, /* Ampersand */
   {  92, "{\\backslash}", "\\backslash", ""   }, /* Backslash */
   { 123, "\\{", "{\\textbraceleft}", "\\textbraceleft" }, /* Left Curly Bracket */
   { 125, "\\}", "{\\textbraceright}", "\\textbraceright" }, /* Right Curly Bracket */
   {  95, "\\_",     "", ""        }, /* Underscore alone indicates subscript */
   { 176, "{\\textdegree}", "\\textdegree", "^\\circ" }, /* Degree sign */
   {  32, "~",       "\\ ", ""        }, /* Tilde is a sticky space */
   { 126, "{\\textasciitilde}", "\\textasciitilde", "\\~{}" }, /* How to get a tilde in latex */
                                 /* This is a cheat, should use "\verb" */
                                 /* Need same for ^ character */

                                           /* Latin Capital A */
   { 192, "{\\`A}",  "\\`{A}",  "\\`A"  }, /*               with grave */
   { 193, "{\\'A}",  "\\'{A}",  "\\'A"  }, /*               with acute */
   { 194, "{\\^A}",  "\\^{A}",  "\\^A"  }, /*               with circumflex */
   { 195, "{\\~A}",  "\\~{A}",  "\\~A"  }, /*               with tilde */
   { 196, "{\\\"A}", "\\\"{A}", "\\\"A" }, /*               with diuresis */
   { 197, "{\\AA}",  "",        ""      }, /*               with ring above */

                                           /* Latin Small a */
   { 224, "{\\`a}",  "\\`{a}",  "\\`a"  }, /*               with grave */
   { 225, "{\\'a}",  "\\'{a}",  "\\'a"  }, /*               with acute */
   { 226, "{\\^a}",  "\\^{a}",  "\\^a"  }, /*               with circumflex */
   { 227, "{\\~a}",  "\\~{a}",  "\\~a"  }, /*               with tilde */
   { 228, "{\\\"a}", "\\\"{a}", "\\\"a" }, /*               with diuresis */
   { 229, "{\\aa}",  "",        ""      }, /*               with ring above */

   { 198, "{\\AE}",  "\\AE",    ""      }, /* Latin Capital AE */
   { 230, "{\\ae}",  "\\ae",    ""      }, /* Latin Small ae */

   { 199, "{\\c{C}}","\\c{C}",  ""      }, /* Latin Capital C with cedilla */
   { 231, "{\\c{c}}","\\c{c}",  ""      }, /* Latin small c with cedilla*/
   { 262, "{\\'C}",  "\\'{C}",  "\\'C"  }, /* Latin Capital C with acute */
   { 263, "{\\'c}",  "\\'{c}",  "\\'c"  }, /* Latin small c with acute */

                                           /* Latin Capital E */
   { 200, "{\\`E}",  "\\`{E}",  "\\`E"  }, /*               with grave */
   { 201, "{\\'E}",  "\\'{E}",  "\\'E"  }, /*               with acute */
   { 202, "{\\^E}",  "\\^{E}",  "\\^E"  }, /*               with circumflex */
   { 203, "{\\\"E}", "\\\"{E}", "\\\"E" }, /*               with diuresis */
 
                                           /* Latin Small e */
   { 232, "{\\`e}",  "\\`{e}",  "\\`e"  }, /*               with grave */
   { 233, "{\\'e}",  "\\'{e}",  "\\'e"  }, /*               with acute */
   { 234, "{\\^e}",  "\\^{e}",  "\\^e"  }, /*               with circumflex */
   { 235, "{\\\"e}", "\\\"{e}", "\\\"e" }, /*               with diuresis */
 
                                           /* Latin Capital i */
   { 204, "{\\`I}",  "\\`{I}",  "\\`I"  }, /*               with grave */
   { 205, "{\\'I}",  "\\'{I}",  "\\'I"  }, /*               with acute */
   { 206, "{\\^I}",  "\\^{I}",  "\\^I"  }, /*               with circumflex */
   { 207, "{\\\"I}", "\\\"{I}", "\\\"I" }, /*               with diuresis */

                                           /* Latin Small i */
   { 236, "{\\`i}",  "\\`{i}",  "\\`i"  }, /*               with grave */
   { 237, "{\\'i}",  "\\'{i}",  "\\'i"  }, /*               with acute */
   { 238, "{\\^i}",  "\\^{i}",  "\\^i"  }, /*               with circumflex */
   { 239, "{\\\"i}", "\\\"{i}", "\\\"i" }, /*               with diuresis */
                                           /* Latex \i has no dot on "i"*/
   { 236, "{\\`\\i}",  "\\`{\\i}",  "\\`\\i"  }, /*         with grave */
   { 237, "{\\'\\i}",  "\\'{\\i}",  "\\'\\i"  }, /*         with acute */
   { 238, "{\\^\\i}",  "\\^{\\i}",  "\\^\\i"  }, /*         with circumflex */
   { 239, "{\\\"\\i}", "\\\"{\\i}", "\\\"\\i" }, /*         with diuresis */

   { 209, "{\\~N}",  "\\~{N}",  "\\~N"  }, /* Latin Capital N with tilde */
   { 327, "{\\vN}",  "\\v{N}",  "\\vN"  }, /* Latin Capital N with caron */
   { 241, "{\\~n}",  "\\~{n}",  "\\~n"  }, /* Latin Small n with tilde */
   { 328, "{\\vn}",  "\\v{n}",  "\\vn"  }, /* Latin Small n with caron */
 
                                           /* Latin Capital O */
   { 210, "{\\`O}",  "\\`{O}",  "\\`O"  }, /*               with grave */
   { 211, "{\\'O}",  "\\'{O}",  "\\'O"  }, /*               with acute */
   { 212, "{\\^O}",  "\\^{O}",  "\\^O"  }, /*               with circumflex */
   { 213, "{\\~O}",  "\\~{O}",  "\\~O"  }, /*               with tilde */
   { 214, "{\\\"O}", "\\\"{O}", "\\\"O" }, /*               with diaeresis */
   { 216, "{\\O}",   "\\O",     ""      }, /*               with stroke */

                                           /* Latin Small o */
   { 242, "{\\`o}",  "\\`{o}",  "\\`o"  }, /*               with grave */
   { 243, "{\\'o}",  "\\'{o}",  "\\'o"  }, /*               with acute */
   { 244, "{\\^o}",  "\\^{o}",  "\\^o"  }, /*               with circumflex */
   { 245, "{\\~o}",  "\\~{o}",  "\\~o"  }, /*               with tilde */
   { 246, "{\\\"o}", "\\\"{o}", "\\\"o" }, /*               with diaeresis */
   { 248, "{\\o}",   "\\o",     ""      }, /*               with stroke */

   { 338, "{\\OE}",  "\\OE",    ""      }, /* Latin Capital OE */
   { 339, "{\\oe}",  "\\oe",    ""      }, /* Latin Small oe */

   { 341, "{\\vR}",  "\\v{R}",  "\\vR"  }, /* Latin Capital R with caron */
   { 342, "{\\vr}",  "\\v{r}",  "\\vr"  }, /* Latin Small r with caron */

   { 352, "{\\vS}",  "\\v{S}",  "\\vS"  }, /* Latin Capital S with caron */
   { 353, "{\\vs}",  "\\v{s}",  "\\vs"  }, /* Latin Small s with caron */

   { 223, "{\\ss}",  "\\ss",    ""      }, /* German sz ligature, "sharp s" */

                                           /* Latin Capital U */
   { 217, "{\\`U}",  "\\`{U}",  "\\`U"  }, /*               with grave */
   { 218, "{\\'U}",  "\\'{U}",  "\\'U"  }, /*               with acute */
   { 219, "{\\^U}",  "\\^{U}",  "\\^U"  }, /*               with circumflex */
   { 220, "{\\\"U}", "\\\"{U}", "\\\"U" }, /*               with diaeresis */

                                           /* Latin Small u */
   { 249, "{\\`u}",  "\\`{u}", "\\`u"   }, /*               with grave */
   { 250, "{\\'u}",  "\\'{u}", "\\'u"   }, /*               with acute */
   { 251, "{\\^u}",  "\\^{u}", "\\^u"   }, /*               with circumflex */
   { 252, "{\\\"u}", "\\\"{u}", "\\\"u" }, /*               with diaeresis */

				/* Latin Capital Y */
   { 221, "{\\'Y}",  "\\'{Y}", "\\'Y"   }, /*               with acute */
   { 376, "{\\\"Y}", "\\\"{Y}", "\\\"Y" }, /*               with diaeresis */

				/* Latin Small y */
   { 253, "{\\'y}",  "\\'{y}", "\\'y"   }, /*               with acute */
   { 255, "{\\\"y}", "\\\"{y}", "\\\"y" }, /*               with diaeresis */


                                /* Hacek-containing */
   { 269, "{\\v c}", "{\\v{c}}", "\\v{c}" }, /* c with a hacek */

				/* Needs to be before \nu */
   { 8203, "$\\null$", "\\null", "" },           /* No space &#x200B; */

   { 913, "$\\Alpha$", "\\Alpha", ""       }, /*GREEKCAPITALLETTERALPHA*/
   /* 902 = GREEKCAPITALLETTERALPHAWITHTONOS*/
   { 914, "$\\Beta$",  "\\Beta", ""       }, /*GREEKCAPITALLETTERBETA*/
   { 915, "$\\Gamma$", "\\Gamma", ""       }, /*GREEKCAPITALLETTERGAMMA*/
   { 916, "$\\Delta$", "\\Delta", ""       }, /*GREEKCAPITALLETTERDELTA*/
   { 917, "$\\Epsilon$", "\\Epsilon", ""     }, /*GREEKCAPITALLETTEREPSILON*/
   /* 904 = GREEKCAPITALLETTEREPSILONWITHTONOS*/
   { 918, "$\\Zeta$", "\\Zeta", ""        }, /*GREEKCAPITALLETTERZETA*/
   { 919, "$\\Eta$", "\\Eta", ""         }, /*GREEKCAPITALLETTERETA*/
   /* 905 = GREEKCAPITALLETTERETAWITHTONOS*/
   { 920, "$\\Theta$", "\\Theta", ""       }, /*GREEKCAPITALLETTERTHETA*/
   { 921, "$\\Iota$", "\\Iota", ""        }, /*GREEKCAPITALLETTERIOTA*/
   /* 938 = GREEKCAPITALLETTERIOTAWITHDIALYTIKA*/
   /* 906 = GREEKCAPITALLETTERIOTAWITHTONOS*/
   { 922, "$\\Kappa$", "\\Kappa", ""       }, /*GREEKCAPITALLETTERKAPPA*/
   { 923, "$\\Lambda$", "\\Lambda", ""      }, /*GREEKCAPITALLETTERLAMDA*/
   { 924, "$\\Mu$", "\\Mu", ""          }, /*GREEKCAPITALLETTERMU*/
   { 925, "$\\Nu$", "\\Nu", ""          }, /*GREEKCAPITALLETTERNU*/
   { 926, "$\\Xi$", "\\Xi", ""          }, /*GREEKCAPITALLETTERXI*/
   { 927, "$\\Omicron$", "\\Omicron", ""     }, /*GREEKCAPITALLETTEROMICRON*/
   /* 908 = GREEKCAPITALLETTEROMICRONWITHTONOS*/
   { 928, "$\\Pi$", "\\Pi", ""          }, /*GREEKCAPITALLETTERPI*/
   { 929, "$\\Rho$", "\\Rho", ""         }, /*GREEKCAPITALLETTERRHO*/
   { 931, "$\\Sigma$", "\\Sigma", ""       }, /*GREEKCAPITALLETTERSIGMA*/
   { 932, "$\\Tau$", "\\Tau", ""         }, /*GREEKCAPITALLETTERTAU*/
   { 933, "$\\Upsilon$", "\\Upsilon", ""     }, /*GREEKCAPITALLETTERUPSILON*/
   /* 939 = GREEKCAPITALLETTERUPSILONWITHDIALYTIKA*/
   /* 910 = GREEKCAPITALLETTERUPSILONWITHTONOS*/
   { 934, "$\\Phi$", "\\Phi", ""         }, /*GREEKCAPITALLETTERPHI*/
   { 935, "$\\Chi$", "\\Chi", ""         }, /*GREEKCAPITALLETTERCHI*/
   { 936, "$\\Psi$", "\\Psi", ""         }, /*GREEKCAPITALLETTERPSI*/
   { 937, "$\\Omega$", "\\Omega", ""       }, /*GREEKCAPITALLETTEROMEGA*/
   /* 911, = GREEKCAPITALLETTEROMEGAWITHTONOS*/

   { 945, "$\\alpha$", "\\alpha", ""       }, /*GREEKSMALLLETTERALPHA*/
   /* 940 = GREEKSMALLLETTERALPHAWITHTONOS*/
   { 946, "$\\beta$", "\\beta", ""        }, /*GREEKSMALLLETTERBETA*/
   { 968, "$\\psi$", "\\psi", ""         }, /*GREEKSMALLLETTERPSI*/
   { 948, "$\\delta$", "\\delta", ""       }, /*GREEKSMALLLETTERDELTA*/
   { 949, "$\\epsilon$", "\\epsilon", ""     }, /*GREEKSMALLLETTEREPSILON*/
   /* 941 = GREEKSMALLLETTEREPSILONWITHTONOS*/
   { 966, "$\\phi$", "\\phi", ""         }, /*GREEKSMALLLETTERPHI*/
   { 947, "$\\gamma$", "\\gamma", ""       }, /*GREEKSMALLLETTERGAMMA*/
   { 951, "$\\eta$", "\\eta", ""         }, /*GREEKSMALLLETTERETA*/
   /* 942 = GREEKSMALLLETTERETAWITHTONOS */
   { 953, "$\\iota$", "\\iota", ""        }, /*GREEKSMALLLETTERIOTA*/
   /* 912 = GREEKSMALLLETTERIOTAWITHDIALYTIKAANDTONOS*/
   /* 943 = GREEKSMALLLETTERIOTAWITHTONOS */
   /* 970 = GREEKSMALLLETTERIOTAWITHDIALYTIKA */
   { 958, "$\\xi$", "\\xi", ""          }, /*GREEKSMALLLETTERXI*/
   { 954, "$\\kappa$", "\\kappa" , ""      }, /*GREEKSMALLLETTERKAPPA*/
   { 955, "$\\lambda$", "\\lambda", ""      }, /*GREEKSMALLLETTERLAMDA*/
   { 956, "$\\mu$", "\\mu", ""          }, /*GREEKSMALLLETTERMU*/
   { 957, "$\\nu$", "\\nu", ""          }, /*GREEKSMALLLETTERNU*/
   { 959, "$\\omicron$", "\\omicron", ""     }, /*GREEKSMALLLETTEROMICRON*/
   /* 972 = GREEKSMALLLETTEROMICRONWITHTONOS*/
   { 960, "$\\pi$", "\\pi", ""          }, /*GREEKSMALLLETTERPI*/
   { 961, "$\\rho$", "\\rho", ""         }, /*GREEKSMALLLETTERRHO*/
   { 963, "$\\sigma$", "\\sigma", ""       }, /*GREEKSMALLLETTERSIGMA*/
   { 964, "$\\tau$", "\\tau", ""         }, /*GREEKSMALLLETTERTAU*/
   { 952, "$\\theta$", "\\theta", ""       }, /*GREEKSMALLLETTERTHETA*/
   { 969, "$\\omega$", "\\omega", ""       }, /*GREEKSMALLLETTEROMEGA*/
   /* 974 = GREEKSMALLLETTEROMEGAWITHTONOS*/
   { 967, "$\\chi$", "\\chi", ""         }, /*GREEKSMALLLETTERCHI*/
   { 965, "$\\upsilon$", "\\upsilon", ""     }, /*GREEKSMALLLETTERUPSILON*/
   /* 973 = GREEKSMALLLETTERUPSILONWITHTONOS*/
   /* 971 = GREEKSMALLLETTERUPSILONWITHDIALYTIKA*/
   /* 944 = GREEKSMALLLETTERUPSILONWITHDIALYTIKAANDTONOS*/
   { 950, "$\\zeta$", "\\zeta", ""        },  /*GREEKSMALLLETTERZETA*/

   { 181, "{\\textmu}", "\\textmu", "$\\mu$" }, /* 181=micro sign, techically &#xB5; */

/* Make sure that these don't stomp on other latex things above */

   { 8242, "{\\textasciiacutex}", "\\textasciiacutex", "$'$" },  /* Prime symbol &#x2032; */
   { 180, "{\\textasciiacute}", "\\textasciiacute", "\\'" }, /* acute accent &#xB4; */
/*   { 769,  "\\'",    "", "" },*/  /* Acute accent &#x0301;--apply to next char */

   { 8243, "{\\textacutedbl}", "\\textacutedbl", "$''$" },  /* Double prime &#x2033; */
   { 8245, "{\\textasciigrave}", "\\textasciigrave", "\\`" }, /* Grave accent &#x2035; */
/*   { 768,  "\\`",    "", "" },*/  /* Grave accent &#x0300;--apply to next char */

   { 8963, "{\\textasciicircum}", "\\textasciicircum", ""} , /* &#x2303; */
   { 184,  "{\\textasciicedilla}", "\\textasciicedilla", "" },  /* cedilla &#xB8; */
   { 168,  "{\\textasciidieresis}", "\\textasciidieresis", "" }, /* dieresis &#xA8; */
   { 175,  "{\\textasciimacron}", "\\textasciimacron", "" }, /* macron &#xAF; */

   { 8593, "{\\textuparrow}", "\\textuparrow", "" },    /* Up arrow &#x2191; */
   { 8595, "{\\textdownarrow}", "\\textdownarrow", "" },  /* Down arrow &#x2193; */
   { 8594, "{\\textrightarrow}", "\\textrightarrow", "" }, /* Right arrow &#x2192; */
   { 8592, "{\\textleftarrow}", "\\textleftarrow", "" },  /* Left arrow &#x2190; */
   { 12296, "{\\textlangle}", "\\textlangle", "" } ,   /* L-angle &#x3008; */
   { 12297, "{\\textrangle}", "\\textrangle", "" } ,   /* L-angle &#x3009; */

   { 166, "{\\textbrokenbar}", "\\textbrokenbar", "" }, /* Broken vertical bar &#xA6; */
   { 167, "{\\textsection}", "\\textsection", "" },   /* Section sign, &#xA7; */
   { 170, "{\\textordfeminine}", "\\textordfeminine", "" }, /* &#xAA; */
   { 172, "{\\textlnot}", "\\textlnot", "" },      /* Lnot &#xAC; */
   { 182, "{\\textparagraph}", "\\textparagraph", "" }, /* Paragraph sign &#xB6; */
   { 183, "{\\textperiodcentered}", "\\textperiodcentered", "" }, /* Period-centered &#xB7; */
   { 186, "{\\textordmasculine}", "\\textordmasculine", "" }, /* &#xBA; */
   { 8214, "{\\textbardbl}", "\\textbardbl", "" },   /* Double vertical bar &#x2016; */
   { 8224, "{\\textdagger}", "\\textdagger", "" },   /* Dagger &#x2020; */
   { 8225, "{\\textdaggerdbl}", "\\textdaggerdbl", "" },/* Double dagger &x2021; */
   { 8226, "{\\textbullet}", "\\textbullet", "" },   /* Bullet &#x2022; */
   { 8494, "{\\textestimated}", "\\textestimated", "" },/* Estimated &#x212E; */
   { 9526, "{\\textopenbullet}", "\\textopenbullet", "" },/* &#x2536; */

   { 8220, "``", "{\\textquotedblleft}", "\\textquotedblleft" }, /* Opening double quote &#x201C; */
   { 8221, "''", "{\\textquotedblright}","\\textquotedblright" }, /* Closing double quote &#x201D; */
   { 8216, "`",  "{\\textquoteleft}", "\\textquoteleft" },    /* Opening single quote &#x2018; */
   { 8217, "'",  "{\\textquoteright}", "\\textquoteright" },   /* Closing single quote &#x2019; */
   { 8261, "{\\textlquill}", "\\textlquill", "" },         /* Left quill &#x2045; */
   { 8262, "{\\textrquill}", "\\textrquill", "" },         /* Right quill &#x2046; */

   { 8212, "---",     "{\\textemdash}", "\\textemdash" },     /* Em-dash &#x2014; */
   { 8211, "--",      "{\\textendash}", "\\textendash" },     /* En-dash &#x2013; */
   { 8230, "\\ldots", "{\\textellipsis}", "\\textellipsis" },   /* Ellipsis &#x2026; */

   { 8194, "\\enspace", "\\hspace{.5em}", "" }, /* En-space &#x2002; */
   { 8195, "\\emspace", "\\hspace{1em}",  "" }, /* Em-space &#x2003; */
   { 8201, "\\thinspace", "", ""},              /* Thin space &#x2009; */
   { 8203, "{\\textnospace}", "\\textnospace", "" },           /* No space &#x200B; */
   { 9251, "{\\textvisiblespace}", "\\textvisiblespace", "" },      /* Visible space &#x2423; */

   { 215, "{\\texttimes}", "\\texttimes", "" }, /* Multiplication symbol &#xD7; */
   { 247, "{\\textdiv}", "\\textdiv", "" },   /* Division symbol &#xF7; */
   { 177, "{\\textpm}", "\\textpm", "" }, /* Plus-minus character &#B1; */
   { 189, "{\\textonehalf}", "\\textonehalf", "" }, /* Vulgar fraction one half &#xBD; */
   { 188, "{\\textonequarter}", "\\textonequarter", "" }, /* Vulgar fraction one quarter &#xBD; */
   { 190, "{\\textthreequarters}", "\\textthreequarters", "" }, /* Vulgar fraction three quarters &#xBE; */
   { 8240, "{\\texttenthousand}", "\\texttenthousand", "" }, /* Per thousand sign &#x2030; */
   { 8241, "{\\textpertenthousand}", "\\textpertenthousand", "" }, /* Per ten thousand sign &#x2031;*/
   { 8260, "{\\textfractionsolidus}", "\\textfractionsolidus", "" }, /* &x8260; */
   { 8451, "{\\textcelcius}", "\\textcelcius", "" }, /* Celcicus &#x2103; */
   { 8470, "{\\textnumero}", "\\textnumero", "" },  /* Numero symbol &#x2116; */
   { 8486, "{\\textohm}", "\\textohm", "" }, /* Ohm symbol &#x2126; */
   { 8487, "{\\textmho}", "\\textmho", "" }, /* Mho symbol &#x2127; */
   { 8730, "{\\textsurd}", "\\textsurd", "" }, /* &#x221A; */

   { 185, "{\\textonesuperior}", "\\textonesuperior", "" },   /*Superscript 1 &#xB9; */
   { 178, "{\\texttwosuperior}", "\\texttwosuperior", "" },   /*Superscript 2 &#xB2; */
   { 179, "{\\textthreesuperior}", "\\textthreesuperior", "" }, /*Superscript 3 &#xB3; */

   { 161, "{\\textexclamdown}", "\\textexclamdown", "" },   /* Inverted exclamation mark &#xA1;*/
   { 191, "{\\textquestiondown}", "\\textquestiondown", "" }, /* Inverted question mark &#xBF; */

   { 162, "{\\textcent}", "\\textcent", "" },         /* Cent sign &#xA2; */
   { 163, "{\\textsterling}", "\\textsterling", "\\pounds" },     /* Pound sign &#xA3; */
   { 165, "{\\textyen}", "\\textyen", "" },          /* Yen sign &#xA5; */
   { 402, "{\\textflorin}", "\\textflorin", "" },       /* Florin sign &#x192; */
   { 3647, "{\\textbaht}", "\\textbaht", "" },        /* Thai currency &#xE3F; */
   { 8355, "{\\textfrenchfranc}", "\\textfrenchfranc", "" }, /* French franc &#x20A3; */
   { 8356, "{\\textlira}", "\\textlira", "" },        /* Lira &#x20A4; */
   { 8358, "{\\textnaira}", "\\textnaria", "" },       /* Naira &#x20A6; */
   { 8361, "{\\textwon}", "\\textwon", "" },         /* &#x20A9; */
   { 8363, "{\\textdong}", "\\textdong", "" },        /* Vietnamese currency &#x20AB; */
   { 8364, "{\\texteuro}", "\\texteuro", "" },        /* Euro sign */

   { 169, "{\\textcopyright}", "\\textcopyright", "" },           /* Copyright (C) &#xA9; */
   { 175, "{\\textregistered}", "\\textregistered", "" },          /* Registered sign (R) &#xAF;*/
   { 8482, "{\\texttrademark}", "\\texttrademark", "$^{TM}$" },   /* Trademark (TM) &#x2122; */
   { 8480, "{\\textservicemark}", "\\textservicemark", "$^{SM}$" }, /* Servicemark (SM) &#x2120;*/
   { 8471, "{\\textcircledP}", "\\textcircledP", "" },           /* Circled P &#2117; */

};

static int nlatex_chars = sizeof(latex_chars)/sizeof(struct latex_chars);

/* latex2char()
 *
 *   Use the latex_chars[] lookup table to determine if any character
 *   is a special LaTeX code.  Note that if it is, then the equivalency
 *   is a Unicode character and we need to flag (by setting *unicode to 1)
 *   that we know the output is Unicode.  Otherwise, we set *unicode to 0,
 *   meaning that the output is whatever character set was given to us
 *   (which could be Unicode, but is not necessarily Unicode).
 *
 */
unsigned int
latex2char( char *s, unsigned int *pos, int *unicode )
{
	unsigned int value;
	char *p, *q[3];
	int i, j, l[3];
	p = &( s[*pos] );
	value = (unsigned char) *p;
	for ( i=0; i<nlatex_chars; ++i ) {
		q[0] = latex_chars[i].bib1;
		l[0] = strlen( q[0] );
		q[1] = latex_chars[i].bib2;
		l[1] = strlen( q[1] );
		q[2] = latex_chars[i].bib3;
		l[2] = strlen( q[2] );
		for ( j=0; j<3; ++j ) {
			if ( l[j] && !strncmp( p, q[j], l[j] ) ) {
				*pos = *pos + l[j];
				*unicode = 1;
				return latex_chars[i].unicode;
			}
		}
	}
	*unicode = 0;
	*pos = *pos + 1;
	return value;
}

void
uni2latex( unsigned int ch, char buf[], int buf_size )
{
	int i;
	buf[0] = '?';
	buf[1] = '\0';
	if ( ch==' ' ) {
		buf[0] = ' '; /*special case to avoid &nbsp;*/
		return;
	}
	for ( i=0; i<nlatex_chars; ++i ) {
		if ( ch == latex_chars[i].unicode ) {
			strncpy( buf, latex_chars[i].bib1, buf_size );
			buf[ buf_size-1 ] = '\0';
			return;
		}
	}
	if ( ch < 128 && buf[0]=='?' ) buf[0] = (char)ch;
}

