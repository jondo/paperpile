/*
 * isiout.c
 *
 * Copyright (c) Chris Putnam 2008-2009
 *
 * Source code released under the GPL
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "utf8.h"
#include "newstr.h"
#include "strsearch.h"
#include "fields.h"
#include "bibutils.h"
#include "isiout.h"

enum {
        TYPE_UNKNOWN = 0,
        TYPE_ARTICLE = 1,
        TYPE_INBOOK  = 2,
        TYPE_BOOK    = 3,
};

static void
output_type( FILE *fp, int type )
{
	fprintf( fp, "PT " );
	if ( type==TYPE_ARTICLE ) fprintf( fp, "Journal" );
	else if ( type==TYPE_INBOOK ) fprintf( fp, "Chapter" );
	else if ( type==TYPE_BOOK ) fprintf( fp, "Book" );
	else fprintf( fp, "Unknown" );
	fprintf( fp, "\n" );
}

static int 
get_type( fields *info )
{
	char *tag, *data;
        int type = TYPE_UNKNOWN, i;
        for ( i=0; i<info->nfields; ++i ) {
		tag = info->tag[i].data;
                if ( strcasecmp( tag, "GENRE" ) &&
                     strcasecmp( tag, "NGENRE") ) continue;
		data = info->data[i].data;
                if ( !strcasecmp( data, "periodical" ) ||
                     !strcasecmp( data, "academic journal" ) )
                        type = TYPE_ARTICLE;
                else if ( !strcasecmp( data, "book" ) ) {
                        if ( info->level[i]==0 ) type=TYPE_BOOK;
                        else type=TYPE_INBOOK;
                }
        }
        return type;
}

static void
output_title( FILE *fp, fields *info, char *isitag, int level )
{
        int n1 = fields_find( info, "TITLE", level );
        int n2 = fields_find( info, "SUBTITLE", level );
        if ( n1!=-1 ) {
                fprintf( fp, "%s %s", isitag, info->data[n1].data );
                if ( n2!=-1 ) {
                        if ( info->data[n1].data[info->data[n1].len]!='?' )
                                fprintf( fp, ": " );
                        else fprintf( fp, " " );
                        fprintf( fp, "%s", info->data[n2].data );
                }
                fprintf( fp, "\n" );
        }
}

static void
output_abbrtitle( FILE *fp, fields *info, char *isitag, int level )
{
        int n1 = fields_find( info, "SHORTTITLE", level );
        int n2 = fields_find( info, "SHORTSUBTITLE", level );
        if ( n1!=-1 ) {
                fprintf( fp, "%s %s", isitag, info->data[n1].data );
                if ( n2!=-1 ){
                        if ( info->data[n1].data[info->data[n1].len]!='?' )
                                fprintf( fp, ": " );
                        else fprintf( fp, " " );
                        fprintf( fp, "%s", info->data[n2].data );
                }
                fprintf( fp, "\n" );
        }
}

static void
output_person( FILE *fp, char *name )
{
	int n = 0, nchars = 0;
	char *p = name;
	while ( *p ) {
		if ( *p=='|' )  { n++; nchars=0; }
		else {
			if ( n==1 && nchars<2 ) fprintf( fp, ", " );
			if ( n==0 || (n>0 && nchars<2) ) {
				fprintf( fp, "%c", *p );
			}
		}
		nchars++;
		p++;
	}
}

static void
output_keywords( FILE *fp, fields *info )
{
	int n = 0, i;
	for ( i=0; i<info->nfields; ++i ) {
		if ( strcasecmp( info->tag[i].data, "KEYWORD" ) ) continue;
		if ( n==0 )
			fprintf( fp, "DE " );
		if ( n>0 )
			fprintf( fp, "; " );
		fprintf( fp, "%s", info->data[i].data );
		n++;
	}
	if ( n ) fprintf( fp, "\n" );
}

static void
output_people( FILE *fp, fields *info, char *tag, char *isitag, int level )
{
	int n = 0, i;
        for ( i=0; i<info->nfields; ++i ) {
                if ( strcasecmp( info->tag[i].data, tag ) ) continue;
		if ( level!=-1 && info->level[i]!=level ) continue;
		if ( n==0 ) {
			fprintf( fp, "%s ", isitag );
		} else {
			fprintf( fp, "   " );
		}
		output_person( fp, info->data[i].data );
		fprintf( fp, "\n" );
		n++;
	}
}

static void
output_easy( FILE *fp, fields *info, char *tag, char *isitag, int level )
{
        int n = fields_find( info, tag, level );
        if ( n!=-1 )
                fprintf( fp, "%s %s\n", isitag, info->data[n].data );
}


static void
output_date( FILE *fp, fields *info )
{
	int n;

	n = fields_find( info, "PARTMONTH", -1 );
	if ( n==-1 ) n = fields_find( info, "MONTH", -1 );
	if ( n!=-1 ) fprintf( fp, "%s %s\n", "PD", info->data[n].data );

	n = fields_find( info, "PARTYEAR", -1 );
	if ( n==-1 ) n = fields_find( info, "YEAR", -1 );
	if ( n!=-1 ) fprintf( fp, "%s %s\n", "PY", info->data[n].data );
}

static void
output_verbose( fields *info, unsigned long refnum )
{
	int i;
	fprintf( stderr, "REF #%lu----\n", refnum+1 );
	for ( i=0; i<info->nfields; ++i ) {
		fprintf( stderr, "\t'%s'\t'%s'\t%d\n",
			info->tag[i].data,
			info->data[i].data,
			info->level[i]);
	}
}

void
isiout_write( fields *info, FILE *fp, param *p, unsigned long refnum )
{
        int type = get_type( info );

	if ( p->format_opts & BIBL_FORMAT_VERBOSE )
		output_verbose( info, refnum );

        output_type( fp, type );
	output_people( fp, info, "AUTHOR", "AU", 0 );
	output_easy( fp, info, "AUTHOR:CORP", "AU", 0 );
	output_easy( fp, info, "AUTHOR:ASIS", "AU", 0 );
/*      output_people( fp, info, "AUTHOR", "A2", 1 );
        output_people( fp, info, "AUTHOR:CORP", "A2", 1 );
        output_people( fp, info, "AUTHOR:ASIS", "A2", 1 );
        output_people( fp, info, "AUTHOR", "A3", 2 );
        output_people( fp, info, "AUTHOR:CORP", "A3", 2 );
        output_people( fp, info, "AUTHOR:ASIS", "A3", 2 );
        output_people( fp, info, "EDITOR", "ED", -1 );
	output_people( fp, info, "EDITOR:CORP", "ED", -1 );
        output_people( fp, info, "EDITOR:ASIS", "ED", -1 );*/
/*        output_date( fp, info, refnum );*/

        output_title( fp, info, "TI", 0 );
        if ( type==TYPE_ARTICLE ) {
                output_title( fp, info, "SO", 1 );
		output_abbrtitle( fp, info, "JI", 1 );
	}
        else output_title( fp, info, "BT", 1 );

	output_date( fp, info );
/*	output_easy( fp, info, "PARTMONTH", "PD", -1 );
	output_easy( fp, info, "PARTYEAR", "PY", -1 );*/

	output_easy( fp, info, "PAGESTART", "BP", -1 );
	output_easy( fp, info, "PAGEEND",   "EP", -1 );
        output_easy( fp, info, "ARTICLENUMBER", "AR", -1 );
        /* output article number as pages */
	output_easy( fp, info, "TOTALPAGES","PG", -1 );

        output_easy( fp, info, "VOLUME",    "VL", -1 );
        output_easy( fp, info, "ISSUE",     "IS", -1 );
        output_easy( fp, info, "NUMBER",    "IS", -1 );
	output_easy( fp, info, "DOI",       "DI", -1 );
	output_easy( fp, info, "ISIREFNUM", "UT", -1 );
	output_easy( fp, info, "LANGUAGE",  "LA", -1 );
	output_easy( fp, info, "ISIDELIVERNUM", "GA", -1 );
	output_keywords( fp, info );
	output_easy( fp, info, "ABSTRACT",  "AB", -1 );
	output_easy( fp, info, "TIMESCITED", "TC", -1 );
	output_easy( fp, info, "NUMBERREFS", "NR", -1 );
	output_easy( fp, info, "CITEDREFS",  "CR", -1 );
	output_easy( fp, info, "ADDRESS",    "PI", -1 );

/*        output_easy( fp, info, "PUBLISHER", "PB", -1 );
        output_easy( fp, info, "DEGREEGRANTOR", "PB", -1 );
        output_easy( fp, info, "ADDRESS", "CY", -1 );
        output_easy( fp, info, "ABSTRACT", "AB", -1 );
        output_easy( fp, info, "ISSN", "SN", -1 );
        output_easy( fp, info, "ISBN", "SN", -1 );
        output_easy( fp, info, "URL", "UR", -1 );
        output_easy( fp, info, "FILEATTACH", "UR", -1 );
        output_pubmed( fp, info, refnum );
        output_easy( fp, info, "NOTES", "N1", -1 );
        output_easy( fp, info, "REFNUM", "ID", -1 );*/
        fprintf( fp, "ER\n\n" );
        fflush( fp );
}

void
isiout_writeheader( FILE *outptr, param *p )
{
	if ( p->utf8bom ) utf8_writebom( outptr );
}
