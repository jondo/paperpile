/*
 * medin.h
 *
 * Copyright (c) Chris Putnam 2004-2009
 *
 * Program and source code released under the GPL
 *
 */
#ifndef MEDIN_H
#define MEDIN_H

#include "newstr.h"
#include "fields.h"
#include "reftypes.h"

extern int medin_readf( FILE *fp, char *buf, int bufsize, int *bufpos, newstr *line, newstr *reference, int *fcharset );
extern int medin_processf( fields *medin, char *data, char *filename, long nref );
extern void medin_convertf( fields *medin, fields *info, int reftype, int verbose, variants *all, int nall );

extern variants med_all[];
extern int med_nall;

#endif

