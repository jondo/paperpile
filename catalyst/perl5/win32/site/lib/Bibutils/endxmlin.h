/*
 * endxmlin.h
 *
 * Copyright (c) Chris Putnam 2006-2009
 *
 * Program and source code released under the GPL
 *
 */
#ifndef ENDXMLIN_H
#define ENDXMLIN_H

#include "newstr.h"
#include "fields.h"
#include "reftypes.h"

extern int endxmlin_readf( FILE *fp, char *buf, int bufsize, int *bufpos,
	newstr *line, newstr *reference, int *fcharset );
extern int endxmlin_processf( fields *endin, char *p, char *filename, long nref );

#endif
