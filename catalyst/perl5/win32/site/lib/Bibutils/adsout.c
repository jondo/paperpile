/*
 * adsout.c
 *
 * Copyright (c) Richard Mathar 2007-2009
 * Copyright (c) Chris Putnam 2007-2009
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
#include "adsout.h"

enum {
	TYPE_UNKNOWN = 0,
	TYPE_GENERIC,
	TYPE_ARTICLE,
	TYPE_MAGARTICLE,
	TYPE_BOOK,
	TYPE_INBOOK,
	TYPE_INPROCEEDINGS,
	TYPE_HEARING,
	TYPE_BILL,
	TYPE_CASE,
	TYPE_NEWSPAPER,
	TYPE_COMMUNICATION,
	TYPE_BROADCAST,
	TYPE_MANUSCRIPT,
	TYPE_REPORT,
	TYPE_THESIS,
	TYPE_MASTERSTHESIS,
	TYPE_PHDTHESIS,
	TYPE_DIPLOMATHESIS,
	TYPE_DOCTORALTHESIS,
	TYPE_HABILITATIONTHESIS,
	TYPE_PATENT,
	TYPE_PROGRAM
};

typedef struct match_type {
	char *name;
	int type;
} match_type;

static int
get_type( fields *info )
{
	match_type match_genres[] = {
		{ "academic journal",          TYPE_ARTICLE },
		{ "magazine",                  TYPE_MAGARTICLE },
		{ "conference publication",    TYPE_INPROCEEDINGS },
		{ "hearing",                   TYPE_HEARING },
		{ "Ph.D. thesis",              TYPE_PHDTHESIS },
		{ "Masters thesis",            TYPE_MASTERSTHESIS },
		{ "Diploma thesis",            TYPE_DIPLOMATHESIS },
		{ "Doctoral thesis",           TYPE_DOCTORALTHESIS },
		{ "Habilitation thesis",       TYPE_HABILITATIONTHESIS },
		{ "legislation",               TYPE_BILL },
		{ "newspaper",                 TYPE_NEWSPAPER },
		{ "communication",             TYPE_COMMUNICATION },
		{ "manuscript",                TYPE_MANUSCRIPT },
		{ "report",                    TYPE_REPORT },
		{ "legal case and case notes", TYPE_CASE },
		{ "patent",                    TYPE_PATENT },
	};
	int nmatch_genres = sizeof( match_genres ) / sizeof( match_genres[0] );

	char *tag, *data;
	int i, j, type = TYPE_UNKNOWN;

	for ( i=0; i<info->nfields; ++i ) {
		tag = info->tag[i].data;
		if ( strcasecmp( tag, "GENRE" )!=0 &&
		     strcasecmp( tag, "NGENRE" )!=0 ) continue;
		data = info->data[i].data;
		for ( j=0; j<nmatch_genres; ++j ) {
			if ( !strcasecmp( data, match_genres[j].name ) ) {
				type = match_genres[j].type;
				fields_setused( info, i );
			}
		}
		if ( type==TYPE_UNKNOWN ) {
			if ( !strcasecmp( data, "periodical" ) )
				type = TYPE_ARTICLE;
			else if ( !strcasecmp( data, "thesis" ) )
				type = TYPE_THESIS;
			else if ( !strcasecmp( data, "book" ) ) {
				if ( info->level[i]==0 ) type = TYPE_BOOK;
				else type = TYPE_INBOOK;
			}
			else if ( !strcasecmp( data, "collection" ) ) {
				if ( info->level[i]==0 ) type = TYPE_BOOK;
				else type = TYPE_INBOOK;
			}
			if ( type!=TYPE_UNKNOWN ) fields_setused( info, i );
		}
	}
	if ( type==TYPE_UNKNOWN ) {
		for ( i=0; i<info->nfields; ++i ) {
			if ( strcasecmp( info->tag[i].data, "RESOURCE" ) )
				continue;
			data = info->data[i].data;
			if ( !strcasecmp( data, "moving image" ) )
				type = TYPE_BROADCAST;
			else if ( !strcasecmp( data, "software, multimedia" ) )
				type = TYPE_PROGRAM;
			if ( type!=TYPE_UNKNOWN ) fields_setused( info, i );
		}
	}

	/* default to generic */
	if ( type==TYPE_UNKNOWN ) type = TYPE_GENERIC;
	
	return type;
}

static void
output_title( FILE *fp, fields *info, char * full, char *sub, char *endtag, int level )
{
	int n1 = fields_find( info, full, level );
	int n2 = fields_find( info, sub, level );
	int sn = fields_find( info, "PAGESTART", -1 );
	int en = fields_find( info, "PAGEEND", -1 );
	int ar = fields_find( info, "ARTICLENUMBER", -1 );
	if ( n1!=-1 ) {
		fprintf( fp, "%s %s", endtag, info->data[n1].data );
		fields_setused( info, n1 );
		if ( n2!=-1 ) {
			if ( info->data[n1].data[info->data[n1].len]!='?' )
				fprintf( fp, ": " );
			else fprintf( fp, " " );
			fprintf( fp, "%s", info->data[n2].data );
			fields_setused( info, n2 );
		}

		n1 = fields_find( info, "VOLUME", -1 );
		if ( n1!=-1 )
			fprintf( fp, ", vol. %s", info->data[n1].data );
		n1 = fields_find( info, "ISSUE", -1 );
		if ( n1 == -1 )
			n1 = fields_find( info, "NUMBER", -1 );
		if ( n1!=-1 )
			fprintf( fp, ", no. %s", info->data[n1].data );

		if ( sn!=-1 ) {
			if ( en != -1)
				fprintf( fp, ", pp.");
			else
				fprintf( fp, ", p.");
			fprintf( fp, " %s", info->data[sn].data);
		} else if ( ar!=-1 ) {
			fprintf( fp, " p. %s", info->data[ar].data );
		}
		if ( en!=-1 ) {
			fprintf( fp, "-%s", info->data[en].data );
		}

		fprintf( fp, "\n" );
	}
}

static void
output_person( FILE *fp, char *p )
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
output_people( FILE *fp, fields *info, char *tag, char *entag, int level )
{
	int i, cnt=0;
	for ( i=0; i<info->nfields; ++i ) {
		if ( level!=-1 && info->level[i]!=level ) continue;
		if ( !strcasecmp( info->tag[i].data, tag ) ) {
			if ( cnt ) fprintf( fp, "; " );
			else fprintf( fp, "%s ", entag );
			output_person( fp, info->data[i].data );
			cnt++;
		}
	}
	if ( cnt ) fprintf( fp, "\n" );
}

static void
output_pages( FILE *fp, fields *info )
{
	int sn = fields_find( info, "PAGESTART", -1 );
	int en = fields_find( info, "PAGEEND", -1 );
	int ar = fields_find( info, "ARTICLENUMBER", -1 );
	if ( sn!=-1 ) {
		fprintf( fp, "%%P %s\n", info->data[sn].data);
	} else if ( ar!=-1 ) {
		fprintf( fp, "%%P %s\n", info->data[ar].data );
	}
	if ( en!=-1 ) {
		fprintf( fp, "%%L %s\n", info->data[en].data );
	}
}

static int
get_year( fields *info, int level )
{
	int year = fields_find( info, "YEAR", level );
	if ( year==-1 )
		year = fields_find( info, "PARTYEAR", level );
	return year;
}

static int
mont2mont( const char *m )
{
	static char *monNames[]= { "jan", "feb", "mar", "apr", "may", 
			"jun", "jul", "aug", "sep", "oct", "nov", "dec" };
	int i;
	if ( isdigit( m[0] ) ) return atoi( m );
        else {
		for ( i=0; i<12; i++ ) {
			if ( !strncasecmp( m, monNames[i], 3 ) ) return i+1;
		}
	}
        return 0;
}

static int
get_month( fields *info, int level )
{
	int n;
	n = fields_find( info, "MONTH", level );
	if ( n==-1 ) n = fields_find( info, "PARTMONTH", level );
	if ( n==-1 ) return 0;
	else return mont2mont( info->data[n].data ); 
}

static void
output_date( FILE *fp, fields *info, char *entag, int level )
{
	int year, month;
	year = get_year( info, level );
	if ( year!=-1 ) {
		month = get_month( info, level );
		fprintf( fp, "%s %02d/%s\n", entag, month, 
			info->data[year].data );
	}
}

#include "adsout_journals.c"

static void
output_4digit_value( char *pos, int n )
{
	char buf[6];
	n = n % 10000; /* truncate to 0->9999, will fit in buf[6] */
	sprintf( buf, "%d", n );
	if ( n < 10 )        strncpy( pos+3, buf, 1 );
	else if ( n < 100 )  strncpy( pos+2, buf, 2 );
	else if ( n < 1000 ) strncpy( pos+1, buf, 3 );
	else                 strncpy( pos,   buf, 4 );
}

static char
get_firstinitial( fields *info )
{
	int n = fields_find( info, "AUTHOR", 0 );
	if ( n==-1 ) n = fields_find( info, "AUTHOR", -1 );
	if ( n!=-1 ) return info->data[n].data[0];
	else return '\0';
}

static int
min( int a, int b )
{
	if ( a < b ) return a;
	else return b;
}

static int
get_journalabbr( fields *info )
{
	char *jrnl;
	int ljrnl, ltmp, len, n, j;

	n = fields_find( info, "TITLE", LEVEL_HOST );
	if ( n!=-1 ) {
		jrnl = info->data[n].data;
		ljrnl = strlen( jrnl );
		for ( j=0; j<njournals; j++ ) {
			ltmp = strlen( journals[j]+6 );
			len = min( ljrnl, ltmp );
			if ( !strncasecmp( jrnl, journals[j]+6, len ) )
				return j;
		}
	}
	return -1;
}

static void
output_Rtag( FILE *fp, fields *info, char * entag, int type )
{
	char out[20], ch;
	int n;

	strcpy( out, "..................." );

	/** YYYY */
	n = fields_find( info, "YEAR", -1 );
	if ( n==-1 ) n = fields_find( info, "PARTYEAR", -1 );
	if ( n!=-1 ) output_4digit_value( out, atoi( info->data[n].data ) );

	/** JJJJ */
	n = get_journalabbr( info );
	if ( n!=-1 ) strncpy( out+4, journals[n], 5 );

	/** VVVV */
	n = fields_find( info, "VOLUME", -1 );
	if ( n!=-1 ) output_4digit_value( out+9, atoi( info->data[n].data ) );

	/** MPPPP */
	n = fields_find( info, "PAGESTART", -1 );
	if ( n==-1 ) n = fields_find( info, "ARTICLENUMBER", -1 );
	if ( n!=-1 ) {
		n = atoi( info->data[n].data );
		output_4digit_value( out+14, n );
		if ( n>=10000 ) {
			ch = 'a' + (n/10000);
			out[13] = ch;
		}
	}

	/** A */
        ch = toupper( get_firstinitial( info ) );
	if ( ch!='\0' ) out[18] = ch;

	fprintf( fp, "%s %s\n", entag, out );
}

static void
output_easyall( FILE *fp, fields *info, char *tag, char *entag, int level )
{
	int i;
	for ( i=0; i<info->nfields; ++i ) {
		if ( level!=-1 && info->level[i]!=level ) continue;
		if ( !strcmp( info->tag[i].data, tag ) )
			fprintf( fp, "%s %s\n", entag, info->data[i].data );
	}
}

static void
output_easy( FILE *fp, fields *info, char *tag, char *entag, int level )
{
	int n = fields_find( info, tag, level );
	if ( n!=-1 )
		fprintf( fp, "%s %s\n", entag, info->data[n].data );
}

static void
output_keys( FILE *fp, fields *info, char *tag, char *entag, int level )
{
	int i, n, nkeys = 0;
	n = fields_find( info, tag, level );
	if ( n!=-1 ) {
		fprintf( fp, "%s ", entag );
		for ( i=0; i<info->nfields; ++i ) {
			if ( level!=-1 && info->level[i]!=level ) continue;
			if ( !strcmp( info->tag[i].data, tag ) ) {
				if ( nkeys ) fprintf( fp, ", " );
				fprintf( fp, "%s", info->data[i].data );
				nkeys++;
			}
		}
		fprintf( fp, "\n" );
	}
}

void
adsout_write( fields *info, FILE *fp, param *p, unsigned long refnum )
{
	int type;
	fields_clearused( info );
	type = get_type( info );

	output_people( fp, info, "AUTHOR", "%A", 0 );
	output_people( fp, info, "EDITOR", "%E", -1 );
	output_easy( fp, info, "TITLE", "%T", -1 );

	if ( type==TYPE_ARTICLE || type==TYPE_MAGARTICLE )
		output_title( fp, info, "TITLE", "SUBTITLE", "%J", 1 );

	output_date( fp, info, "%D", -1 );
	output_easy( fp, info, "VOLUME", "%V", -1 );
	output_easy( fp, info, "ISSUE", "%N", -1 );
	output_easy( fp, info, "NUMBER", "%N", -1 );
	output_easy( fp, info, "LANGUAGE", "%M", -1 );
	output_easyall( fp, info, "NOTES", "%X", -1 );
	output_easy( fp, info, "ABSTRACT", "%B", -1 );
	output_keys( fp, info, "KEYWORD", "%K", -1 );
	output_easyall( fp, info, "URL", "%U", -1 ); 
	output_easyall( fp, info, "FILEATTACH", "%U", -1 ); 
	output_pages( fp, info );
	output_easyall( fp, info, "DOI", "%Y", -1 );
        fprintf( fp, "%%W PHY\n%%G AUTHOR\n" );
	output_Rtag( fp, info, "%R", type );
	fprintf( fp, "\n" );
	fflush( fp );
}

void
adsout_writeheader( FILE *outptr, param *p )
{
	if ( p->utf8bom ) utf8_writebom( outptr );
}

