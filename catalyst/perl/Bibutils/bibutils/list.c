/*
 * list.c
 *
 * Copyright (c) Chris Putnam 2004-8
 *
 * Source code released under the GPL
 *
 * Implements a simple managed array of newstrs.
 *
 */
#include "list.h"

newstr *
list_getstr( list *a, int n )
{
	if ( n<0 || n>a->n ) return NULL;
	else return &(a->str[n]);
}

char *
list_getstr_char( list *a, int n )
{
	if ( n<0 || n>a->n ) return NULL;
	else return a->str[n].data;
}

static int
list_alloc( list *a )
{
	int i, alloc = 20;
	a->str = ( newstr* ) malloc( sizeof( newstr ) * alloc );
	if ( !(a->str) ) return 0;
	a->max = alloc;
	a->n = 0;
	for ( i=0; i<alloc; ++i )
		newstr_init( &(a->str[i]) );
	return 1;
}

static int
list_realloc( list *a )
{
	newstr *more;
	int i, alloc = a->max * 2;
	more = ( newstr* ) realloc( a->str, sizeof( newstr ) * alloc );
	if ( !more ) return 0;
	a->str = more;
	for ( i=a->max; i<alloc; ++i )
		newstr_init( &(a->str[i]) );
	a->max = alloc;
	return 1;
}

int
list_add( list *a, char *value )
{
	int ok = 1;

	/* ensure sufficient space */
	if ( a->max==0 ) ok = list_alloc( a );
	else if ( a->n >= a->max ) ok = list_realloc( a );

	if ( ok ) {
		newstr_strcpy( &(a->str[a->n]), value );
		a->sorted = 0;
		a->n++;
	}

	return ok;
}

void
list_empty( list *a )
{
	int i;
	for ( i=0; i<a->max; ++i )
		newstr_empty( &(a->str[i]) );
	a->n = 0;
	a->sorted = 1;
}

void
list_free( list *a )
{
	int i;
	for ( i=0; i<a->max; ++i )
		newstr_free( &(a->str[i]) );
	free( a->str );
	list_init( a );
}

void
list_init( list *a  )
{
	a->str = NULL;
	a->max = 0;
	a->n = 0;
	a->sorted = 0;
}

static int
list_comp( const void *v1, const void *v2 )
{
	newstr *s1 = ( newstr* ) v1;
	newstr *s2 = ( newstr *) v2;
	return strcmp( s1->data, s2->data );
}

void
list_sort( list *a )
{
	qsort( a->str, a->n, sizeof( newstr ), list_comp );
	a->sorted = 1;
}

static int
list_find_sorted( list *a, char *searchstr )
{
	int min, max, mid, comp;
	if ( a->n==0 ) return -1;
	min = 0;
	max = a->n - 1;
	while ( min <= max ) {
		mid = ( min + max ) / 2;
		comp = list_comp( (void*)list_getstr_char( a, mid ),
			(void*) searchstr );
		if ( comp==0 ) return mid;
		else if ( comp > 0 ) max = mid - 1;
		else if ( comp < 0 ) min = mid + 1;
	}
	return -1;
}

static int
list_find_simple( list *a, char *searchstr, int nocase )
{
	int i;
	if ( nocase ) {
		for ( i=0; i<a->n; ++i )
			if ( !strcasecmp(a->str[i].data,searchstr) ) 
				return i;
	} else {
		for ( i=0; i<a->n; ++i )
			if ( !strcmp(a->str[i].data,searchstr) ) 
				return i;
	}
	return -1;
}

int
list_find( list *a, char *searchstr )
{
	if ( a->sorted )
		return list_find_sorted( a, searchstr );
	else
		return list_find_simple( a, searchstr, 0 );
}

int
list_findnocase( list *a, char *searchstr )
{
	return list_find_simple( a, searchstr, 1 );
}

/* Return the index of searched-for string.
 * If cannot find string, add to list and then
 * return the index
 */
int
list_find_or_add( list *a, char *searchstr )
{
	int n = list_find( a, searchstr );
	if ( n==-1 )
		n = list_add( a, searchstr );
	return n;
}

int
list_fill( list *a, char *filename )
{
	newstr line;
	FILE *fp;
	char *p;
	char buf[512]="";
	int  bufpos = 0;

	fp = fopen( filename, "r" );
	if ( !fp ) return 0;

	list_init( a );

	newstr_init( &line );
	while ( newstr_fget( fp, buf, sizeof(buf), &bufpos, &line ) ) {
		p = &(line.data[0]);
		if ( *p=='\0' ) continue;
		if ( !list_add( a, line.data ) ) return 0;
	}
	newstr_free( &line );
	fclose( fp );
	return 1;
}

void
list_copy( list *to, list *from )
{
	int i;
	list_free( to );
	to->str = ( newstr * ) malloc( sizeof( newstr ) * from->n );
	if ( !to->str ) return;
	to->n = to->max = from->n;
	for ( i=0; i<from->n; ++i ) {
		newstr_init( &(to->str[i]) );
		newstr_strcpy( &(to->str[i]), from->str[i].data );
	}
}

list *
list_dup( list *aold )
{
	list *anew;
	int i;
	anew = ( list* ) malloc( sizeof( list ) );
	if ( !anew ) goto err0;
	anew->str = ( newstr* ) malloc( sizeof( newstr ) * aold->n );
	if ( !anew->str ) goto err1;
	anew->n = anew->max = aold->n;
	for ( i=0; i<aold->n; ++i ) {
		newstr_init( &(anew->str[i]) );
		newstr_strcpy( &(anew->str[i]), aold->str[i].data );
	}
	return anew;
err1:
	free( anew );
err0:
	return NULL;
}

