/*
 * newstring_conv.h
 *
 * Copyright (c) Chris Putnam 1999-2009
 *
 * Source code released under the GPL
 *
 */

#ifndef NEWSTR_CONV_H
#define NEWSTR_CONV_H

#include "newstr.h"

#define CHARSET_UNKNOWN (-1)
#define CHARSET_UNICODE (-2)
#define CHARSET_GB18030 (-3)
#define CHARSET_DEFAULT (66)  /* Latin-1/ISO8859-1 */

extern int get_charset( char *name );
extern void list_charsets( FILE *fp );
extern void newstr_convert( newstr *s, 
		int charsetin, int latexin, int utf8in, int xmlin, 
		int charsetout, int latexout, int utf8out, int xmlout );


#endif

