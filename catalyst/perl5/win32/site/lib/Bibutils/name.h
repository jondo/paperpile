/*
 * name.h
 *
 * mangle names w/ and w/o commas
 *
 * Copyright (c) Chris Putnam 2004-2009
 *
 * Source code released under the GPL
 *
 */
#ifndef NAME_H
#define NAME_H

#include "newstr.h"
#include "list.h"
#include "fields.h"

extern void name_nocomma( char *start, newstr *outname );
extern void name_comma( char *p, newstr *outname );
extern void name_add( fields *info, char *tag, char *q, int level,
	list *asis, list *corps );


#endif

