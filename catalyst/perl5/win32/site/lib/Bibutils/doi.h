/*
 * doi.h
 *
 * Copyright (c) Chris Putnam 2004-2009
 *
 * Source code released under the GPL
 */
#ifndef DOI_H
#define DOI_H

#include "newstr.h"
#include "fields.h"

extern void doi_to_url( fields *info, int n, char *urltag, newstr *doi_url );
extern int is_doi( char *s );
extern void pmid_to_url( fields *info, int n, char *urltag, newstr *pmid_url );
extern void arxiv_to_url( fields *info, int n, char *urltag, newstr *pmid_url );

#endif
