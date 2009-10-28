/*
 * fields.c
 *
 * Copyright (c) Chris Putnam 2003-2009
 *
 * Source code released under the GPL
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "strsearch.h"
#include "fields.h"

int
fields_add( fields *info, char *tag, char *data, int level )
{
	newstr *newtags, *newdata;
	int *newused, *newlevel;
	int min_alloc = 20, i, found;
	if ( !tag || !data ) return 1;
	if ( info->maxfields==0 ){
		info->tag = (newstr*)malloc( sizeof(newstr) * min_alloc );
		info->data= (newstr*)malloc( sizeof(newstr) * min_alloc );
		info->used= (int*)      malloc( sizeof(int) * min_alloc );
		info->level=(int*)      malloc( sizeof(int) * min_alloc );
		if ( !info->tag || !info->data || !info->used || !info->level ){
			if ( info->tag ) free( info->tag );
			if ( info->data ) free( info->data );
			if ( info->used ) free( info->used );
			if ( info->level ) free( info->level );
			return 0;
		}
		info->maxfields = min_alloc;
		info->nfields = 0;
		for ( i=0; i<min_alloc; ++i ) {
			newstr_init(&(info->tag[i]));
			newstr_init(&(info->data[i]));
		}
	} else if ( info->nfields >= info->maxfields ){
		min_alloc = info->maxfields * 2;
		newtags = (newstr*) realloc( info->tag,
			       	sizeof(newstr) * min_alloc );
		newdata = (newstr*) realloc( info->data,
				sizeof(newstr) * min_alloc );
		newused = (int*)    realloc( info->used,
				sizeof(int) * min_alloc );
		newlevel= (int*)    realloc( info->level,
				sizeof(int) * min_alloc );
		if ( !newtags || !newdata || !newused || !newlevel ) {
			if ( newtags ) info->tag=newtags;
			if ( newdata ) info->data=newdata;
			if ( newused ) info->used=newused;
			if ( newlevel ) info->level=newlevel;
			return 0;
		}
		info->tag = newtags;
		info->data = newdata;
		info->used = newused;
		info->level = newlevel;
		info->maxfields = min_alloc;
		for ( i=info->nfields; i<min_alloc; ++i ) {
			newstr_init(&(info->tag[i]));
			newstr_init(&(info->data[i]));
		}
	}
	found = 0;
	for ( i=0; i<info->nfields && !found; ++i ) {
		if ( info->level[i]==level &&
		     !strcasecmp( info->tag[i].data, tag ) &&
		     !strcasecmp( info->data[i].data, data ) ) found=1;
	}
	if ( !found ) {
		newstr_strcpy( &(info->tag[info->nfields]), tag );
		newstr_strcpy( &(info->data[info->nfields]), data );
		info->used[ info->nfields ] = 0;
		info->level[ info->nfields ] = level;
		info->nfields++;
	}
	return 1;
}

int
fields_add_tagsuffix( fields *info, char *tag, char *suffix, char *data, 
	int level )
{
	char *buf;
	int len, ret;
	len = strlen( tag ) + strlen( suffix ) + 1;
	buf = ( char * ) malloc( sizeof(char)*len );
	if ( !buf ) return 0;
	strcpy( buf, tag );
	strcat( buf, suffix );
	ret = fields_add( info, buf, data, level );
	free( buf );
	return ret;
}


fields*
fields_new( void )
{
	fields *info = ( fields * ) malloc( sizeof( fields ) );
	if ( info ) fields_init( info );
	return info;
}

void
fields_init( fields *info )
{
	info->used  = NULL;
	info->level = NULL;
	info->tag   = NULL;
	info->data  = NULL;
	info->maxfields = info->nfields = 0;
}

void
fields_free( fields *info )
{
	int i;
	for (i=0; i<info->maxfields; ++i) {
		newstr_free( &(info->tag[i]) );
		newstr_free( &(info->data[i]) );
	}
	if ( info->tag )  free( info->tag );
	if ( info->data ) free( info->data );
	if ( info->used ) free( info->used );
	if ( info->level ) free( info->level );
	fields_init( info );
}

int
fields_find( fields *info, char *searchtag, int level )
{
	int i, found = -1;
	for ( i=0; i<info->nfields && found==-1; ++i ) {
		if ( (level==-1 || level==info->level[i]) &&
		     !strcasecmp( info->tag[i].data, searchtag ) ) {
			found = i;
			/* if there is no data for the tag, mark as unfound */
			/* but set "used" so noise is suppressed */
			if ( info->data[i].len==0 ) {
				found=-1;
				info->used[i] = 1;
			}
		}
	}
	return found;
}

int
fields_find_firstof( fields *info, char *tags[], int ntags, int level )
{
	int i=0, found = -1;
	while ( i<ntags && found==-1 )
		found = fields_find( info, tags[i], level );
	return found;
}


int
fields_maxlevel( fields *info )
{
	int i, max = 0;
	for ( i=0; i<info->nfields; ++i ) {
		if ( info->level[i]>max ) max = info->level[i];
	}
	return max;
}

void
fields_clearused( fields *info )
{
	int i;
	for ( i=0; i<info->nfields; ++i )
		info->used[i] = 0;
}

void
fields_setused( fields *info, int n )
{
	if ( n < info->nfields )
		info->used[n] = 1;
}


