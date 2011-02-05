/*
 * charsets.h
 *
 * Copyright (c) Chris Putnam 2003-2009
 *
 * Source code released under the GPL
 *
 */

typedef unsigned int charconvert;

typedef struct allcharconvert_t {
	char name[15];
	char name2[25];
	charconvert *table;
	int ntable;
} allcharconvert_t;
extern allcharconvert_t allcharconvert[];
extern int nallcharconvert;


