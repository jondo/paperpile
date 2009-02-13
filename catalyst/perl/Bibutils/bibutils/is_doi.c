/*
 * is_doi.c
 *
 * Copyright (c) Chris Putnam 2008
 *
 * Program and source code released under the GPL
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "newstr.h"
#include "newstr_conv.h"
#include "fields.h"
#include "name.h"
#include "title.h"
#include "serialno.h"
#include "reftypes.h"
#include "risin.h"

/* Rules for the pattern:
 *   '#' = number
 *   isalpha() = match precisely (matchcase==1) or match regardless of case
 *   	(matchcase==0)
 *   all others must match precisely
 */
static int
string_pattern( char *s, char *pattern, int matchcase )
{
	int patlen, match, i;
	patlen = strlen( pattern );
	if ( strlen( s ) < patlen ) return 0; /* too short */
	for ( i=0; i<patlen; ++i ) {
		match = 0;
		if ( pattern[i]=='#' ) {
			if ( isdigit( s[i] ) ) match = 1;
		} else if ( !matchcase && isalpha( pattern[i] ) ) {
			if ( tolower(pattern[i])==tolower(s[i])) match = 1;
		} else {
			if ( pattern[i] == s[i] ) match = 1;
		}
		if ( !match ) return 0;
	}
	return 1;
}

/* science direct is now doing "M3  - doi: DOI: 10.xxxx/xxxxx" */
int
is_doi( char *s )
{
	if ( string_pattern( s, "##.####/", 0 ) ) return 0;
	if ( string_pattern( s, "doi:##.####/", 0 ) ) return 4;
	if ( string_pattern( s, "doi: DOI: ##.####/", 0 ) ) return 10;
	return -1;
}
