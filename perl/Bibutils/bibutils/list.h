/*
 * list.h
 *
 * Copyright (c) Chris Putnam 2004-2009
 *
 * Source code released under the GPL
 *
 */

#ifndef LISTS_H
#define LISTS_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "newstr.h"

typedef struct list {
	int n, max;
	int sorted;
	newstr *str;
} list;

extern void    list_init( list *a );
extern int     list_add( list *a, char *value );
extern void    list_sort( list *a );
extern int     list_find( list *a, char *searchstr );
extern int     list_findnocase( list *a, char *searchstr );
extern int     list_find_or_add( list *a, char *searchstr );
extern void    list_free( list *a );
extern int     list_fill( list *a, char *filename );
extern newstr* list_getstr( list *a, int n );
extern char*   list_getstr_char( list *a, int n );
extern list*   list_dup( list *a );
extern void    list_copy( list *to, list *from );

#endif
