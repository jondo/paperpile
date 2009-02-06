/*
 * newstr.c
 *
 * Copyright (c) Chris Putnam 1999-2008
 *
 * Source code released under the GPL
 *
 *
 * newstring routines for dynamically allocated strings
 *
 * C. Putnam 3/29/02  Clean up newstr_findreplace() (x4 speed increase too)
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <limits.h>
#include "newstr.h"
#include "is_ws.h"

#include <assert.h>

#define newstr_initlen (64)

#ifndef NEWSTR_PARANOIA

static void 
newstr_realloc( newstr *s, unsigned long minsize )
{
	char *newptr;
	unsigned long size;
	assert( s );
	size = 2 * s->dim;
	if (size < minsize) size = minsize;
	newptr = (char *) realloc( s->data, sizeof( *(s->data) )*size );
	if ( !newptr ) {
		fprintf(stderr,"Error.  Cannot reallocate memory (%ld bytes) in newstr_realloc.\n", sizeof(*(s->data))*size);
		exit( EXIT_FAILURE );
	}
	s->data = newptr;
	s->dim = size;
}

/* define as no-op */
static inline void
newstr_nullify( newstr *s )
{
}

#else

static void 
newstr_realloc( newstr *s, unsigned long minsize )
{
	char *newptr;
	unsigned long size;
	assert( s );
	size = 2 * s->dim;
	if ( size < minsize ) size = minsize;
	newptr = (char *) malloc( sizeof( *(s->data) ) * size );
	if ( !newptr ) {
		fprintf( stderr, "Error.  Cannot reallocate memory (%d bytes)"
			" in newstr_realloc.\n", sizeof(*(s->data))*size );
		exit( EXIT_FAILURE );
	}
	if ( s->data ) {
		newstr_nullify( s );
		free( s->data );
	}
	s->data = newptr;
	s->dim = size;
}

static inline void
newstr_nullify( newstr *s )
{
	memset( s->data, 0, s->dim );
}

#endif

void 
newstr_init( newstr *s )
{
	assert( s );
	s->dim = 0;
	s->len = 0;
	s->data = NULL;
}

static void 
newstr_initalloc( newstr *s, unsigned long minsize )
{
	unsigned long size = newstr_initlen;
	assert( s );
	if ( minsize > newstr_initlen ) size = minsize;
	s->data = (char *) malloc (sizeof( *(s->data) ) * size);
	if ( !s->data ) {
		fprintf(stderr,"Error.  Cannot allocate memory in newstr_initalloc.\n");
		exit( EXIT_FAILURE );
	}
	s->data[0]='\0';
	s->dim=size;
	s->len=0;
}

newstr *
newstr_new( void )
{
	newstr *s = (newstr *) malloc( sizeof( *s ) );
	if ( s )
		newstr_initalloc( s, newstr_initlen );
	return s;
}

void 
newstr_free( newstr *s )
{
	assert( s );
	if ( s->data ) {
		newstr_nullify( s );
		free( s->data );
	}
	s->dim = 0;
	s->len = 0;
	s->data = NULL;
}

void
newstr_empty( newstr *s )
{
	assert( s );
	if ( s->data ) {
		newstr_nullify( s );
		s->data[0] = '\0';
	}
	s->len = 0;
}

void
newstr_addchar( newstr *s, char newchar )
{
	assert( s );
	if ( !s->data || s->dim==0 ) 
		newstr_initalloc( s, newstr_initlen );
	if ( s->len + 2 > s->dim ) 
		newstr_realloc( s, s->len+2 );
	s->data[s->len++] = newchar;
	s->data[s->len] = '\0';
}

void 
newstr_fprintf( FILE *fp, newstr *s )
{
	assert( s );
	if ( s->data ) fprintf( fp, "%s", s->data );
}

void
newstr_prepend( newstr *s, char *addstr )
{
	unsigned long lenaddstr, i;
	assert( s && addstr );
	lenaddstr = strlen( addstr );
	if ( !s->data || !s->dim )
		newstr_initalloc( s, lenaddstr+1 );
	else {
		if ( s->len + lenaddstr  + 1 > s->dim )
			newstr_realloc( s, s->len + lenaddstr + 1 );
		for ( i=s->len+lenaddstr-1; i>=lenaddstr; i-- )
			s->data[i] = s->data[i-lenaddstr];
	}
	strncpy( s->data, addstr, lenaddstr );
	s->len += lenaddstr;
	s->data[ s->len ] = '\0';
}

static inline void
newstr_strcat_ensurespace( newstr *s, unsigned long n )
{
	unsigned long m = s->len + n + 1;
	if ( !s->data || !s->dim )
		newstr_initalloc( s, m );
	else if ( s->len + n + 1 > s->dim )
		newstr_realloc( s, m );
}

static inline void 
newstr_strcat_internal( newstr *s, char *addstr, unsigned long n )
{
	newstr_strcat_ensurespace( s, n );
	strncat( &(s->data[s->len]), addstr, n );
	s->len += n;
	s->data[s->len]='\0';
}

void
newstr_newstrcat( newstr *s, newstr *old )
{
	assert ( s && old );
	if ( !old->data ) return;
	else newstr_strcat_internal( s, old->data, old->len );
}

void
newstr_strcat( newstr *s, char *addstr )
{
	unsigned long n;
	assert( s && addstr );
	n = strlen( addstr );
	newstr_strcat_internal( s, addstr, n );
}

void
newstr_segcat( newstr *s, char *startat, char *endat )
{
	size_t seglength;
	char *p, *q;

	assert( s && startat && endat );
	assert( (size_t) startat < (size_t) endat );

	seglength=(size_t) endat - (size_t) startat;
	if ( !s->data || !s->dim )
		newstr_initalloc( s, seglength+1 );
	else {
		if ( s->len + seglength + 1 > s->dim )
			newstr_realloc( s, s->len + seglength+1 );
	}
	q = &(s->data[s->len]);
	p = startat;
	while ( *p && p!=endat ) *q++ = *p++;
	*q = '\0';
	s->len += seglength;
}

static inline void
newstr_strcpy_ensurespace( newstr *s, unsigned long n )
{
	unsigned long m = n + 1;
	if ( !s->data || !s->dim )
		newstr_initalloc( s, m );
	else if ( n+1 > s->dim ) 
		newstr_realloc( s, m );
}

static inline void
newstr_strcpy_internal( newstr *s, char *p, unsigned long n )
{
	newstr_strcpy_ensurespace( s, n );
	strcpy( s->data, p );
	s->len = n;
}

void
newstr_newstrcpy( newstr *s, newstr *old )
{
	assert( s && old );
	if ( s==old ) return;
	if ( !old->data || !old->dim ) newstr_empty( s );
	else newstr_strcpy_internal( s, old->data, old->len );
}

void 
newstr_strcpy( newstr *s, char *addstr )
{
	unsigned long n;
	assert( s && addstr );
	n = strlen( addstr );
	newstr_strcpy_internal( s, addstr, n );
}

newstr *
newstr_strdup( char *s1 )
{
	newstr *s2 = newstr_new();
	if ( s2 )
		newstr_strcpy( s2, s1 );
	return s2;
}

/* newstr_segcpy( s, start, end );
 *
 * copies [start,end) into s
 */
void
newstr_segcpy( newstr *s, char *startat, char *endat )
{
	size_t n;
	char *p, *q;

	assert( s && startat && endat );
	assert( ((size_t) startat) <= ((size_t) endat) );

	n = (size_t) endat - (size_t) startat;
	newstr_strcpy_ensurespace( s, n );
	q = s->data;
	p = startat;
	while ( *p && p!=endat ) *q++ = *p++;
	*q = '\0';
	s->len = n;
}

void
newstr_segdel( newstr *s, char *p, char *q )
{
	newstr tmp1, tmp2;
	char *r;
	assert( s );
	r = &(s->data[s->len]);
	newstr_init( &tmp1 );
	newstr_init( &tmp2 );
	newstr_segcpy( &tmp1, s->data, p );
	newstr_segcpy( &tmp2, q, r );
	newstr_empty( s );
	if ( tmp1.data ) newstr_strcat( s, tmp1.data );
	if ( tmp2.data ) newstr_strcat( s, tmp2.data );
	newstr_free( &tmp2 );
	newstr_free( &tmp1 );
}

/*
 * newstr_findreplace()
 *
 *   if replace is "" or NULL, then delete find
 */

int
newstr_findreplace( newstr *s, char *find, char *replace )
{
	long diff;
	size_t findstart, searchstart;
	size_t p1, p2;
	size_t find_len, rep_len, curr_len;
	char empty[2] = "";
	unsigned long minsize;
	char *p;
	int n = 0;

	assert( s && find );
	if ( !s->data || !s->dim ) return n;
	if ( !replace ) replace = empty;

	find_len = strlen( find );
	rep_len  = strlen( replace );
	diff     = rep_len - find_len;
	if ( diff < 0 ) diff = 0;

	searchstart=0;
	while ((p=strstr(s->data + searchstart,find))!=NULL) {
		curr_len = strlen(s->data);
		findstart=(size_t) p - (size_t) s->data;
		minsize = curr_len + diff + 1;
	 	if (s->dim <= minsize) newstr_realloc( s, minsize );
		if ( find_len > rep_len ) {
			p1 = findstart + rep_len;
			p2 = findstart + find_len;
			while( s->data[p2] )
				s->data[p1++]=s->data[p2++];
			s->data[p1]='\0';
			n++;
		} else if ( find_len < rep_len ) {
			for ( p1=curr_len; p1>=findstart+find_len; p1-- )
				s->data[p1+diff] = s->data[p1];
			n++;
		}
		for (p1=0; p1<rep_len; p1++)
			s->data[findstart+p1]=replace[p1];
		searchstart = findstart + rep_len; 
		s->len += rep_len - find_len;
	}
	return n;
}


/* newstr_fget()
 *   returns 0 if we're done, 1 if we're not done
 *   extracts line by line (regardless of end characters)
 *   and feeds from buf....
 */
int
newstr_fget( FILE *fp, char *buf, int bufsize, int *pbufpos, newstr *outs )
{
	int  bufpos = *pbufpos, done = 0;
	char *ok;
	newstr_empty( outs );
	while ( !done ) {
		while ( buf[bufpos] && buf[bufpos]!='\r' && buf[bufpos]!='\n' )
			newstr_addchar( outs, buf[bufpos++] );
		if ( buf[bufpos]=='\0' ) {
			ok = fgets( buf, bufsize, fp );
			bufpos=*pbufpos=0;
			if ( !ok && feof(fp) ) { /* end-of-file */
				buf[bufpos] = 0;
				if ( outs->len==0 ) return 0; /*nothing in out*/
				else return 1; /*one last out */
			}
		} else if ( buf[bufpos]=='\r' || buf[bufpos]=='\n' ) done=1;
	}
	if ( ( buf[bufpos]=='\n' && buf[bufpos+1]=='\r') ||
	     ( buf[bufpos]=='\r' && buf[bufpos+1]=='\n') ) bufpos+=2;
	else if ( buf[bufpos]=='\n' || buf[bufpos]=='\r' ) bufpos+=1; 
	*pbufpos = bufpos;
	return 1;
}

void
newstr_toupper( newstr *s )
{
	unsigned long i;
	assert( s );
	for ( i=0; i<s->len; ++i )
		s->data[i] = toupper( s->data[i] );
}

/* newstr_swapstrings( s1, s2 )
 * be sneaky and swap internal newstring data from one
 * string to another
 */
void
newstr_swapstrings( newstr *s1, newstr *s2 )
{
	char *tmpp;
	int tmp;

	assert( s1 && s2 );

	/* swap dimensioning info */
	tmp = s1->dim;
	s1->dim = s2->dim;
	s2->dim = tmp;

	/* swap length info */
	tmp = s1->len;
	s1->len = s2->len;
	s2->len = tmp;

	/* swap data */
	tmpp = s1->data;
	s1->data = s2->data;
	s2->data = tmpp;
}

void
newstr_trimendingws( newstr *s )
{
	assert( s );
	while ( s->len > 0 && is_ws( s->data[s->len-1] ) ) {
		s->data[s->len-1] = '\0';
		s->len--;
	}
}

