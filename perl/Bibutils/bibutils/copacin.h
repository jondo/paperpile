/*
 * copacin.h
 *
 * Copyright (c) Chris Putnam 2004-2009
 *
 * Program and source code released under the GPL
 *
 */
#ifndef COPACIN_H
#define COPACIN_H

#include "newstr.h"
#include "fields.h"
#include "reftypes.h"
#include "bibutils.h"

extern int copacin_readf( FILE *fp, char *buf, int bufsize, int *bufpos,
		newstr *line, newstr *reference, int *fcharset );
extern int copacin_processf( fields *copacin, char *p, char *filename, 
		long nref );
extern void copacin_convertf( fields *copacin, fields *info, int reftype, param *p, variants *all, int nall );

extern variants copac_all[];
extern int copac_nall;


#endif
