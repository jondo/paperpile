/*
 * fields.h
 *
 * Copyright (c) Chris Putnam 2003-2009
 *
 * Source code released under the GPL
 *
 */
#ifndef FIELDS_H
#define FIELDS_H

#define LEVEL_MAIN (0)
#define LEVEL_HOST (1)
#define LEVEL_SERIES (2)

#define LEVEL_ORIG (-2)

#include "newstr.h"

typedef struct {
	newstr    *tag;
	newstr    *data;
	int       *used;
	int       *level;
	int       nfields;
	int       maxfields;
} fields;

extern int  fields_add( fields *info, char *tag, char *data, int level );
extern int  fields_add_tagsuffix( fields *info, char *tag, char *suffix,
		char *data, int level );
extern void fields_free( fields *info );
extern void fields_init( fields *info );
extern fields *fields_new( void );
extern int  fields_find( fields *info, char *searchtag, int level );
extern int  fields_find_firstof( fields *info, char *tags[], int ntags, 
		int level );
extern int  fields_maxlevel( fields *info );
extern void fields_clearused( fields *info );
extern void fields_setused( fields *info, int n );


#endif
