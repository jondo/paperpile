/*
 * isiout.h
 *
 * Copyright (c) Chris Putnam 2007-2009
 *
 */
#ifndef ISIOUT_H
#define ISIOUT_H

#include <stdio.h>
#include "bibutils.h"

extern void isiout_write( fields *info, FILE *fp, param *p,
		unsigned long refnum );
extern void isiout_writeheader( FILE *outptr, param *p );

#endif
