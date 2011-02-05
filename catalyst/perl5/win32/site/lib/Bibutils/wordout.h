/*
 * wordout.h
 *
 * Copyright (c) Chris Putnam 2008-2009
 *
 * Source code released under the GPL
 *
 */
#ifndef WORDOUT_H
#define WORDOUT_H

/* format-specific options */
#define WORDOUT_DROPKEY (2)

#include <stdio.h>
#include "bibl.h"
#include "bibutils.h"

extern void wordout_writeheader( FILE *outptr, param *p );
extern void wordout_writefooter( FILE *outptr );
extern void wordout_write( fields *info, FILE *outptr, param *p,
	unsigned long numrefs );

#endif

