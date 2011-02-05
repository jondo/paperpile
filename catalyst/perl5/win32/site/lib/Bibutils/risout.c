/*
 * risout.c
 *
 * Copyright (c) Chris Putnam 2003-2009
 *
 * Program and source code released under the GPL
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "utf8.h"
#include "newstr.h"
#include "strsearch.h"
#include "fields.h"
#include "doi.h"
#include "risout.h"

enum { 
	TYPE_UNKNOWN,
	TYPE_STD,                /* standard/generic */
	TYPE_ABSTRACT,           /* abstract */
	TYPE_ARTICLE,            /* article */
	TYPE_BOOK,               /* book */
	TYPE_CASE,               /* case */
	TYPE_INBOOK,             /* chapter */
	TYPE_CONF,               /* conference */
	TYPE_ELEC,               /* electronic */
	TYPE_HEAR,               /* hearing */
	TYPE_MAGARTICLE,         /* magazine article */
	TYPE_NEWS,               /* newspaper */
	TYPE_MPCT,               /* mpct */
	TYPE_PAMP,               /* pamphlet */
	TYPE_PATENT,             /* patent */
	TYPE_PCOMM,              /* personal communication */
	TYPE_PROGRAM,            /* program */
	TYPE_REPORT,             /* report */
	TYPE_STATUTE,            /* statute */
	TYPE_THESIS,             /* thesis */
	TYPE_MASTERSTHESIS,      /* thesis */
	TYPE_PHDTHESIS,          /* thesis */
	TYPE_DIPLOMATHESIS,      /* thesis */
	TYPE_DOCTORALTHESIS,     /* thesis */
	TYPE_HABILITATIONTHESIS, /* thesis */
	TYPE_UNPUBLISHED,        /* unpublished */
};

typedef struct match_type {
	char *name;
	int type;
} match_type;

/* Try to determine type of reference from <genre></genre> 
 * and <TypeOfResource></TypeOfResource>
 */
static int
get_type_genre( fields *info )
{
	match_type match_genres[] = {
		{ "academic journal",          TYPE_ARTICLE },
		{ "magazine",                  TYPE_MAGARTICLE },
		{ "conference publication",    TYPE_CONF },
		{ "newspaper",                 TYPE_NEWS },
		{ "legislation",               TYPE_STATUTE },
		{ "communication",             TYPE_PCOMM },
		{ "hearing",                   TYPE_HEAR },
		{ "electronic",                TYPE_ELEC },
		{ "legal case and case notes", TYPE_CASE },
		{ "Ph.D. thesis",              TYPE_PHDTHESIS },
		{ "Masters thesis",            TYPE_MASTERSTHESIS },
		{ "Diploma thesis",            TYPE_DIPLOMATHESIS },
		{ "Doctoral thesis",           TYPE_DOCTORALTHESIS },
		{ "Habilitation thesis",       TYPE_HABILITATIONTHESIS },
		{ "report",                    TYPE_REPORT },
		{ "abstract or summary",       TYPE_ABSTRACT },
		{ "patent",                    TYPE_PATENT },
		{ "unpublished",               TYPE_UNPUBLISHED },
	};
	int nmatch_genres = sizeof( match_genres ) / sizeof( match_genres[0] );
	match_type match_res[] = {
		{ "software, multimedia",      TYPE_PROGRAM },
	};
	int nmatch_res = sizeof( match_res ) / sizeof( match_res[0] );
	char *tag, *data;
	int type = TYPE_UNKNOWN, i, j;
	for ( i=0; i<info->nfields; ++i ) {
		tag = info->tag[i].data;
		if ( strcasecmp( tag, "GENRE" ) &&
		     strcasecmp( tag, "NGENRE") ) continue;
		data = info->data[i].data;
		for ( j=0; j<nmatch_genres; ++j ) {
			if ( !strcasecmp( data, match_genres[j].name ) )
				type = match_genres[j].type;
		}
		if ( type==TYPE_UNKNOWN ) {
			if ( !strcasecmp( data, "periodical" ) )
				type = TYPE_ARTICLE;
			else if ( !strcasecmp( data, "thesis" ) )
				type = TYPE_THESIS;
			else if ( !strcasecmp( data, "book" ) ) {
				if ( info->level[i]==0 ) type=TYPE_BOOK;
				else type=TYPE_INBOOK;
			}
			else if ( !strcasecmp( data, "collection" ) ) {
				if ( info->level[i]==0 ) type=TYPE_BOOK;
				else type=TYPE_INBOOK;
			}
		}
	}
	if ( type==TYPE_UNKNOWN ) {
		for ( i=0; i<info->nfields; ++i ) {
			tag = info->tag[i].data;
			if ( strcasecmp( tag, "RESOURCE" ) ) continue;
			data = info->data[i].data;

			for ( j=0; j<nmatch_res; ++j ) {
				if ( !strcasecmp( data, match_res[j].name ) )
					type = match_res[j].type;
			}
		}
	}
	return type;
}

/* Try to determine type of reference from <issuance></issuance> and */
/* <typeOfReference></typeOfReference> */
static int
get_type_issuance( fields *info )
{
	int type = TYPE_UNKNOWN;
	int i, monographic = 0, text = 0, monographic_level = 0;
	for ( i=0; i<info->nfields; ++i ) {
		if ( !strcasecmp( info->tag[i].data, "issuance" ) &&
		     !strcasecmp( info->data[i].data, "MONOGRAPHIC" ) ){
			monographic = 1;
			monographic_level = info->level[i];
		}
		if ( !strcasecmp( info->tag[i].data, "typeOfResource" ) &&
		     !strcasecmp( info->data[i].data,"text") ) {
			text = 1;
		}
	}
	if ( monographic && text ) {
		if ( monographic_level==0 ) type=TYPE_BOOK;
		else if ( monographic_level>0 ) type=TYPE_INBOOK;
	}
	return type;
}

static int
get_type( fields *info )
{
	int type;
	type = get_type_genre( info );
	if ( type==TYPE_UNKNOWN ) type = get_type_issuance( info );
	if ( type==TYPE_UNKNOWN ) type = TYPE_STD;
	return type;
}

static void
output_type( FILE *fp, int type, param *p )
{
	match_type tyout[] = {
		{ "STD",  TYPE_STD },
		{ "ABST", TYPE_ABSTRACT },
		{ "JOUR", TYPE_ARTICLE },
		{ "BOOK", TYPE_BOOK },
		{ "CASE", TYPE_CASE },
		{ "CHAP", TYPE_INBOOK },
		{ "CONF", TYPE_CONF },
		{ "ELEC", TYPE_ELEC },
		{ "HEAR", TYPE_HEAR },
		{ "MGZN", TYPE_MAGARTICLE },
		{ "NEWS", TYPE_NEWS },
		{ "MPCT", TYPE_MPCT },
		{ "PAMP", TYPE_PAMP },
		{ "PAT",  TYPE_PATENT },
		{ "PCOMM",TYPE_PCOMM },
		{ "COMP", TYPE_PROGRAM },
		{ "RPRT", TYPE_REPORT },
		{ "STAT", TYPE_STATUTE },
		{ "THES", TYPE_THESIS },
		{ "THES", TYPE_MASTERSTHESIS },
		{ "THES", TYPE_PHDTHESIS },
		{ "THES", TYPE_DIPLOMATHESIS },
		{ "THES", TYPE_DOCTORALTHESIS },
		{ "THES", TYPE_HABILITATIONTHESIS },
		{ "UNPB", TYPE_UNPUBLISHED }
	};
	int ntyout = sizeof( tyout ) / sizeof( tyout[0] );
	int i, found;

	fprintf( fp, "TY  - " );
	found = 0;
	for ( i=0; i<ntyout && !found ; ++i ) {
		if ( tyout[i].type == type ) {
			fprintf( fp, "%s", tyout[i].name );
			found = 1;
		}
	}
	if ( !found ) {
		if ( p->progname ) fprintf( stderr, "%s: ", p->progname );
		fprintf( stderr, "Internal Error: Cannot identify type %d\n",
			type );
	}
	fprintf( fp, "\n" );
}

static void
output_person ( FILE *fp, char *p )
{
	int nseps = 0, nch;
	while ( *p ) {
		nch = 0;
		if ( nseps==1 ) fprintf( fp, "," );
		if ( nseps ) fprintf( fp, " " );
		while ( *p && *p!='|' ) {
			fprintf( fp, "%c", *p++ );
			nch++;
		}
		if ( *p=='|' ) p++;
		if ( nseps!=0 && nch==1 ) fprintf( fp, "." ); 
		nseps++;
	}
}

static void
output_people( FILE *fp, fields *info, long refnum, char *tag, 
		char *ristag, int level )
{
	int i;
	for ( i=0; i<info->nfields; ++i ) {
		if ( level!=-1 && info->level[i]!=level ) continue;
		if ( !strcasecmp( info->tag[i].data, tag ) ) {
			fprintf( fp, "%s  - ", ristag );
			output_person ( fp, info->data[i].data );
			fprintf( fp, "\n" );
		}
	}
}

static void
output_date( FILE *fp, fields *info, long refnum )
{
	int year = fields_find( info, "YEAR", -1 );
	int month = fields_find( info, "MONTH", -1 );
	int day = fields_find( info, "DAY", -1 );
	if ( year==-1 ) year = fields_find( info, "PARTYEAR", -1 );
	if ( month==-1 ) month = fields_find( info, "PARTMONTH", -1 );
	if ( day==-1 ) day = fields_find( info, "PARTDAY", -1 );
	if ( year==-1 && month==-1 && day==-1 ) return;
	fprintf( fp, "PY  - " );
	if ( year!=-1 ) fprintf( fp, "%s", info->data[year].data );
	fprintf( fp, "/" );
	if ( month!=-1 ) fprintf( fp, "%s", info->data[month].data );
	fprintf( fp, "/" );
	if ( day!=-1 ) fprintf( fp, "%s", info->data[day].data );
	fprintf( fp, "\n" );
}

static void
output_title( FILE *fp, fields *info, char *ristag, int level )
{
	int n1 = fields_find( info, "TITLE", level );
	int n2 = fields_find( info, "SUBTITLE", level );
	if ( n1!=-1 ) {
		fprintf( fp, "%s  - %s", ristag, info->data[n1].data );
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
output_abbrtitle( FILE *fp, fields *info, char *ristag, int level )
{
	int n1 = fields_find( info, "SHORTTITLE", level );
	int n2 = fields_find( info, "SHORTSUBTITLE", level );
	if ( n1!=-1 ) {
		fprintf( fp, "%s  - %s", ristag, info->data[n1].data );
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
output_pages( FILE *fp, fields *info, long refnum )
{
	int sn = fields_find( info, "PAGESTART", -1 );
	int en = fields_find( info, "PAGEEND", -1 );
	int ar = fields_find( info, "ARTICLENUMBER", -1 );
	if ( sn!=-1 || en!=-1 ) {
		if ( sn!=-1 ) 
			fprintf( fp, "SP  - %s\n", info->data[sn].data );
		if ( en!=-1 ) 
			fprintf( fp, "EP  - %s\n", info->data[en].data );
	} else if ( ar!=-1 ) {
		fprintf( fp, "SP  - %s\n", info->data[ar].data );
	}
}

static void
output_keywords( FILE *fp, fields *info )
{
	int i;
	for ( i=0; i<info->nfields; ++i ) {
		if ( !strcmp( info->tag[i].data, "KEYWORD" ) )
			fprintf( fp, "KW  - %s\n", info->data[i].data );
	}
}

static void
output_doi( FILE *fp, fields *info )
{
	newstr doi_url;
	int i;
	newstr_init( &doi_url );
	for ( i=0; i<info->nfields; ++i ) {
		if ( strcmp( info->tag[i].data, "DOI" ) ) continue;
		doi_to_url( info, i, "URL", &doi_url );
		if ( doi_url.len )
			fprintf( fp, "UR  - %s\n", doi_url.data );
	}
	newstr_free( &doi_url );
}

static void
output_pmid( FILE *fp, fields *info )
{
	newstr pmid_url;
	int i;
	newstr_init( &pmid_url );
	for ( i=0; i<info->nfields; ++i ) {
		if ( strcmp( info->tag[i].data, "PMID" ) ) continue;
		pmid_to_url( info, i, "URL", &pmid_url );
		if ( pmid_url.len )
			fprintf( fp, "UR  - %s\n", pmid_url.data );
	}
	newstr_free( &pmid_url );
}

static void
output_arxiv( FILE *fp, fields *info )
{
	newstr arxiv_url;
	int i;
	newstr_init( &arxiv_url );
	for ( i=0; i<info->nfields; ++i ) {
		if ( strcmp( info->tag[i].data, "ARXIV" ) ) continue;
		arxiv_to_url( info, i, "URL", &arxiv_url );
		if ( arxiv_url.len )
			fprintf( fp, "UR  - %s\n", arxiv_url.data );
	}
	newstr_free( &arxiv_url );
}

static void
output_thesishint( FILE *fp, int type )
{
	if ( type==TYPE_MASTERSTHESIS )
		fprintf( fp, "%s  - %s\n", "U1", "Masters thesis" );
	else if ( type==TYPE_PHDTHESIS )
		fprintf( fp, "%s  - %s\n", "U1", "Ph.D. thesis" );
	else if ( type==TYPE_DIPLOMATHESIS )
		fprintf( fp, "%s  - %s\n", "U1", "Diploma thesis" );
	else if ( type==TYPE_DOCTORALTHESIS )
		fprintf( fp, "%s  - %s\n", "U1", "Doctoral thesis" );
	else if ( type==TYPE_HABILITATIONTHESIS )
		fprintf( fp, "%s  - %s\n", "U1", "Habilitation thesis" );
}

static void
output_easy( FILE *fp, fields *info, long refnum, char *tag, char *ristag, int level )
{
	int n = fields_find( info, tag, level );
	if ( n!=-1 ) {
		fprintf( fp, "%s  - %s\n", ristag, info->data[n].data );
	}
}

static void
output_easyall( FILE *fp, fields *info, long refnum, char *tag, char *ristag, int level )
{
	int i;
	for ( i=0; i<info->nfields; ++i ) {
		if ( level!=-1 && level!=info->level[i] ) continue;
		if ( !strcmp( info->tag[i].data, tag ) )
			fprintf( fp, "%s  - %s\n", ristag, info->data[i].data );
	}
}

void
risout_write( fields *info, FILE *fp, param *p, unsigned long refnum )
{
	int type;
	type = get_type( info );
	output_type( fp, type, p );
	output_people( fp, info, refnum, "AUTHOR", "AU", 0 );
	output_easyall( fp, info, refnum, "AUTHOR:CORP", "AU", 0 );
	output_easyall( fp, info, refnum, "AUTHOR:ASIS", "AU", 0 );
	output_people( fp, info, refnum, "AUTHOR", "A2", 1 );
	output_easyall( fp, info, refnum, "AUTHOR:CORP", "A2", 1 );
	output_easyall( fp, info, refnum, "AUTHOR:ASIS", "A2", 1 );
	output_people( fp, info, refnum, "AUTHOR", "A3", 2 );
	output_easyall( fp, info, refnum, "AUTHOR:CORP", "A3", 2 );
	output_easyall( fp, info, refnum, "AUTHOR:ASIS", "A3", 2 );
	output_people( fp, info, refnum, "EDITOR", "ED", -1 );
	output_easyall( fp, info, refnum, "EDITOR:CORP", "ED", -1 );
	output_easyall( fp, info, refnum, "EDITOR:ASIS", "ED", -1 );
	output_date( fp, info, refnum );
	output_title( fp, info, "TI", 0 );
	output_abbrtitle( fp, info, "T2", -1 );
	if ( type==TYPE_ARTICLE || type==TYPE_MAGARTICLE ) {
		output_title( fp, info, "JO", 1 );
	}
	else output_title( fp, info, "BT", 1 );
	output_title( fp, info, "T3", 2 );
	output_pages( fp, info, refnum );
	output_easy( fp, info, refnum, "VOLUME", "VL", -1 );
	output_easy( fp, info, refnum, "ISSUE", "IS", -1 );
	output_easy( fp, info, refnum, "NUMBER", "IS", -1 );
	/* output article number as pages */
	output_easy( fp, info, refnum, "PUBLISHER", "PB", -1 );
	output_easy( fp, info, refnum, "DEGREEGRANTOR", "PB", -1 );
	output_easy( fp, info, refnum, "DEGREEGRANTOR:ASIS", "PB", -1 );
	output_easy( fp, info, refnum, "DEGREEGRANTOR:CORP", "PB", -1 );
	output_easy( fp, info, refnum, "ADDRESS", "CY", -1 );
	output_keywords( fp, info );
	output_easy( fp, info, refnum, "ABSTRACT", "N2", -1 );
	output_easy( fp, info, refnum, "ISSN", "SN", -1 );
	output_easy( fp, info, refnum, "ISBN", "SN", -1 );
	output_easyall( fp, info, refnum, "URL", "UR", -1 );
	output_easyall( fp, info, refnum, "FILEATTACH", "L1", -1 );
	output_doi( fp, info );
	output_pmid( fp, info );
	output_arxiv( fp, info );
	output_easy( fp, info, refnum, "NOTES", "N1", -1 );
	output_easy( fp, info, refnum, "REFNUM", "ID", -1 );
	output_thesishint( fp, type );
	fprintf( fp, "ER  - \n" );
	fflush( fp );
}

void
risout_writeheader( FILE *outptr, param *p )
{
	if ( p->utf8bom ) utf8_writebom( outptr );
}

