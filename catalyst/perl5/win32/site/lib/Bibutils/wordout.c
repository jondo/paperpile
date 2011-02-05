/*
 * wordout.c
 * 
 * (Word 2007 format)
 *
 * Copyright (c) Chris Putnam 2007-2009
 *
 * Source code released under the GPL
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "newstr.h"
#include "fields.h"
#include "utf8.h"
#include "wordout.h"

typedef struct convert {
	char oldtag[25];
	char newtag[25];
	int  code;
} convert;

typedef struct outtype {
	int value;
	char *out;
} outtype;

/*
At the moment 17 unique types of sources are defined:

{code}
	Art
	ArticleInAPeriodical
	Book
	BookSection
	Case
	Conference
	DocumentFromInternetSite
	ElectronicSource
	Film
	InternetSite
	Interview
	JournalArticle
	Report
	Misc
	Patent
	Performance
	Proceedings
	SoundRecording
{code}

*/

enum {
	TYPE_UNKNOWN = 0,
	TYPE_ART,
	TYPE_ARTICLEINAPERIODICAL,
	TYPE_BOOK,
	TYPE_BOOKSECTION,
	TYPE_CASE,
	TYPE_CONFERENCE,
	TYPE_DOCUMENTFROMINTERNETSITE,
	TYPE_ELECTRONICSOURCE,
	TYPE_FILM,
	TYPE_INTERNETSITE,
	TYPE_INTERVIEW,
	TYPE_JOURNALARTICLE,
	TYPE_MISC,
	TYPE_PATENT,
	TYPE_PERFORMANCE,
	TYPE_PROCEEDINGS,
	TYPE_REPORT,
	TYPE_SOUNDRECORDING,

	TYPE_THESIS,
	TYPE_MASTERSTHESIS,
	TYPE_PHDTHESIS,
};

/*
 * fixed output
 */
static void
output_fixed( FILE *outptr, char *tag, char *data, int level )
{
	int i;
	for ( i=0; i<level; ++i ) fprintf( outptr, " " );
	fprintf( outptr, "<%s>%s</%s>\n", tag, data, tag );
}

/* detail output
 *
 */
static void
output_item( fields *info, FILE *outptr, char *tag, int item, int level )
{
	int i;
	if ( item==-1 ) return;
	for ( i=0; i<level; ++i ) fprintf( outptr, " " );
	fprintf( outptr, "<%s>%s</%s>\n", tag, info->data[item].data, tag );
	fields_setused( info, item );
}

/* range output
 *
 * <TAG>start-end</TAG>
 *
 */
static void
output_range( fields *info, FILE *outptr, char *tag, int start, int end,
		int level )
{
	int i;
	if ( start==-1 && end==-1 ) return;
	if ( start==-1 )
		output_item( info, outptr, tag, end, 0 );
	else if ( end==-1 )
		output_item( info, outptr, tag, start, 0 );
	else {
		for ( i=0; i<level; ++i )
			fprintf( outptr, " " );
		fprintf( outptr, "<%s>%s-%s</%s>\n", tag, 
			info->data[start].data, info->data[end].data, tag );
		fields_setused( info, start );
		fields_setused( info, end );
	}
}

static void
output_list( fields *info, FILE *outptr, convert *c, int nc )
{
        int i, n;
        for ( i=0; i<nc; ++i ) {
                n = fields_find( info, c[i].oldtag, c[i].code );
                if ( n!=-1 ) output_item( info, outptr, c[i].newtag, n, 0 );
        }

}

static
outtype genres[] = {
	{ TYPE_PATENT, "patent" },
	{ TYPE_REPORT, "report" },
	{ TYPE_CASE,   "legal case and case notes" },
	{ TYPE_ART,    "art original" },
	{ TYPE_ART,    "art reproduction" },
	{ TYPE_ART,    "comic strip" },
	{ TYPE_ART,    "diorama" },
	{ TYPE_ART,    "graphic" },
	{ TYPE_ART,    "model" },
	{ TYPE_ART,    "picture" },
	{ TYPE_ELECTRONICSOURCE, "electronic" },
	{ TYPE_FILM,   "videorecording" },
	{ TYPE_FILM,   "motion picture" },
	{ TYPE_SOUNDRECORDING, "sound" },
	{ TYPE_PERFORMANCE, "rehersal" },
	{ TYPE_INTERNETSITE, "web site" },
	{ TYPE_INTERVIEW, "interview" },
	{ TYPE_INTERVIEW, "communication" },
	{ TYPE_MISC, "misc" },
};
int ngenres = sizeof( genres ) / sizeof( genres[0] );

static int
get_type_from_genre( fields *info )
{
	int type = TYPE_UNKNOWN, i, j, level;
	char *genre;
	for ( i=0; i<info->nfields; ++i ) {
		if ( strcasecmp( info->tag[i].data, "GENRE" ) &&
			strcasecmp( info->tag[i].data, "NGENRE" ) ) continue;
		genre = info->data[i].data;
		for ( j=0; j<ngenres; ++j ) {
			if ( !strcasecmp( genres[j].out, genre ) )
				type = genres[j].value;
		}
		if ( type==TYPE_UNKNOWN ) {
			level = info->level[i];
			if ( !strcasecmp( genre, "academic journal" ) ) {
				type = TYPE_JOURNALARTICLE;
			}
			else if ( !strcasecmp( genre, "periodical" ) ) {
				if ( type == TYPE_UNKNOWN )
					type = TYPE_ARTICLEINAPERIODICAL;
			}
			else if ( !strcasecmp( genre, "book" ) ||
				!strcasecmp( genre, "collection" ) ) {
				if ( info->level[i]==0 ) type = TYPE_BOOK;
				else type = TYPE_BOOKSECTION;
			}
			else if ( !strcasecmp( genre, "conference publication" ) ) {
				if ( level==0 ) type=TYPE_CONFERENCE;
				type = TYPE_PROCEEDINGS;
			}
			else if ( !strcasecmp( genre, "thesis" ) ) {
	                        if ( type==TYPE_UNKNOWN ) type=TYPE_THESIS;
			}
			else if ( !strcasecmp( genre, "Ph.D. thesis" ) ) {
				type = TYPE_PHDTHESIS;
			}
			else if ( !strcasecmp( genre, "Masters thesis" ) ) {
				type = TYPE_MASTERSTHESIS;
			}
		}
	}
	return type;
}

static int
get_type_from_resource( fields *info )
{
	int type = TYPE_UNKNOWN, i;
	char *resource;
	for ( i=0; i<info->nfields; ++i ) {
		if ( strcasecmp( info->tag[i].data, "GENRE" )!=0 &&
			strcasecmp( info->tag[i].data, "NGENRE" )!=0 ) continue;
		resource = info->data[i].data;
		if ( !strcasecmp( resource, "moving image" ) )
			type = TYPE_FILM;
	}
	return type;
}

static int
get_type( fields *info )
{
	int type;
	type = get_type_from_genre( info );
	if ( type==TYPE_UNKNOWN )
		type = get_type_from_resource( info );
	return type;
}

static void
output_titleinfo( fields *info, FILE *outptr, char *tag, int level )
{
	char *p;
	int ttl, subttl;
	ttl = fields_find( info, "TITLE", level );
	subttl = fields_find( info, "SUBTITLE", level );
	if ( ttl!=-1 || subttl!=-1 ) {
		fprintf( outptr, "<%s>", tag );
		if ( ttl!=-1 ) {
			fprintf( outptr, "%s", info->data[ttl].data );
			fields_setused( info, ttl );
		}
		if ( subttl!=-1 ) {
			if ( ttl!=-1 ) {
				p = info->data[ttl].data;
				if ( p[info->data[ttl].len-1]!='?' )
					fprintf( outptr, ":" );
				fprintf( outptr, " " );
			}
			fprintf( outptr, "%s", info->data[subttl].data );
			fields_setused( info, subttl );
		}
		fprintf( outptr, "</%s>\n", tag );
	}
}

static void
output_title( fields *info, FILE *outptr, int level )
{
	int ttl = fields_find( info, "TITLE", level );
	int subttl = fields_find( info, "SUBTITLE", level );
	int shrttl = fields_find( info, "SHORTTITLE", level );

	output_titleinfo( info, outptr, "b:Title", 0 );

	/* output shorttitle if it's different from normal title */
	if ( shrttl!=-1 ) {
		if ( ttl==-1 || subttl!=-1 ||
			strcmp(info->data[ttl].data,info->data[shrttl].data) ) {
			fprintf( outptr,  " <b:ShortTitle>" );
			fprintf( outptr, "%s", info->data[shrttl].data );
			fprintf( outptr, "</b:ShortTitle>\n" );
		}
		fields_setused( info, shrttl );
	}
}

static void
output_name_nomangle( FILE *outptr, char *p )
{
	fprintf( outptr, "<b:Person>" );
	fprintf( outptr, "<b:Last>%s</b:Last>", p );
	fprintf( outptr, "</b:Person>\n" );
}

static void
output_name( FILE *outptr, char *p )
{
	newstr family, part;
	int n=0, npart=0;

	newstr_init( &family );
	while ( *p && *p!='|' ) newstr_addchar( &family, *p++ );
	if ( *p=='|' ) p++;
	if ( family.len ) {
		fprintf( outptr, "<b:Person>" );
		fprintf( outptr, "<b:Last>%s</b:Last>",family.data );
		n++;
	}
	newstr_free( &family );

	newstr_init( &part );
	while ( *p ) {
		while ( *p && *p!='|' ) newstr_addchar( &part, *p++ );
		if ( part.len ) {
			if ( n==0 ) fprintf( outptr, "<b:Person>" );
			if ( npart==0 ) 
				fprintf( outptr, "<b:First>%s</b:First>",
					part.data );
			else fprintf( outptr, "<b:Middle>%s</b:Middle>",
					part.data );
			n++;
			npart++;
		}
		if ( *p=='|' ) {
			p++;
			newstr_empty( &part );
		}
	}
	if ( n ) fprintf( outptr, "</b:Person>\n" );

	newstr_free( &part );
}


#define NAME (1)
#define NAME_ASIS (2)
#define NAME_CORP (4)

static int
extract_name_and_info( newstr *outtag, newstr *intag )
{
	int code = NAME;
	newstr_newstrcpy( outtag, intag );
	if ( newstr_findreplace( outtag, ":ASIS", "" ) ) code = NAME_ASIS;
	if ( newstr_findreplace( outtag, ":CORP", "" ) ) code = NAME_CORP;
	return code;
}

static void
output_name_type( fields *info, FILE *outptr, int level, 
			char *map[], int nmap, char *tag )
{
	newstr ntag;
	int i, j, n=0, code;
	newstr_init( &ntag );
	for ( j=0; j<nmap; ++j ) {
		for ( i=0; i<info->nfields; ++i ) {
			code = extract_name_and_info( &ntag, &(info->tag[i]) );
			if ( strcasecmp( ntag.data, map[j] ) ) continue;
			if ( n==0 )
				fprintf( outptr, "<%s><b:NameList>\n", tag );
			if ( code != NAME )
				output_name_nomangle( outptr, info->data[i].data );
			else 
				output_name( outptr, info->data[i].data );
			fields_setused( info, i );
			n++;
		}
	}
	newstr_free( &ntag );
	if ( n )
		fprintf( outptr, "</b:NameList></%s>\n", tag );
}

static void
output_names( fields *info, FILE *outptr, int level, int type )
{
	char *authors[] = { "AUTHOR", "WRITER", "ASSIGNEE", "ARTIST",
		"CARTOGRAPHER", "INVENTOR", "ORGANIZER", "DIRECTOR",
		"PERFORMER", "REPORTER", "TRANSLATOR", "RECIPIENT",
		"2ND_AUTHOR", "3RD_AUTHOR", "SUB_AUTHOR", "COMMITTEE",
		"COURT", "LEGISLATIVEBODY" };
	int nauthors = sizeof( authors ) / sizeof( authors[0] );

	char *editors[] = { "EDITOR" };
	int neditors = sizeof( editors ) / sizeof( editors[0] );

	char author_default[] = "b:Author", inventor[] = "b:Inventor";
	char *author_type = author_default;

	if ( type == TYPE_PATENT ) author_type = inventor;

	fprintf( outptr, "<b:Author>\n" );
	output_name_type( info, outptr, level, authors, nauthors, author_type );
	output_name_type( info, outptr, level, editors, neditors, "b:Editor" );
	fprintf( outptr, "</b:Author>\n" );
}

static void
output_date( fields *info, FILE *outptr, int level )
{
	convert parts[3] = {
		{ "PARTYEAR",  "b:Year",  -1 },
		{ "PARTMONTH", "b:Month", -1 },
		{ "PARTDAY",   "b:Day",   -1 }
	};

	convert fulls[3] = {
		{ "YEAR",  "", -1 },
		{ "MONTH", "", -1 },
		{ "DAY",   "", -1 }
	};

	int i, np, nf;
	for ( i=0; i<3; ++i ) {
		np = fields_find( info, parts[i].oldtag, level );
		nf = fields_find( info, fulls[i].oldtag, level );
		if ( np!=-1 )
			output_item( info, outptr, parts[i].newtag, np, 0 );
		else if ( nf!=-1 )
			output_item( info, outptr, parts[i].newtag, nf, 0 );
	}
}

static void
output_pages( fields *info, FILE *outptr, int level )
{
	int start = fields_find( info, "PAGESTART", -1 );
	int end = fields_find( info, "PAGEEND", -1 );
	int ar = fields_find( info, "ARTICLENUMBER", -1 );
	if ( start!=-1 || end!=-1 )
		output_range( info, outptr, "b:Pages", start, end, level );
	else if ( ar!=-1 )
		output_range( info, outptr, "b:Pages", ar, -1, level );
}

static void
output_includedin( fields *info, FILE *outptr, int type )
{
	if ( type==TYPE_JOURNALARTICLE ) {
		output_titleinfo( info, outptr, "b:JournalName", 1 );
	} else if ( type==TYPE_ARTICLEINAPERIODICAL ) {
		output_titleinfo( info, outptr, "b:PeriodicalName", 1 );
	} else if ( type==TYPE_BOOKSECTION ) {
		output_titleinfo( info, outptr, "b:ConferenceName", 1 ); /*??*/
	} else if ( type==TYPE_PROCEEDINGS ) {
		output_titleinfo( info, outptr, "b:ConferenceName", 1 );
	}
}

static int
type_is_thesis( int type )
{
	if ( type==TYPE_THESIS || type==TYPE_PHDTHESIS || 
			type==TYPE_MASTERSTHESIS )
		return 1;
	else return 0;
}

static void
output_thesisdetails( fields *info, FILE *outptr, int type )
{
	int i;

	if ( type==TYPE_PHDTHESIS )
		output_fixed( outptr, "b:ThesisType", "Ph.D. Thesis", 0 );
	else if ( type==TYPE_MASTERSTHESIS ) 
		output_fixed( outptr, "b:ThesisType", "Masters Thesis", 0 );

	for ( i=0; i<info->nfields; ++i ) {
		if ( strcasecmp( info->tag[i].data, "DEGREEGRANTOR" ) &&
			strcasecmp( info->tag[i].data, "DEGREEGRANTOR:ASIS") &&
			strcasecmp( info->tag[i].data, "DEGREEGRANTOR:CORP"))
				continue;
		output_item( info, outptr, "b:Institution", i, 0 );
	}
}

static
outtype types[] = {
	{ TYPE_UNKNOWN,                  "Misc" },
	{ TYPE_MISC,                     "Misc" },
	{ TYPE_BOOK,                     "Book" },
	{ TYPE_BOOKSECTION,              "BookSection" },
	{ TYPE_CASE,                     "Case" },
	{ TYPE_CONFERENCE,               "Conference" },
	{ TYPE_ELECTRONICSOURCE,         "ElectronicSource" },
	{ TYPE_FILM,                     "Film" },
	{ TYPE_INTERNETSITE,             "InternetSite" },
	{ TYPE_INTERVIEW,                "Interview" },
	{ TYPE_SOUNDRECORDING,           "SoundRecording" },
	{ TYPE_ARTICLEINAPERIODICAL,     "ArticleInAPeriodical" },
	{ TYPE_DOCUMENTFROMINTERNETSITE, "DocumentFromInternetSite" },
	{ TYPE_JOURNALARTICLE,           "JournalArticle" },
	{ TYPE_REPORT,                   "Report" },
	{ TYPE_PATENT,                   "Patent" },
	{ TYPE_PERFORMANCE,              "Performance" },
	{ TYPE_PROCEEDINGS,              "Proceedings" },
};
static
int ntypes = sizeof( types ) / sizeof( types[0] );

static void
output_type( fields *info, FILE *outptr, int type )
{
	int i, found = 0;
	fprintf( outptr, "<b:SourceType>" );
	for ( i=0; i<ntypes && !found; ++i ) {
		if ( types[i].value!=type ) continue;
		found = 1;
		fprintf( outptr, "%s", types[i].out );
	}
	if ( !found ) {
		if (  type_is_thesis( type ) ) fprintf( outptr, "Report" );
		else fprintf( outptr, "Misc" );
	}
	fprintf( outptr, "</b:SourceType>\n" );

	if ( type_is_thesis( type ) )
		output_thesisdetails( info, outptr, type );
}

static void
output_comments( fields *info, FILE *outptr, int level )
{
	int i, written=0;
	int nabs = fields_find( info, "ABSTRACT", level );
	if ( nabs!=-1 ) {
		fprintf( outptr, "<b:Comments>" );
		fprintf( outptr, "%s", info->data[nabs].data );
		written = 1;
	}
	for ( i=0; i<info->nfields; ++i ) {
		if ( info->level[i]!=level ) continue;
		if ( strcasecmp( info->tag[i].data, "NOTES" ) ) continue;
		if ( !written ) {
			fprintf( outptr, "<b:Comments>" );
			written = 1;
		}
		fprintf( outptr, "%s", info->data[i].data );
	}
	if ( written ) fprintf( outptr, "</b:Comments>\n" );
}

static void
output_bibkey( fields *info, FILE *outptr )
{
	int  n = fields_find( info, "REFNUM", -1 );
	if ( n==-1 ) n = fields_find( info, "BIBKEY", -1 );
	output_item( info, outptr, "b:Tag", n, 0 );
}

static void
output_citeparts( fields *info, FILE *outptr, int level, int max, int type )
{
	convert origin[] = {
		{ "ADDRESS",	"b:City",	-1 },
		{ "PUBLISHER",	"b:Publisher",	-1 },
		{ "EDITION",	"b:Edition",	-1 }
	};
	int norigin = sizeof( origin ) / sizeof ( convert );
	
	convert parts[] = {
		{ "VOLUME",          "b:Volume",  -1 },
		{ "SECTION",         "b:Section", -1 },
		{ "ISSUE",           "b:Issue",   -1 },
		{ "NUMBER",          "b:Issue",   -1 },
		{ "PUBLICLAWNUMBER", "b:Volume",  -1 },
		{ "SESSION",         "b:Issue",   -1 },
	};
	int nparts=sizeof(parts)/sizeof(convert);
	
	output_bibkey( info, outptr );
	output_type( info, outptr, type );
	output_list( info, outptr, origin, norigin );
	output_date( info, outptr, level );
	output_includedin( info, outptr, type );
	output_list( info, outptr, parts, nparts );
	output_pages( info, outptr, level );
	output_names( info, outptr, level, type );
	output_title( info, outptr, level );
	output_comments( info, outptr, level );
}

void
wordout_write( fields *info, FILE *outptr, param *p, unsigned long numrefs )
{
	int max = fields_maxlevel( info );
	int type = get_type( info );

	fprintf( outptr, "<b:Source>\n" );
	output_citeparts( info, outptr, -1, max, type );
	fprintf( outptr, "</b:Source>\n" );

	fflush( outptr );
}

void
wordout_writeheader( FILE *outptr, param *p )
{
	if ( p->utf8bom ) utf8_writebom( outptr );
	fprintf(outptr,"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
	fprintf(outptr,"<b:Sources SelectedStyle=\"\" "
		"xmlns:b=\"http://schemas.openxmlformats.org/officeDocument/2006/bibliography\" "
		" xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/bibliography\" >\n");
}

void
wordout_writefooter( FILE *outptr )
{
	fprintf(outptr,"</b:Sources>\n");
	fflush( outptr );
}
