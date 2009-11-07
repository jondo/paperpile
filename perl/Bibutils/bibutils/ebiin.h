/*
 * ebiin.h
 *
 * Copyright (c) Chris Putnam 2004-2009
 *
 * Program and source code released under the GPL
 *
 */
#ifndef PUBIN_H
#define PUBIN_H

#include "newstr.h"
#include "fields.h"
#include "reftypes.h"

extern int ebiin_readf( FILE *fp, char *buf, int bufsize, int *bufpos, newstr *line, newstr *reference, int *fcharset );
extern int ebiin_processf( fields *ebiin, char *data, char *filename, long nref );
extern void ebiin_convertf( fields *ebiin, fields *info, int reftype, int verbose, variants *all, int nall );

extern variants med_all[];
extern int med_nall;

#endif

