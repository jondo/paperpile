/*
 * doi.c
 *
 * doi_to_url()
 * Handle outputing DOI as a URL (Endnote and RIS formats)
 *     1) Append http://dx.doi.org as necessary
 *     2) Check for overlap with pre-existing URL for the DOI
 *
 * is_doi()
 * Check for DOI buried in another field.
 *
 * Copyright (c) Chris Putnam 2008-2009
 *
 * Source code released under the GPL
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "newstr.h"
#include "fields.h"

static void
construct_url( char *prefix, newstr *id, newstr *id_url )
{
	if ( !strncasecmp( id->data, "http:", 5 ) )
		newstr_newstrcpy( id_url, id );
	else {
		newstr_strcpy( id_url, prefix );
		if ( id->data[0]!='/' ) newstr_addchar( id_url, '/' );
		newstr_newstrcat( id_url, id );
	}
}

static int
url_exists( fields *info, char *urltag, newstr *doi_url )
{
	int i, found = 0;
	if ( urltag ) {
		for ( i=0; i<info->nfields && !found; ++i ) {
			if ( strcmp( info->tag[i].data, urltag ) )
				continue;
			if ( !strcmp( info->data[i].data, doi_url->data ) )
				found=1;
		}
	}
	return found;
}

void
doi_to_url( fields *info, int n, char *urltag, newstr *doi_url )
{
	newstr_empty( doi_url );
	construct_url( "http://dx.doi.org", &(info->data[n]), doi_url );
	if ( url_exists( info, urltag, doi_url ) )
		newstr_empty( doi_url );
}

void
pmid_to_url( fields *info, int n, char *urltag, newstr *pmid_url )
{
	newstr_empty( pmid_url );
	construct_url( "http://www.ncbi.nlm.nih.gov/pubmed", &(info->data[n]),
			pmid_url );
	if ( url_exists( info, urltag, pmid_url ) )
		newstr_empty( pmid_url );
}

void
arxiv_to_url( fields *info, int n, char *urltag, newstr *arxiv_url )
{
	newstr_empty( arxiv_url );
	construct_url( "http://arxiv.org/abs", &(info->data[n]), arxiv_url );
	if ( url_exists( info, urltag, arxiv_url ) )
		newstr_empty( arxiv_url );
}

/* Rules for the pattern:
 *   '#' = number
 *   isalpha() = match precisely (matchcase==1) or match regardless of case
 *   	(matchcase==0)
 *   all others must match precisely
 */
static int
string_pattern( char *s, char *pattern, int matchcase )
{
	int patlen, match, i;
	patlen = strlen( pattern );
	if ( strlen( s ) < patlen ) return 0; /* too short */
	for ( i=0; i<patlen; ++i ) {
		match = 0;
		if ( pattern[i]=='#' ) {
			if ( isdigit( s[i] ) ) match = 1;
		} else if ( !matchcase && isalpha( pattern[i] ) ) {
			if ( tolower(pattern[i])==tolower(s[i])) match = 1;
		} else {
			if ( pattern[i] == s[i] ) match = 1;
		}
		if ( !match ) return 0;
	}
	return 1;
}

/* science direct is now doing "M3  - doi: DOI: 10.xxxx/xxxxx" */
int
is_doi( char *s )
{
	if ( string_pattern( s, "##.####/", 0 ) ) return 0;
	if ( string_pattern( s, "doi:##.####/", 0 ) ) return 4;
	if ( string_pattern( s, "doi: ##.####/", 0 ) ) return 5;
	if ( string_pattern( s, "doi: DOI: ##.####/", 0 ) ) return 10;
	return -1;
}
