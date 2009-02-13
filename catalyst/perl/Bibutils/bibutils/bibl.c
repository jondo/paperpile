/*
 * bibl.c
 *
 * Copyright (c) Chris Putnam 2005-8
 *
 * Source code released under the GPL
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include "bibl.h"

void
bibl_init( bibl *b )
{
	b->nrefs = b->maxrefs = 0L;
	b->ref = NULL;
}

static void
bibl_malloc( bibl * b )
{
	int alloc = 50;
	b->nrefs = 0;
	b->ref = ( fields ** ) malloc( sizeof( fields* ) * alloc );
	if ( b->ref ) {
		b->maxrefs = alloc;
	} else {
		fprintf( stderr, "bibl_malloc: allocation error\n" );
		exit( EXIT_FAILURE );
	}
}

static void
bibl_realloc( bibl * b )
{
	int alloc = b->maxrefs * 2;
	fields **more;
	more = ( fields ** ) realloc( b->ref, sizeof( fields* ) * alloc );
	if ( more ) {
		b->ref = more;
		b->maxrefs = alloc;
	} else {
		fprintf( stderr, "bibl_realloc: allocation error\n" );
		exit( EXIT_FAILURE );
	}
}

void
bibl_addref( bibl *b, fields *ref )
{
	if ( b->maxrefs==0 ) bibl_malloc( b );
	else if ( b->nrefs >= b->maxrefs ) bibl_realloc( b );
	b->ref[ b->nrefs ] = ref;
	b->nrefs++;
}

void
bibl_free( bibl *b )
{
	long i;
	for ( i=0; i<b->nrefs; ++i )
		fields_free( b->ref[i] );
	free( b->ref );
	b->nrefs = b->maxrefs = 0;
}

void
bibl_copy( bibl *bout, bibl *bin )
{
	fields *refin;
	fields *refout;
	int i, j;
	for ( i=0; i<bin->nrefs; ++i ) {
		refin = bin->ref[i];
		refout = fields_new();
		for ( j=0; j<refin->nfields; ++j ) {
			if ( refin->tag[j].data && refin->data[j].data )
				fields_add( refout, refin->tag[j].data, 
					refin->data[j].data, refin->level[j] );
		}
		bibl_addref( bout, refout );
	}
}

