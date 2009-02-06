/*
 * name.c
 *
 * mangle names w/ and w/o commas
 *
 * Copyright (c) Chris Putnam 2004-8
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
should_split( int upperlast, int lowerlast, int upperfirst, int lowerfirst )
{
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


/* name_nocomma()
 *
 * names in the format "H. F. Author"
 */
void
name_nocomma( char *start, newstr *outname )
{
	char *p, *last, *end;
	int uplast, lowlast, upfirst, lowfirst, splitfirst;

	/* move to end */
	p = start;
	while ( *p && *(p+1) ) p++;

	/* point to last name */
	end = p;
	while ( p>start && !is_ws( *p ) ) p--;
	if ( !strcasecmp( p, "Jr." ) || !strcasecmp( p, "III" ) ) {
		while ( p>start && is_ws( *p ) ) p--;
		while ( p>start && !is_ws( *p ) ) p--;
	}
	last = p;

	p = skip_ws( p );

	/* look for upper and lower case in last name */
	check_case( p, end+1, &uplast, &lowlast );

	/* copy last name */
	while ( p<=end )
		newstr_addchar( outname, *p++ );

	if ( start==last ) return;   /*Only last name */

	/* Given names */
	newstr_addchar( outname, '|' );

	/* look for upper and lower case in given name(s) */
	check_case( start, last, &upfirst, &lowfirst );
	splitfirst = should_split( uplast, lowlast, upfirst, lowfirst );

	/* copy given name(s), splitfirst to identify cases of "HF Author" */
	p = start;
	while ( p!=last ) {
		if ( *p!=' ' && *p!='\t' ) {
			if ( !(splitfirst && ( *p=='.' || *p=='-' ) ) ) {
				p = name_addmultibytechar( outname, p, last );
				if ( splitfirst )
					newstr_addchar(outname,'|');
			} else p++;
		} else {
			while ( p!=last && ( *p==' ' || *p=='\t' ) )
				p++;
			if ( p!=last && !splitfirst )
				newstr_addchar( outname, '|' );
		}
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
	char *q;
	int uplast, lowlast, upfirst, lowfirst, splitfirst;

	q = p;
	while ( *q && ( *q!=',' ) ) q++;
	check_case( p, q, &uplast, &lowlast );

	while ( *p && ( *p!=',' ) ) 
		newstr_addchar( outname, *p++ );

	if ( *p==',' ) p++;
	p = skip_ws( p );

	q = p;
	while ( *q ) q++;
	check_case( p, q, &upfirst, &lowfirst );
	splitfirst = should_split( uplast, lowlast, upfirst, lowfirst );

	if ( !*p ) return; /* Only last name */

	/* add each part of the given name */
	newstr_addchar( outname, '|' );

	/* splitfirst to identify cases of Author, HF */
	while ( *p ) {
		if ( !is_ws( *p ) ) {
			if ( ! (splitfirst && ( *p=='.' || *p=='-' ) ) ) {
				p=name_addmultibytechar(outname,p,NULL);
				if ( splitfirst )
					newstr_addchar( outname, '|' );
			} else p++;
		} else if ( *(p+1)!='\0' ) {
			if ( !splitfirst )
				newstr_addchar( outname, '|' );
			p++;
		} else p++;
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
name_process( fields *info, char *tag, int level, newstr *inname, list *asis,
	list *corps )
{
	newstr newtag, outname;
	newstr_init( &newtag );
	newstr_init( &outname );
	if ( name_nomangle( tag, inname->data, &newtag, asis, corps ) ) {
		fields_add( info, newtag.data, inname->data, level );
	} else {
		newstr_findreplace( inname, ".", ". " );
		if ( strchr( inname->data, ',' ) ) 
			name_comma( inname->data, &outname );
		else
			name_nocomma( inname->data, &outname );
		if ( outname.len!=0 ) {
			fields_add( info, tag, outname.data, level );
		}
	}
	newstr_free( &newtag );
	newstr_free( &outname );
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
	newstr inname;
	char *p, *start, *end;

	if ( !q ) return;

	newstr_init( &inname );

	while ( *q ) {

		start = q = skip_ws( q );

		/* strip tailing whitespace and commas */
		while ( *q && *q!='|' ) q++;
		end = q;
		while ( is_ws( *end ) || *end==',' || *end=='|' || *end=='\0' )
			end--;

		for ( p=start; p<=end; p++ )
			newstr_addchar( &inname, *p );

		/* keep "names" like " , " from coredumping program */
		if ( inname.len ) {
			name_process( info, tag, level, &inname, asis, corps );
			newstr_empty( &inname );
		}

		if ( *q=='|' ) q++;
	}
	newstr_free( &inname );
}
