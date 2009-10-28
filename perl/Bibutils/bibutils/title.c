/*
 * title.c
 *
 * process titles into title/subtitle pairs for MODS
 *
 * Copyright (c) Chris Putnam 2004-2009
 *
 * Source code released under the GPL
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "newstr.h"
#include "fields.h"
#include "title.h"
#include "is_ws.h"

void
title_process( fields *info, char *tag, char *data, int level, 
						unsigned char nosplittitle )
{
	newstr title, subtitle;
	char *p, *q;
	newstr_init( &title );
	newstr_init( &subtitle );

	if ( nosplittitle ) q = NULL;
	else {
		q = strstr( data, ": " );
		if ( !q ) q = strstr( data, "? " );
	}

	if ( !q ) newstr_strcpy( &title, data );
	else {
		p = data;
		while ( p!=q ) newstr_addchar( &title, *p++ );
		if ( *q=='?' ) newstr_addchar( &title, '?' );
		q++;
		q = skip_ws( q );
		while ( *q ) newstr_addchar( &subtitle, *q++ );
	}

	if ( strncasecmp( "SHORT", tag, 5 ) ) {
		if ( title.len>0 ) 
			fields_add( info, "TITLE", title.data, level );
		if ( subtitle.len>0 ) 
			fields_add( info, "SUBTITLE", subtitle.data, level );
	} else {
		if ( title.len>0 )
			fields_add( info, "SHORTTITLE", title.data, level );
		/* no SHORT-SUBTITLE! */
	}

	newstr_free( &subtitle );
	newstr_free( &title );
}

