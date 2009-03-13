/*
 * endout.c
 *
 * Copyright (c) Chris Putnam 2004-8
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
#include "endout.h"

enum {
	TYPE_UNKNOWN = 0,
	TYPE_GENERIC,                     /* Generic */
	TYPE_ARTWORK,                     /* Artwork */
	TYPE_AUDIOVISUAL,                 /* Audiovisual Material */
	TYPE_BILL,                        /* Bill */
	TYPE_BOOK,                        /* Book */
	TYPE_INBOOK,                      /* Book Section */
	TYPE_CASE,                        /* Case */
	TYPE_CHARTTABLE,                  /* Chart or Table */
	TYPE_CLASSICALWORK,               /* Classical Work */
	TYPE_PROGRAM,                     /* Computer Program */
	TYPE_INPROCEEDINGS,               /* Conference Paper */
	TYPE_PROCEEDINGS,                 /* Conference Proceedings */
	TYPE_EDITEDBOOK,                  /* Edited Book */
	TYPE_EQUATION,                    /* Equation */
	TYPE_ELECTRONICARTICLE,           /* Electronic Article */
	TYPE_ELECTRONICBOOK,              /* Electronic Book */
	TYPE_ELECTRONIC,                  /* Electronic Source */
	TYPE_FIGURE,                      /* Figure */
	TYPE_FILMBROADCAST,               /* Film or Broadcast */
	TYPE_GOVERNMENT,                  /* Government Document */
	TYPE_HEARING,                     /* Hearing */
	TYPE_ARTICLE,                     /* Journal Article */
	TYPE_LEGALRULE,                   /* Legal Rule/Regulation */
	TYPE_MAGARTICLE,                  /* Magazine Article */
	TYPE_MANUSCRIPT,                  /* Manuscript */
	TYPE_MAP,                         /* Map */
	TYPE_NEWSARTICLE,                 /* Newspaper Article */
	TYPE_ONLINEDATABASE,              /* Online Database */
	TYPE_ONLINEMULTIMEDIA,            /* Online Multimedia */
	TYPE_PATENT,                      /* Patent */
	TYPE_COMMUNICATION,               /* Personal Communication */
	TYPE_REPORT,                      /* Report */
	TYPE_STATUTE,                     /* Statute */
	TYPE_THESIS,                      /* Thesis */
	TYPE_MASTERSTHESIS,               /* Thesis */
	TYPE_PHDTHESIS,                   /* Thesis */
	TYPE_DIPLOMATHESIS,               /* Thesis */
	TYPE_DOCTORALTHESIS,              /* Thesis */
	TYPE_HABILITATIONTHESIS,          /* Thesis */
	TYPE_UNPUBLISHED,                 /* Unpublished Work */
};

typedef struct match_type {
	char *name;
	int type;
} match_type;

static int
get_type( fields *info )
{
	/* Comment out TYPE_GENERIC entries as that is default, but
         * keep in source as record of mapping decision. */
	match_type match_genres[] = {
		/* MARC Authority elements */
		{ "art original",              TYPE_ARTWORK },
		{ "art reproduction",          TYPE_ARTWORK },
		{ "article",                   TYPE_ARTICLE },
		{ "atlas",                     TYPE_MAP },
		{ "autobiography",             TYPE_BOOK },
/*		{ "bibliography",              TYPE_GENERIC },*/
		{ "biography",                 TYPE_BOOK },
		{ "book",                      TYPE_BOOK },
/*		{ "catalog",                   TYPE_GENERIC },*/
		{ "chart",                     TYPE_CHARTTABLE },
/*		{ "comic strip",               TYPE_GENERIC },*/
		{ "conference publication",    TYPE_PROCEEDINGS },
		{ "database",                  TYPE_ONLINEDATABASE },
/*		{ "dictionary",                TYPE_GENERIC },*/
		{ "diorama",                   TYPE_ARTWORK },
/*		{ "directory",                 TYPE_GENERIC },*/
		{ "discography",               TYPE_AUDIOVISUAL },
/*		{ "drama",                     TYPE_GENERIC },*/
		{ "encyclopedia",              TYPE_BOOK },
/*		{ "essay",                     TYPE_GENERIC }, */
/*		{ "festschrift",               TYPE_GENERIC },*/
		{ "fiction",                   TYPE_BOOK },
		{ "filmography",               TYPE_FILMBROADCAST },
		{ "filmstrip",                 TYPE_FILMBROADCAST },
/*		{ "finding aid",               TYPE_GENERIC },*/
/*		{ "flash card",                TYPE_GENERIC },*/
		{ "folktale",                  TYPE_CLASSICALWORK },
		{ "font",                      TYPE_ELECTRONIC },
/*		{ "game",                      TYPE_GENERIC },*/
		{ "government publication",    TYPE_GOVERNMENT },
		{ "graphic",                   TYPE_FIGURE },
		{ "globe",                     TYPE_MAP },
/*		{ "handbook",                  TYPE_GENERIC },*/
		{ "history",                   TYPE_BOOK },
		{ "hymnal",                    TYPE_BOOK },
/*		{ "humor, satire",             TYPE_GENERIC },*/
/*		{ "index",                     TYPE_GENERIC },*/
/*		{ "instruction",               TYPE_GENERIC },*/
/*		{ "interview",                 TYPE_GENERIC },*/
		{ "issue",                     TYPE_ARTICLE },
		{ "journal",                   TYPE_ARTICLE },
/*		{ "kit",                       TYPE_GENERIC },*/
/*		{ "language instruction",      TYPE_GENERIC },*/
/*		{ "law report or digest",      TYPE_GENERIC },*/
/*		{ "legal article",             TYPE_GENERIC },*/
		{ "legal case and case notes", TYPE_CASE },
		{ "legislation",               TYPE_BILL },
		{ "letter",                    TYPE_COMMUNICATION },
		{ "loose-leaf",                TYPE_GENERIC },
		{ "map",                       TYPE_MAP },
/*		{ "memoir",                    TYPE_GENERIC },*/
/*		{ "microscope slide",          TYPE_GENERIC },*/
/*		{ "model",                     TYPE_GENERIC },*/
		{ "motion picture",            TYPE_AUDIOVISUAL },
		{ "multivolume monograph",     TYPE_BOOK },
		{ "newspaper",                 TYPE_NEWSARTICLE },
		{ "novel",                     TYPE_BOOK },
/*		{ "numeric data",              TYPE_GENERIC },*/
/*		{ "offprint",                  TYPE_GENERIC },*/
		{ "online system or service",  TYPE_ELECTRONIC },
		{ "patent",                    TYPE_PATENT },
		{ "periodical",                TYPE_MAGARTICLE },
		{ "picture",                   TYPE_ARTWORK },
/*		{ "poetry",                    TYPE_GENERIC },*/
		{ "programmed text",           TYPE_PROGRAM },
/*		{ "realia",                    TYPE_GENERIC },*/
		{ "rehearsal",                 TYPE_AUDIOVISUAL },
/*		{ "remote sensing image",      TYPE_GENERIC },*/
/*		{ "reporting",                 TYPE_GENERIC },*/
/*		{ "review",                    TYPE_GENERIC },*/
/*		{ "script",                    TYPE_GENERIC },*/
/*		{ "series",                    TYPE_GENERIC },*/
/*		{ "short story",               TYPE_GENERIC },*/
/*		{ "slide",                     TYPE_GENERIC },*/
		{ "sound",                     TYPE_AUDIOVISUAL },
/*		{ "speech",                    TYPE_GENERIC },*/
/*		{ "statistics",                TYPE_GENERIC },*/
/*		{ "survey of literature",      TYPE_GENERIC },*/
		{ "technical drawing",         TYPE_ARTWORK },
		{ "techincal report",          TYPE_REPORT },
		{ "thesis",                    TYPE_THESIS },
/*		{ "toy",                       TYPE_GENERIC },*/
/*		{ "transparency",              TYPE_GENERIC },*/
/*		{ "treaty",                    TYPE_GENERIC },*/
		{ "videorecording",            TYPE_AUDIOVISUAL },
		{ "web site",                  TYPE_ELECTRONIC },
		/* Non-MARC Authority elements */
		{ "academic journal",          TYPE_ARTICLE },
		{ "magazine",                  TYPE_MAGARTICLE },
		{ "hearing",                   TYPE_HEARING },
		{ "Ph.D. thesis",              TYPE_PHDTHESIS },
		{ "Masters thesis",            TYPE_MASTERSTHESIS },
		{ "Diploma thesis",            TYPE_DIPLOMATHESIS },
		{ "Doctoral thesis",           TYPE_DOCTORALTHESIS },
		{ "Habilitation thesis",       TYPE_HABILITATIONTHESIS },
		{ "communication",             TYPE_COMMUNICATION },
		{ "manuscript",                TYPE_MANUSCRIPT },
		{ "report",                    TYPE_REPORT },
		{ "unpublished",               TYPE_UNPUBLISHED },
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
		/* the inbook type should be defined if 'book' in host */
		if ( type==TYPE_BOOK && info->level[i]!=0 ) type = TYPE_INBOOK;
		/* the article types should be defined if it's the host */
		if ( ( type==TYPE_ARTICLE || type==TYPE_MAGARTICLE || type==TYPE_NEWSARTICLE ) && info->level[i]<1 ) type=TYPE_UNKNOWN;
	}
	if ( type==TYPE_UNKNOWN ) {
		for ( i=0; i<info->nfields; ++i ) {
			if ( strcasecmp( info->tag[i].data, "RESOURCE" ) )
				continue;
			data = info->data[i].data;
			if ( !strcasecmp( data, "moving image" ) )
				type = TYPE_FILMBROADCAST;
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
output_type( FILE *fp, int type, param *p )
{
	/* These are restricted to Endnote-defined types */
	match_type genrenames[] = {
		{ "Generic",                TYPE_GENERIC },
		{ "Artwork",                TYPE_ARTWORK },
		{ "Audiovisual Material",   TYPE_AUDIOVISUAL },
		{ "Bill",                   TYPE_BILL },
		{ "Book",                   TYPE_BOOK },
		{ "Book Section",           TYPE_INBOOK },
		{ "Case",                   TYPE_CASE },
		{ "Chart or Table",         TYPE_CHARTTABLE },
		{ "Classical Work",         TYPE_CLASSICALWORK },
		{ "Computer Program",       TYPE_PROGRAM },
		{ "Conference Paper",       TYPE_INPROCEEDINGS },
		{ "Conference Proceedings", TYPE_PROCEEDINGS },
		{ "Edited Book",            TYPE_EDITEDBOOK },
		{ "Equation",               TYPE_EQUATION },
		{ "Electronic Article",     TYPE_ELECTRONICARTICLE },
		{ "Electronic Book",        TYPE_ELECTRONICBOOK },
		{ "Electronic Source",      TYPE_ELECTRONIC },
		{ "Figure",                 TYPE_FIGURE },
		{ "Film or Broadcast",      TYPE_FILMBROADCAST },
		{ "Government Document",    TYPE_GOVERNMENT },
		{ "Hearing",                TYPE_HEARING },
		{ "Journal Article",        TYPE_ARTICLE },
		{ "Legal Rule/Regulation",  TYPE_LEGALRULE },
		{ "Magazine Article",       TYPE_MAGARTICLE },
		{ "Manuscript",             TYPE_MANUSCRIPT },
		{ "Map",                    TYPE_MAP },
		{ "Newspaper Article",      TYPE_NEWSARTICLE },
		{ "Online Database",        TYPE_ONLINEDATABASE },
		{ "Online Multimedia",      TYPE_ONLINEMULTIMEDIA },
		{ "Patent",                 TYPE_PATENT },
		{ "Personal Communication", TYPE_COMMUNICATION },
		{ "Report",                 TYPE_REPORT },
		{ "Statute",                TYPE_STATUTE },
		{ "Thesis",                 TYPE_THESIS }, 
		{ "Thesis",                 TYPE_PHDTHESIS },
		{ "Thesis",                 TYPE_MASTERSTHESIS },
		{ "Thesis",                 TYPE_DIPLOMATHESIS },
		{ "Thesis",                 TYPE_DOCTORALTHESIS },
		{ "Thesis",                 TYPE_HABILITATIONTHESIS },
		{ "Unpublished Work",       TYPE_UNPUBLISHED },
	};
	int ngenrenames = sizeof( genrenames ) / sizeof( genrenames[0] );
	int i, found = 0;
	fprintf( fp, "%%0 ");
	for ( i=0; i<ngenrenames && !found; ++i ) {
		if ( genrenames[i].type == type ) {
			fprintf( fp, "%s", genrenames[i].name );
			found = 1;
		}
	}
	if ( !found ) {
		fprintf( fp, "Generic" );
		if ( p->progname ) fprintf( stderr, "%s: ", p->progname );
		fprintf( stderr, "Cannot identify type %d\n", type );
	}
	fprintf( fp, "\n" );
}

static void
output_title( FILE *fp, fields *info, char *full, char *sub, char *endtag, 
		int level )
{
	int n1 = fields_find( info, full, level );
	int n2 = fields_find( info, sub, level );
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
	int i;
	for ( i=0; i<info->nfields; ++i ) {
		if ( level!=-1 && info->level[i]!=level ) continue;
		if ( !strcasecmp( info->tag[i].data, tag ) ) {
			fprintf( fp, "%s ", entag );
			output_person( fp, info->data[i].data );
			fprintf( fp, "\n" );
		}
	}
}

static void
output_pages( FILE *fp, fields *info )
{
	int sn = fields_find( info, "PAGESTART", -1 );
	int en = fields_find( info, "PAGEEND", -1 );
	int ar = fields_find( info, "ARTICLENUMBER", -1 );
	if ( sn!=-1 || en!=-1 ) {
		fprintf( fp, "%%P ");
		if ( sn!=-1 ) fprintf( fp, "%s", info->data[sn].data );
		if ( sn!=-1 && en!=-1 ) fprintf( fp, "-" );
		if ( en!=-1 ) fprintf( fp, "%s", info->data[en].data );
		fprintf( fp, "\n");
	} else if ( ar!=-1 ) {
		fprintf( fp, "%%P %s\n", info->data[ar].data );
	}
}

static void
output_year( FILE *fp, fields *info, int level )
{
	int year = fields_find( info, "YEAR", level );
	if ( year==-1 ) year = fields_find( info, "PARTYEAR", level );
	if ( year!=-1 )
		fprintf( fp, "%%D %s\n", info->data[year].data );
}

static void
output_monthday( FILE *fp, fields *info, int level )
{
	char *months[12] = { "January", "February", "March", "April",
		"May", "June", "July", "August", "September", "October",
		"November", "December" };
	int m;
	int month = fields_find( info, "MONTH", level );
	int day   = fields_find( info, "DAY", level );
	if ( month==-1 ) month = fields_find( info, "PARTMONTH", level );
	if ( day==-1 ) day = fields_find( info, "PARTDAY", level );
	if ( month!=-1 || day!=-1 ) {
		fprintf( fp, "%%8 " );
		if ( month!=-1 ) {
			m = atoi( info->data[month].data );
			if ( m>0 && m<13 )
				fprintf( fp, "%s", months[m-1] );
			else
				fprintf( fp, "%s", info->data[month].data );
		}
		if ( month!=-1 && day!=-1 ) fprintf( fp, " " );
		if ( day!=-1 ) fprintf( fp, "%s", info->data[day].data );
		fprintf( fp, "\n" );
	}
}

static void
output_thesishint( FILE *fp, int type )
{
	if ( type==TYPE_MASTERSTHESIS )
		fprintf( fp, "%%9 Masters thesis\n" );
	else if ( type==TYPE_PHDTHESIS )
		fprintf( fp, "%%9 Ph.D. thesis\n" );
	else if ( type==TYPE_DIPLOMATHESIS )
		fprintf( fp, "%%9 Diploma thesis\n" );
	else if ( type==TYPE_DOCTORALTHESIS )
		fprintf( fp, "%%9 Doctoral thesis\n" );
	else if ( type==TYPE_HABILITATIONTHESIS )
		fprintf( fp, "%%9 Habilitation thesis\n" );
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

void
endout_write( fields *info, FILE *fp, param *p, unsigned long refnum )
{
	int type;
	fields_clearused( info );
	type = get_type( info );
	output_type( fp, type, p );
	output_title( fp, info, "TITLE", "SUBTITLE", "%T", 0 );
	output_title( fp, info, "SHORTTITLE", "SHORTSUBTITLE", "%!", 0 );
	output_people( fp, info, "AUTHOR", "%A", 0 );
	output_people( fp, info, "EDITOR", "%E", -1 );
	output_people( fp, info, "TRANSLATOR", "%H", -1 );
	if ( type==TYPE_CASE )
		output_easy( fp, info, "AUTHOR:CORP", "%I", 0 );
	else if ( type==TYPE_HEARING )
		output_easyall( fp, info, "AUTHOR:CORP", "%S", 0 );
	else if ( type==TYPE_NEWSARTICLE )
		output_people( fp, info, "REPORTER", "%A", 0 );
	else if ( type==TYPE_COMMUNICATION )
		output_people( fp, info, "RECIPIENT", "%E", -1 );
	else {
		output_easy( fp, info, "AUTHOR:CORP", "%A", 0 );
		output_easy( fp, info, "AUTHOR:ASIS", "%A", 0 );
		output_easy( fp, info, "EDITOR:CORP", "%E", -1 );
		output_easy( fp, info, "EDITOR:ASIS", "%E", -1 );
	}
	if ( type==TYPE_ARTICLE || type==TYPE_MAGARTICLE )
		output_title( fp, info, "TITLE", "SUBTITLE", "%J", 1 );
	else output_title( fp, info, "TITLE", "SUBTITLE", "%B", 1 );
	output_year( fp, info, -1 );
	output_monthday( fp, info, -1 );
	output_easy( fp, info, "VOLUME", "%V", -1 );
	output_easy( fp, info, "ISSUE", "%N", -1 );
	output_easy( fp, info, "NUMBER", "%N", -1 );
	output_easy( fp, info, "EDITION", "%7", -1 );
	output_easy( fp, info, "PUBLISHER", "%I", -1 );
	output_easy( fp, info, "ADDRESS", "%C", -1 );
	output_easy( fp, info, "DEGREEGRANTOR", "%C", -1 );
	output_easy( fp, info, "DEGREEGRANTOR:CORP", "%C", -1 );
	output_easy( fp, info, "DEGREEGRANTOR:ASIS", "%C", -1 );
	output_easy( fp, info, "SERIALNUMBER", "%@", -1 );
	output_easy( fp, info, "ISSN", "%@", -1 );
	output_easy( fp, info, "ISBN", "%@", -1 );
	output_easy( fp, info, "LANGUAGE", "%G", -1 );
	output_easy( fp, info, "REFNUM", "%F", -1 );
	output_easyall( fp, info, "NOTES", "%O", -1 );
	output_easy( fp, info, "ABSTRACT", "%X", -1 );
	output_easy( fp, info, "CLASSIFICATION", "%L", -1 );
	output_easyall( fp, info, "KEYWORD", "%K", -1 );
	output_easyall( fp, info, "NGENRE", "%9", -1 );
	output_thesishint( fp, type );
	output_easyall( fp, info, "URL", "%U", -1 ); 
	output_pages( fp, info );
	fprintf( fp, "\n" );
	fflush( fp );
}

void
endout_writeheader( FILE *outptr, param *p )
{
	if ( p->utf8bom ) utf8_writebom( outptr );
}

