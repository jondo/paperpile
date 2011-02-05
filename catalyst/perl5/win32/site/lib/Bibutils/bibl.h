/*
 * bibl.h
 *
 * Copyright (c) Chris Putnam 2005-9
 *
 */
#ifndef BIBL_H
#define BIBL_H

#include <stdio.h>
#include "newstr.h"
#include "fields.h"
#include "reftypes.h"

typedef struct {
	long nrefs;
	long maxrefs;
	fields **ref;
} bibl;

extern void bibl_init( bibl *b );
extern void bibl_addref( bibl *b, fields *ref );
extern void bibl_free( bibl *b );
extern void bibl_copy( bibl *bout, bibl *bin );

#endif

