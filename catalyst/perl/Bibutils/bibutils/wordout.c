/*
 * wordout.c
 * 
 * (Word 2007 format)
 *
 * Copyright (c) Chris Putnam 2007-8
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

enum {
	TYPE_UNKNOWN = 0,
	TYPE_ARTICLE,
	TYPE_BOOK,
	TYPE_INBOOK,
	TYPE_INPROCEEDINGS,
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

static int
get_type( fields *info )
{
	char *genre;
	int i, type = TYPE_UNKNOWN;
	for ( i=0; i<info->nfields; ++i ) {
		if ( strcasecmp( info->tag[i].data, "GENRE" )!=0 &&
			strcasecmp( info->tag[i].data, "NGENRE" )!=0 ) continue;
		genre = info->data[i].data;
		if ( !strcasecmp( genre, "periodical" ) ||
		     !strcasecmp( genre, "academic journal" ) )
			type = TYPE_ARTICLE;
		else if ( !strcasecmp( genre, "book" ) ||
			!strcasecmp( genre, "collection" ) ) {
			if ( info->level[i]==0 ) type = TYPE_BOOK;
			else type = TYPE_INBOOK;
		}
                else if ( !strcasecmp( genre, "conference publication" ) ) {
/*                        if ( level==0 ) type=TYPE_PROCEEDINGS;*/
                        /*else */ type = TYPE_INPROCEEDINGS;
                }
		else if ( !strcasecmp( genre, "thesis" ) ) {
                        if ( type==TYPE_UNKNOWN ) type=TYPE_THESIS;
                } else if ( !strcasecmp( genre, "Ph.D. thesis" ) )
                        type = TYPE_PHDTHESIS;
                else if ( !strcasecmp( genre, "Masters thesis" ) )
                        type = TYPE_MASTERSTHESIS;

	}
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
output_name( FILE *outptr, char *p, int level )
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

static void
output_name_type( fields *info, FILE *outptr, int level, 
			convert *map, int nmap, char *tag )
{
	int i, n;
	fprintf( outptr, "<%s><b:NameList>\n", tag );
	for ( n=0; n<nmap; ++n ) {
		for ( i=0; i<info->nfields; ++i ) {
			if ( strcasecmp(info->tag[i].data,map[n].oldtag) )
				continue;
			if ( map[n].code & NAME_ASIS || 
					map[n].code & NAME_CORP ) {
				fprintf( outptr, "<b:Person>" );
				fprintf( outptr, "<b:Last>%s</b:Last>",
					info->data[i].data );
				fprintf( outptr, "</b:Person>\n" );
			} else {
				output_name(outptr, info->data[i].data, level);
			}
			fields_setused( info, i );
		}
	}
	fprintf( outptr, "</b:NameList></%s>\n", tag );
}

static void
output_names( fields *info, FILE *outptr, int level )
{
	convert authors[] = {
		{ "AUTHOR",       "author",               NAME },
		{ "AUTHOR:ASIS",  "author",               NAME_ASIS },
		{ "AUTHOR:CORP",  "author",               NAME_CORP },
		{ "WRITER",       "author",               NAME },
		{ "WRITER:ASIS",  "author",               NAME_ASIS },
		{ "WRITER:CORP",  "author",               NAME_CORP },
		{ "ASSIGNEE",     "author",               NAME },
		{ "ASSIGNEE:ASIS","author",               NAME_ASIS },
		{ "ASSIGNEE:CORP","author",               NAME_CORP },
		{ "ARTIST",       "artist",               NAME },
		{ "ARTIST:ASIS",  "artist",               NAME_ASIS },
		{ "ARTIST:CORP",  "artist",               NAME_CORP },
		{ "CARTOGRAPHER", "cartographer",         NAME },
		{ "CARTOGRAPHER:ASIS", "cartographer",    NAME_ASIS},
		{ "CARTOGRAPHER:CORP", "cartographer",     NAME_CORP},
		{ "INVENTOR",     "inventor",             NAME },
		{ "INVENTOR:ASIS","inventor",             NAME_ASIS},
		{ "INVENTOR:CORP","inventor",             NAME_CORP},
		{ "ORGANIZER",    "organizer of meeting", NAME },
		{ "ORGANIZER:ASIS","organizer of meeting",NAME_ASIS },
		{ "ORGANIZER:CORP","organizer of meeting",NAME_CORP },
		{ "DIRECTOR",     "director",             NAME },
		{ "DIRECTOR:ASIS","director",     NAME_ASIS },
		{ "DIRECTOR:CORP","director",     NAME_CORP },
		{ "PERFORMER",    "performer",    NAME },
		{ "PERFORMER:ASIS","performer",   NAME_ASIS },
		{ "PERFORMER:CORP","performer",   NAME_CORP },
		{ "REPORTER",     "reporter",     NAME },
		{ "REPORTER:ASIS","reporter",     NAME_ASIS },
		{ "REPORTER:CORP","reporter",     NAME_CORP },
		{ "TRANSLATOR",   "translator",   NAME },
		{ "DIRECTOR",     "director",     NAME },
		{ "DIRECTOR:ASIS","director",     NAME_ASIS },
		{ "DIRECTOR:CORP","director",     NAME_CORP },
		{ "PERFORMER",    "performer",    NAME },
		{ "PERFORMER:ASIS","performer",   NAME_ASIS },
		{ "PERFORMER:CORP","performer",   NAME_CORP },
		{ "TRANSLATOR",   "translator",   NAME },
		{ "TRANSLATOR:ASIS", "translator",NAME_ASIS },
		{ "TRANSLATOR:CORP", "translator",NAME_CORP },
		{ "RECIPIENT",    "recipient",    NAME },
		{ "RECIPIENT:ASIS","recipient",   NAME_ASIS },
		{ "RECIPIENT:CORP","recipient",   NAME_CORP },
		{ "2ND_AUTHOR",   "author",       NAME },
		{ "2ND_AUTHOR:ASIS","author",     NAME_ASIS },
		{ "2ND_AUTHOR:CORP","author",     NAME_CORP },
		{ "3RD_AUTHOR",   "author",       NAME },
		{ "3RD_AUTHOR:ASIS","author",     NAME_ASIS },
		{ "3RD_AUTHOR:CORP","author",     NAME_CORP },
		{ "SUB_AUTHOR",   "author",       NAME },
		{ "SUB_AUTHOR:ASIS","author",     NAME_ASIS },
		{ "COMMITTEE:CORP",    "author",  NAME_CORP },
		{ "COURT:CORP",        "author",  NAME_CORP },
		{ "LEGISLATIVEBODY:CORP",   "author",  NAME_CORP }
	};
	int nauthors = sizeof( authors ) / sizeof( convert );

	convert editors[] = {
		{ "EDITOR",       "editor", NAME },
		{ "EDITOR:ASIS",  "editor", NAME_ASIS },
		{ "EDITOR:CORP",  "editor", NAME_CORP },
	};
	int neditors = sizeof( editors ) / sizeof( convert );
	
	fprintf( outptr, "<b:Author>\n" );
	output_name_type( info, outptr, level, authors, nauthors, "b:Author" );
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
	if ( type==TYPE_ARTICLE ) {
		output_titleinfo( info, outptr, "b:JournalName", 1 );
	} else if ( type==TYPE_INBOOK ) {
		output_titleinfo( info, outptr, "b:ConferenceName", 1 ); /*??*/
	} else if ( type==TYPE_INPROCEEDINGS ) {
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

static void
output_type( fields *info, FILE *outptr, int type )
{
	fprintf( outptr, "<b:SourceType>" );
	if ( type==TYPE_UNKNOWN || type==TYPE_BOOK )
		fprintf( outptr, "Book" );
	else if ( type==TYPE_INBOOK )
		fprintf( outptr, "BookSection" );
	else if ( type==TYPE_ARTICLE )
		fprintf( outptr, "JournalArticle" );
	else if ( type==TYPE_INPROCEEDINGS )
		fprintf( outptr, "ConferenceProceedings" );
	else if ( type_is_thesis( type ) ) 
		fprintf( outptr, "Report" );
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
	output_names( info, outptr, level);
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
