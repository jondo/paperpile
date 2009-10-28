/*
 * name.c
 *
 * mangle names w/ and w/o commas
 *
 * Copyright (c) Chris Putnam 2004-2009
 *
 * Source code released under the GPL
 *
 */
#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include "is_ws.h"
#include "newstr.h"
#include "fields.h"
#include "list.h"
#include "name.h"

static void
check_case( char *start, char *end, int *upper, int *lower )
{
	int u = 0, l = 0;
	char *p = start;
	while ( p < end ) {
		if ( islower( *p ) ) l = 1;
		else if ( isupper( *p ) ) u = 1;
		p++;
	}
	*upper = u;
	*lower = l;
}

static int
should_split( char *last_start, char *last_end, char *first_start, 
	char *first_end )
{
	int upperlast, lowerlast, upperfirst, lowerfirst;
        check_case( first_start, first_end, &upperfirst, &lowerfirst );
        check_case( last_start,  last_end,  &upperlast,  &lowerlast );
        if ( ( upperlast && lowerlast ) && ( upperfirst && !lowerfirst ) )
                return 1;
        else return 0;
}

/* name_addmultibytechar
 * 
 * Add character to newstring s starting at pointer p.
 *
 * Handles the case for multibyte Unicode chars (with high bits
 * set).  Do not progress past the lastp barrier.
 *
 * Since we can progress more than one byte in the string,
 * return the properly updated pointer p.
 */
static char *
name_addmultibytechar( newstr *s, char *p, char *lastp )
{
	if ( ! ((*p) & 128) ) {
		newstr_addchar( s, *p );
		p++;
	} else {
		while ( p!=lastp && ((*p) & 128) ) {
			newstr_addchar( s, *p );
			p++;
		}
	}
	return p;
}

static void
name_givennames_nosplit( char *start_first, char *end_first, newstr *outname )
{
	char *p;
	p = start_first;
	while ( p!=end_first ) {
		if ( !is_ws( *p ) && *p!='.' ) {
			p = name_addmultibytechar( outname, p, end_first );
		} else {
			if ( *p=='.' ) p++;
			while ( p!=end_first && is_ws( *p ) ) p++;
			if ( p!=end_first )
				newstr_addchar( outname, '|' );
		}
	}
}

static void
name_givennames_split( char *start_first, char *end_first, newstr *outname )
{
	int n = 0;
	char *p;
	p = start_first;
	while ( p!=end_first ) {
		if ( !is_ws( *p ) ) {
			if ( *p=='.' && *(p+1)=='-' ) {
				newstr_strcat( outname, ".-" );
				p++; p++;
				p = skip_ws( p );
				p = name_addmultibytechar( outname, p, end_first );
				newstr_addchar( outname, '.' );
				n++;
			} else if ( *p=='.' ) {
				p++;
			} else if ( *p=='-' ) {
				newstr_strcat( outname, ".-" );
				p++;
				p = skip_ws( p );
				p = name_addmultibytechar( outname, p, end_first );
				newstr_addchar( outname, '.' );
				n++;
			} else {
				if ( n ) newstr_addchar( outname, '|' );
				p = name_addmultibytechar( outname, p, end_first );
				n++;
			}
		} else {
			while ( p!=end_first && is_ws( *p ) ) p++;
		}
	}
}

static void
name_givennames( char *first_start, char *first_end, char *last_start,
	char *last_end, newstr *outname )
{
	int splitfirst;
        newstr_addchar( outname, '|' );
	splitfirst = should_split( last_start, last_end, first_start, 
		first_end );
	if ( !splitfirst )
		name_givennames_nosplit( first_start, first_end, outname );
	else 
		name_givennames_split( first_start, first_end, outname );
}

static char *
string_end( char *p )
{
	while ( *p ) p++;
	return p;
}


/* name_nocomma()
 *
 * names in the format "H. F. Author"
 */
void
name_nocomma( char *start, newstr *outname )
{
        char *p, *last_start, *last_end, *first_start, *first_end;

        /** Last name **/
	p = last_end = string_end( start );
	while ( p!=start && !is_ws( *p ) ) p--;
	if ( !strcasecmp( p+1, "Jr." ) || !strcasecmp( p+1, "III" ) ) {
		while ( p!=start && is_ws( *p ) ) p--;
		while ( p!=start && !is_ws( *p ) ) p--;
	}
	last_start = p = skip_ws( p );
        while ( p!=last_end )
                newstr_addchar( outname, *p++ );

        /** Given names **/
        if ( start!=last_start ) {
		first_start = skip_ws( start );
		first_end = last_start;
		while ( first_end!=first_start && !is_ws( *first_end ) )
			first_end--;
		name_givennames( first_start, last_start, last_start, last_end, 
			outname );
	}
}

/*
 * name_comma()
 *
 * names in the format "Author, H.F.", w/comma
 */
void
name_comma( char *p, newstr *outname )
{
	char *start_first, *end_first, *start_last, *end_last;

	/** Last name **/
	start_last = skip_ws( p );
	while ( *p && ( *p!=',' ) ) {
		newstr_addchar( outname, *p++ );
		end_last = p;
	}

	/** Given names **/
	if ( *p==',' ) p++;
	start_first = skip_ws( p );
	if ( *start_first ) {
		end_first = string_end( start_first );
		name_givennames( start_first, end_first, start_last, end_last, 
				outname );
	}
}

/* Determine if name is of type "corporate" or if it
 * should be added "as-is"; both should not be mangled.
 *
 * First check tag for prefixes ":CORP" and ":ASIS",
 * then optionally check lists, bailing if "corporate"
 * type can be identified.
 *
 * "corporate" is the same as "as-is" plus getting 
 * special MODS treatment, so "corporate" type takes
 * priority
 */
static void
name_determine_flags( int *ctf, int *clf, int *atf, int *alf, char *tag, char *data, list *asis, list *corps )
{
	int corp_tag_flag = 0, corp_list_flag = 0;
	int asis_tag_flag = 0, asis_list_flag = 0;

	if ( strstr( tag, ":CORP" ) ) corp_tag_flag = 1;
	else if ( list_find( corps, data ) != -1 )
		corp_list_flag = 1;

	if ( strstr( tag, ":ASIS" ) ) {
		asis_tag_flag = 1;
		if ( list_find( corps, data ) != -1 )
			corp_list_flag = 1;
	} else {
		if ( list_find( corps, data ) != -1 )
			corp_list_flag = 1;
		else if ( list_find( asis, data ) != -1 )
			asis_list_flag = 1;
	}

	*ctf = corp_tag_flag;
	*clf = corp_list_flag;
	*atf = asis_tag_flag;
	*alf = asis_list_flag;
}

/*
 * return 1 on a nomangle with a newtag value
 * return 0 on a name to mangle
 */
static int
name_nomangle( char *tag, char *data, newstr *newtag, list *asis, list *corps )
{
	int corp_tag_flag, corp_list_flag;
	int asis_tag_flag, asis_list_flag;
	name_determine_flags( &corp_tag_flag, &corp_list_flag,
		&asis_tag_flag, &asis_list_flag, tag, data, asis, corps );
	if ( corp_tag_flag || corp_list_flag || asis_tag_flag || asis_list_flag ) {
		newstr_strcpy( newtag, tag );
		if ( corp_tag_flag ) { /* do nothing else */
		} else if ( corp_list_flag && !asis_tag_flag ) {
			newstr_strcat( newtag, ":CORP" );
		} else if ( corp_list_flag && asis_tag_flag ) {
			newstr_findreplace( newtag, ":ASIS", ":CORP" );
		} else if ( asis_tag_flag ) { /* do nothing else */
		} else if ( asis_list_flag ) {
			newstr_strcat( newtag, ":ASIS" );
		}
		return 1;
	}
	else return 0;
}

static void
name_person( fields *info, char *tag, int level, newstr *inname )
{
	newstr outname;
	newstr_init( &outname );
	if ( strchr( inname->data, ',' ) ) 
		name_comma( inname->data, &outname );
	else
		name_nocomma( inname->data, &outname );
	if ( outname.len!=0 )
		fields_add( info, tag, outname.data, level );
	newstr_free( &outname );
}

/*
 * name_process
 *
 * returns 1 if "et al." needs to be added to the list globally
 */
static int
name_process( fields *info, char *tag, int level, newstr *inname, list *asis, list *corps )
{
	newstr newtag;
	int add_etal = 0;

	/* keep "names" like " , " from coredumping program */
	if ( !inname->len ) return 0;

	/* identify and process asis or corps names */
	newstr_init( &newtag );
	if ( name_nomangle( tag, inname->data, &newtag, asis, corps ) ) {
		fields_add( info, newtag.data, inname->data, level );
	} else {
		if ( strstr( inname->data, "et al." ) ) {
			add_etal = 1;
			newstr_findreplace( inname, "et al.", "" );
		}
		if ( inname->len ) {
			name_person( info, tag, level, inname );
		}
	}
	newstr_free( &newtag );
	return add_etal;
}

/*
 * name_add( info, newtag, data, level )
 *
 * take name(s) in data, multiple names should be separated by
 * '|' characters and divide into individual name, e.g.
 * "H. F. Author|W. G. Author|Q. X. Author"
 *
 * for each name, compare to names in the "as is" or "corporation"
 * lists...these are not personal names and should be added to the
 * bibliography fields directly and should not be mangled
 * 
 * for each personal name, send to appropriate algorithm depending
 * on if the author name is in the format "H. F. Author" or
 * "Author, H. F."
 */
void
name_add( fields *info, char *tag, char *q, int level, list *asis, list *corps )
{
	newstr inname, newtag;
	char *p, *start, *end;
	int add_etal = 0;

	if ( !q ) return;

	newstr_init( &inname );
	newstr_init( &newtag );

	while ( *q ) {

		start = q = skip_ws( q );

		/* strip tailing whitespace and commas */
		while ( *q && *q!='|' ) q++;
		end = q;
		while ( is_ws( *end ) || *end==',' || *end=='|' || *end=='\0' )
			end--;

		for ( p=start; p<=end; p++ )
			newstr_addchar( &inname, *p );

		add_etal += name_process( info, tag, level, &inname, asis, corps );
#if 0
		/* keep "names" like " , " from coredumping program */
		if ( inname.len ) {
			if ( name_nomangle( tag, inname.data, &newtag, asis, corps ) ) {
				fields_add( info, newtag.data, inname.data, level );
				newstr_empty( &newtag );
			} else {
				if ( strstr( inname.data, "et al." ) ) {
					add_etal=1;
					newstr_findreplace( &inname, "et al.", "" );
				}
				if ( inname.len ) name_person( info, tag, level, &inname, asis, corps );
			}
			newstr_empty( &inname );
		}
#endif

		newstr_empty( &inname );
		if ( *q=='|' ) q++;
	}
	if ( add_etal ) {
		newstr_strcpy( &newtag, tag );
		newstr_strcat( &newtag, ":ASIS" );
		fields_add( info, newtag.data, "et al.", level );
	}
	newstr_free( &inname );
	newstr_free( &newtag );
}
