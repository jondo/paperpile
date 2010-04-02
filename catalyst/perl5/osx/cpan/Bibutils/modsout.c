/*
 * modsout.c
 *
 * Copyright (c) Chris Putnam 2003-8
 *
 * Source code released under the GPL
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "is_ws.h"
#include "newstr.h"
#include "newstr_conv.h"
#include "fields.h"
#include "utf8.h"
#include "modsout.h"
#include "modstypes.h"
#include "marc.h"

static int
increment_level( int level, int amt )
{
	if ( level > -1 ) return level+amt;
	else return level-amt;
}

static void
output_tab0( FILE *outptr, int level )
{
	int i;
	level = abs( level );
	for ( i=0; i<=level; ++i ) fprintf( outptr, "    " );
}

static void
output_tab1( FILE *outptr, int level, char *tag )
{
	output_tab0( outptr, level );
	fprintf( outptr, "%s", tag );
}

#if 0
static void
output_tab2( FILE *outptr, int level, char *tag, char *data, int cr )
{
	output_tab0( outptr, level );
	fprintf( outptr, "<%s>%s</%s>", tag, data, tag );
	if ( cr ) fprintf( outptr, "\n" );
}
#endif

static void
output_tab2_attrib( FILE *outptr, int level, char *tag, char *data, 
	char *attrib, char *type, int cr )
{
	output_tab0( outptr, level );
	fprintf( outptr, "<%s", tag );
	if ( attrib && type ) fprintf( outptr, " %s=\"%s\"", attrib, type );
	fprintf( outptr, ">%s</%s>", data, tag );
	if ( cr ) fprintf( outptr, "\n" );
}

static void
output_tab4( FILE *outptr, int level, char *tag, char *aname, char *avalue,
		char *data, int cr )
{
	output_tab0( outptr, level );
	fprintf( outptr, "<%s %s=\"%s\">%s</%s>", tag,aname,avalue,data,tag);
	if ( cr ) fprintf( outptr, "\n" );
}

static void
output_fill2( FILE *outptr, int level, char *tag, fields *info, int n, int cr )
{
	if ( n!=-1 ) {
		output_tab2_attrib( outptr, level, tag, info->data[n].data, 
			NULL, NULL, cr );
		fields_setused( info, n );
	}
}

#if 0
static void
output_fill2_attrib( FILE *outptr, int level, char *tag, char *attrib, char *type,
	fields *info, int n, int cr )
{
	if ( n!=-1 ) {
		output_tab2_attrib( outptr, level, tag, info->data[n].data, 
			attrib, type, cr );
		fields_setused( info, n );
	}
}
#endif

static void
output_fill4( FILE *outptr, int level, char *tag, char *aname, char *avalue,
		fields *info, int n, int cr )
{
	if ( n!=-1 ) {
		output_tab4( outptr, level, tag, aname, avalue,
				info->data[n].data, cr );
		fields_setused( info, n );
	}
}

static void
output_title( fields *info, FILE *outptr, int level )
{
	int ttl = fields_find( info, "TITLE", level );
	int subttl = fields_find( info, "SUBTITLE", level );
	int shrttl = fields_find( info, "SHORTTITLE", level );

	output_tab1( outptr, level, "<titleInfo>\n" );
	output_fill2( outptr, increment_level(level,1), "title", info, ttl, 1);
	output_fill2( outptr, increment_level(level,1), "subTitle", info, subttl, 1 );
	if ( ttl==-1 && subttl==-1 ) 
		output_tab1( outptr, increment_level(level,1), "<title/>\n" );
	output_tab1( outptr, level, "</titleInfo>\n" );

	/* output shorttitle if it's different from normal title */
	if ( shrttl!=-1 ) {
		if ( ttl==-1 || subttl!=-1 ||
			strcmp(info->data[ttl].data,info->data[shrttl].data) ) {
			output_tab1( outptr, level, 
					"<titleInfo type=\"abbreviated\">\n" );
			output_fill2( outptr, level+1, "title", info, shrttl,1);
			output_tab1( outptr, level, "</titleInfo>\n" );
		}
		fields_setused( info, shrttl );
	}
}

static void
output_personalstart( FILE *outptr, int level )
{
	int j;
	for ( j=0; j<=level; ++j ) fprintf( outptr, "    " );
		fprintf( outptr, "<name type=\"personal\">\n" );
}

static void
output_name( FILE *outptr, char *p, int level )
{
	newstr family, part;
	int n=0;

	newstr_init( &family );
	newstr_init( &part );

	while ( *p && *p!='|' ) newstr_addchar( &family, *p++ );
	if ( *p=='|' ) p++;

	while ( *p ) {
		while ( *p && *p!='|' ) newstr_addchar( &part, *p++ );
		/* truncate periods from "A. B. Jones" names */
		if ( part.len ) {
			if ( part.len==2 && part.data[1]=='.' ) {
				part.len=1;
				part.data[1]='\0';
			}
			if ( n==0 ) output_personalstart( outptr, level );
			output_tab4( outptr, increment_level(level,1), "namePart", "type", 
					"given", part.data, 1 );
			n++;
		}
		if ( *p=='|' ) {
			p++;
			newstr_empty( &part );
		}
	}

	if ( family.len ) {
		if ( n==0 ) output_personalstart( outptr, level );
		output_tab4( outptr, increment_level(level,1), "namePart", "type", "family",
				family.data, 1 );
	}

	newstr_free( &part );
	newstr_free( &family );
}


#define NO_AUTHORITY (0)
#define MARC_AUTHORITY (1)

static void
output_names( fields *info, FILE *outptr, int level )
{
	convert   names[] = {
	  { "author",        "AUTHOR",             MARC_AUTHORITY },
	  { "writer",        "WRITER",             MARC_AUTHORITY },
	  { "artist",        "ARTIST",             MARC_AUTHORITY },
	  { "cartographer",  "CARTOGRAPHER",       MARC_AUTHORITY },
	  { "commentator",   "COMMENTATOR",        NO_AUTHORITY   },
	  { "degree grantor","DEGREEGRANTOR",      MARC_AUTHORITY },
	  { "director",      "DIRECTOR",           MARC_AUTHORITY },
	  { "editor",        "EDITOR",             MARC_AUTHORITY },
	  { "inventor",      "INVENTOR",           MARC_AUTHORITY },
	  { "organizer of meeting","ORGANIZER",    MARC_AUTHORITY },
	  { "patent holder", "ASSIGNEE",           MARC_AUTHORITY },
	  { "performer",     "PERFORMER",          MARC_AUTHORITY },
	  { "recipient",     "RECIPIENT",          MARC_AUTHORITY },
	  { "redactor",      "REDACTOR",           NO_AUTHORITY   },
	  { "reporter",      "REPORTER",           NO_AUTHORITY   },
	  { "translator",    "TRANSLATOR",         MARC_AUTHORITY },
	  { "author",        "2ND_AUTHOR",         MARC_AUTHORITY },
	  { "author",        "3RD_AUTHOR",         MARC_AUTHORITY },
	  { "author",        "SUB_AUTHOR",         MARC_AUTHORITY },
	  { "author",        "COMMITTEE",          MARC_AUTHORITY },
	  { "author",        "COURT",              MARC_AUTHORITY },
	  { "author",        "LEGISLATIVEBODY",    MARC_AUTHORITY }
	};
	int       i, n, ntypes = sizeof( names ) / sizeof( convert );
	newstr role;
	int f_asis, f_corp;

	newstr_init( &role );
	for ( n=0; n<ntypes; ++n ) {
		for ( i=0; i<info->nfields; ++i ) {
			if ( info->level[i]!=level ) continue;
			f_asis = f_corp = 0;
			newstr_strcpy( &role, info->tag[i].data );
			if ( newstr_findreplace( &role, ":ASIS", "" )) f_asis=1;
			if ( newstr_findreplace( &role, ":CORP", "" )) f_corp=1;
			if ( strcasecmp( role.data, names[n].internal ) )
				continue;
			if ( f_asis ) {
				output_tab0( outptr, level );
				fprintf( outptr, "<name>\n" );
				output_fill2( outptr, increment_level(level,1), "namePart", info, i, 1 );
			} else if ( f_corp ) {
				output_tab0( outptr, level );
				fprintf( outptr, "<name type=\"corporate\">\n" );
				output_fill2( outptr, increment_level(level,1), "namePart", info, i, 1 );
			} else {
				output_name(outptr, info->data[i].data, level);
			}
			output_tab1( outptr, increment_level(level,1), "<role>\n" );
			output_tab1( outptr, increment_level(level,2), "<roleTerm" );
			if ( names[n].code & MARC_AUTHORITY )
				fprintf( outptr, " authority=\"marcrelator\"");
			fprintf( outptr, " type=\"text\">");
			fprintf( outptr, "%s", names[n].mods );
			fprintf( outptr, "</roleTerm>\n");
			output_tab1( outptr, increment_level(level,1), "</role>\n" );
			output_tab1( outptr, level, "</name>\n" );
			fields_setused( info, i );
		}
	}
	newstr_free( &role );
}

static int
output_finddateissued( fields *info, int level, int pos[3] )
{
	char      *src_names[] = { "YEAR", "MONTH", "DAY" };
	char      *alt_names[] = { "PARTYEAR", "PARTMONTH", "PARTDAY" };
	int       i, found = -1, ntypes = 3;

	for ( i=0; i<ntypes; ++i ) {
		pos[i] = fields_find( info, src_names[i], level );
		if ( pos[i]!=-1 ) found = pos[i];
	}
	/* for LEVEL_MAIN, do what it takes to find a date */
	if ( found==-1 && level==0 ) {
		for ( i=0; i<ntypes; ++i ) {
			pos[i] = fields_find( info, src_names[i], -1 );
			if ( pos[i]!=-1 ) found = pos[i];
		}
	}
	if ( found==-1 && level==0 ) {
		for ( i=0; i<ntypes; ++i ) {
			pos[i] = fields_find( info, alt_names[i], -1 );
			if ( pos[i]!=-1 ) found = pos[i];
		}
	}
	return found;
}

static void
output_dateissued( fields *info, FILE *outptr, int level, int pos[3] )
{
	int nprinted = 0, i;
	output_tab1( outptr, increment_level(level,1), "<dateIssued>" );
	for ( i=0; i<3 && pos[i]!=-1; ++i ) {
		if ( nprinted>0 ) fprintf( outptr, "-" );
		if ( i>0 && info->data[pos[i]].len==1 )
			fprintf( outptr, "0" ); /*zero pad Jan,Feb,etc*/
		fprintf( outptr,"%s",info->data[pos[i]].data );
		nprinted++;
		fields_setused( info, pos[i] );
	}
	fprintf( outptr, "</dateIssued>\n" );
}

static void
output_origin( fields *info, FILE *outptr, int level )
{
	convert origin[] = {
		{ "issuance",	"ISSUANCE",	0 },
		{ "publisher",	"PUBLISHER",	0 },
		{ "place",	"ADDRESS",	1 },
		{ "edition",	"EDITION",	0 }
	};
	int n, ntypes = sizeof( origin ) / sizeof ( convert );
	int found, datefound, pos[5], date[3];

	/* find all information to be outputted */
	found = -1;
	for ( n=0; n<ntypes; ++n ) {
		pos[n] = fields_find( info, origin[n].internal, level );
		if ( pos[n]!=-1 ) found = pos[n];
	}
	datefound = output_finddateissued( info, level, date );
	if ( found==-1 && datefound==-1 ) return;

	output_tab1( outptr, level, "<originInfo>\n" );
	output_fill2( outptr, increment_level(level,1), "issuance", info, pos[0], 1 );
	if ( datefound!=-1 ) output_dateissued( info, outptr, level, date );

	for ( n=1; n<ntypes; n++ ) {
		if ( pos[n]==-1 ) continue;
		output_tab0( outptr, increment_level(level,1) );
		fprintf( outptr, "<%s", origin[n].mods );
		fprintf( outptr, ">" );
		if ( origin[n].code ) {
			fprintf( outptr, "\n" );
			output_fill4( outptr, increment_level(level,2), 
				"placeTerm", "type", "text", info, pos[n], 1 );
			output_tab0( outptr, increment_level(level,1) );
		} else {
			fprintf( outptr, "%s", info->data[pos[n]].data );
			fields_setused( info, pos[n] );
		}
		fprintf( outptr, "</%s>\n", origin[n].mods );
	}
	output_tab1( outptr, level, "</originInfo>\n" );
}

static void
output_language( fields *info, FILE *outptr, int level )
{
	int n = fields_find( info, "LANGUAGE", level );
	output_fill2( outptr, level, "language", info, n, 1 );
}

static void
output_description( fields *info, FILE *outptr, int level )
{
	int n = fields_find( info, "DESCRIPTION", level );
	output_fill2( outptr, level, "physicalDescription", info, n, 1 );
}

static void
output_toc( fields *info, FILE *outptr, int level )
{
	int n = fields_find( info, "CONTENTS", level );
	output_fill2( outptr, level, "tableOfContents", info, n, 1 );
}

/* part date output
 *
 * <date>xxxx-xx-xx</date>
 *
 */
static void
output_partdate( fields *info, FILE *outptr, int level, int *wrote_header )
{
	convert parts[3] = {
		{ "",	"PARTYEAR",                -1 },
		{ "",	"PARTMONTH",               -1 },
		{ "",	"PARTDAY",                 -1 },
	};
	int i, found = 0;
	for ( i=0; i<3; ++i ) {
		parts[i].code = fields_find( info, parts[i].internal, level );
		found += ( parts[i].code!=-1 );
	}
	if ( !found ) return;

	if ( !*wrote_header ) {
		output_tab1( outptr, level, "<part>\n" );
		*wrote_header = 1;
	}

	output_tab1( outptr, increment_level(level,1), "<date>" );

	if ( parts[0].code!=-1 ) {
		fprintf( outptr, "%s", info->data[ parts[0].code ].data);
		fields_setused( info, parts[0].code );
	}

	if ( parts[1].code!=-1 ) {
		if ( parts[0].code!=-1 ) fprintf( outptr, "-" );
		else fprintf( outptr, "XXXX-" );
		fprintf( outptr, "%s", info->data[parts[1].code].data );
		fields_setused( info, parts[1].code );
	}

	if ( parts[2].code!=-1 ) {
		if ( parts[1].code!=-1 ) fprintf( outptr, "-" );
		else if ( parts[0].code!=-1 ) fprintf( outptr, "-XX-" );
		fprintf( outptr, "%s", info->data[parts[2].code].data );
		fields_setused( info, parts[2].code );
	}

	fprintf( outptr,"</date>\n");
}

/* detail output
 *
 * for example:
 *
 * <detail type="volume"><number>xxx</number></detail
 */
static void
mods_output_detail( fields *info, FILE *outptr, int item, char *item_name,
		int level )
{
	if ( item==-1 ) return;
	output_tab0( outptr, increment_level(level,1) );
	fprintf( outptr, "<detail type=\"%s\"><number>", item_name );
	fprintf( outptr, "%s</number></detail>\n", info->data[item].data );
	fields_setused( info, item );
}


/* extents output
 *
 * <extent unit="page">
 * 	<start>xxx</start>
 * 	<end>xxx</end>
 * </extent>
 */
static void
mods_output_extents( fields *info, FILE *outptr, int start, int end,
		int total, char *extype, int level )
{
	output_tab0( outptr, increment_level(level,1) );
	fprintf( outptr, "<extent unit=\"%s\">\n", extype);
	output_fill2( outptr, increment_level(level,2), "start", info, start, 1 );
	output_fill2( outptr, increment_level(level,2), "end", info, end, 1 );
	output_fill2( outptr, increment_level(level,2), "total", info, total, 1 );
	output_tab1 ( outptr, increment_level(level,1), "</extent>\n" );
}

static void
mods_output_partpages( fields *info, FILE *outptr, int level, int *wrote_header )
{
	convert parts[3] = {
		{ "",  "PAGESTART",                -1 },
		{ "",  "PAGEEND",                  -1 },
		{ "",  "TOTALPAGES",               -1 }
	};
	int i, found = 0;
	for ( i=0; i<3; ++i ) {
		parts[i].code = fields_find( info, parts[i].internal, level );
		found += ( parts[i].code!=-1 );
	}
	if ( !found ) return;
	if ( !*wrote_header ) {
		output_tab1( outptr, level, "<part>\n" );
		*wrote_header = 1;
	}
	/* If PAGESTART or PAGEEND are  undefined */
	if ( parts[0].code==-1 || parts[1].code==-1 ) {
		if ( parts[0].code!=-1 )
			mods_output_detail( info, outptr, parts[0].code,
				"page", level );
		if ( parts[1].code!=-1 )
			mods_output_detail( info, outptr, parts[1].code,
				"page", level );
		if ( parts[2].code!=-1 )
			mods_output_extents( info, outptr, -1, -1,
					parts[2].code, "page", level ); 
	}
	/* If both PAGESTART and PAGEEND are defined */
	else {
		mods_output_extents( info, outptr, parts[0].code, 
			parts[1].code, parts[2].code, "page", level ); 
	}
}

static void
output_partelement( fields *info, FILE *outptr, int level, int *wrote_header )
{
	convert parts[] = {
		{ "volume",          "VOLUME",          -1 },
		{ "section",         "SECTION",         -1 },
		{ "issue",           "ISSUE",           -1 },
		{ "number",          "NUMBER",          -1 },
		{ "publiclawnumber", "PUBLICLAWNUMBER", -1 },
		{ "session",         "SESSION",         -1 },
		{ "articlenumber",   "ARTICLENUMBER",   -1 }
	};
	int i, nparts = sizeof( parts ) / sizeof( convert ), found = 0;
	for ( i=0; i<nparts; ++i ) {
		parts[i].code = fields_find( info, parts[i].internal, level );
		found += ( parts[i].code!=-1 );
	}
	if ( !found ) return;
	if ( !(*wrote_header) ) {
		output_tab1( outptr, level, "<part>\n" );
		*wrote_header = 1;
	}
	for ( i=0; i<nparts; ++i ) {
		if ( parts[i].code==-1 ) continue;
		mods_output_detail( info, outptr, parts[i].code, 
			parts[i].mods, level );
	}
}

static void
output_part( fields *info, FILE *outptr, int level )
{
	int wrote_header = 0;
	output_partdate( info, outptr, level, &wrote_header );
	output_partelement( info, outptr, level, &wrote_header );
	mods_output_partpages( info, outptr, level, &wrote_header );
	if ( wrote_header )
		output_tab1( outptr, level, "</part>\n" );
}

static void
output_genre( fields *info, FILE *outptr, int level )
{
	int i, ismarc;
	for ( i=0; i<info->nfields; ++i ) {
		if ( info->level[i]!=level ) continue;
		if ( strcasecmp( info->tag[i].data, "GENRE" ) ) continue;
		if ( marc_findgenre( info->data[i].data )!=-1 ) ismarc = 1;
		else ismarc = 0;
		output_tab1( outptr, level, "<genre" );
		if ( ismarc ) 
			fprintf( outptr, " authority=\"marcgt\"" );
		fprintf( outptr, ">%s</genre>\n", info->data[i].data );
		fields_setused( info, i );
	}
}

static void
output_typeresource( fields *info, FILE *outptr, int level )
{
	int n, ismarc = 0;
	n = fields_find( info, "RESOURCE", level );
	if ( n!=-1 ) {
		if ( marc_findresource( info->data[n].data )!=-1 ) ismarc = 1;
		if ( !ismarc ) {
			fprintf( stderr, "Illegal typeofResource = '%s'\n",
					info->data[n].data );
		} else {
			output_fill2( outptr, level, "typeOfResource", info, 
				n, 1 );
		}
		fields_setused( info, n );
	}
}

static void
output_type( fields *info, FILE *outptr, int level )
{
	int n = fields_find( info, "TYPE", 0 );
	if ( n!=-1 ) fields_setused( info, n );
	output_typeresource( info, outptr, level );
	output_genre( info, outptr, level );
}

static void
output_abs( fields *info, FILE *outptr, int level )
{
	int i;
	int nabs = fields_find( info, "ABSTRACT", level );
	output_fill2( outptr, level, "abstract", info, nabs, 1 );
	for ( i=0; i<info->nfields; ++i ) {
		if ( info->level[i]!=level ) continue;
		if ( strcasecmp( info->tag[i].data, "NOTES" ) ) continue;
		output_fill2( outptr, level, "note", info, i, 1 );
	}
}

static void
output_timescited( fields *info, FILE *outptr, int level )
{
	int n = fields_find( info, "TIMESCITED", level );
	if ( n!=-1 ) {
		output_tab0( outptr, level );
		fprintf( outptr, "<note>Times Cited: %s</note>\n",
				info->data[n].data );
		fields_setused( info, n );
	}
}

static void
output_indexkey( fields *info, FILE *outptr, int level )
{
	int n = fields_find( info, "BIBKEY", level );
	if ( n!=-1 ) {
		output_tab0( outptr, level );
		fprintf( outptr, "<note>Key: %s</note>\n",
				info->data[n].data );
		fields_setused( info, n );
	}
}

static void
output_key( fields *info, FILE *outptr, int level )
{
	int i;
	for ( i=0; i<info->nfields; ++i ) {
		if ( info->level[i]!=level ) continue;
		if ( !strcasecmp( info->tag[i].data, "KEYWORD" ) ) {
			output_tab1( outptr, level, "<subject>\n" );
			output_fill2( outptr, increment_level(level,1), "topic", info, i, 1 );
			output_tab1( outptr, level, "</subject>\n" );
		}
	}
}

static void
output_sn( fields *info, FILE *outptr, int level )
{
	char      *internal_names[] = { "ISBN", "LCCN", "ISSN", "REFNUM", 
		"DOI" , "PUBMED", "MEDLINE", "PII", "ISIREFNUM", "ACCESSNUM" };
	char      *mods_types[] = { "isbn", "lccn", "issn", "citekey", "doi",
		"pubmed", "medline", "pii", "isi", "accessnum" };
	int       n, ntypes = sizeof( internal_names ) / sizeof( char* );
	int       found, i;

	found = fields_find ( info, "CALLNUMBER", level );
	output_fill2( outptr, level, "classification", info, found, 1 );

	for ( n=0; n<ntypes; ++n ) {
		found = fields_find( info, internal_names[n], level );
		if ( found==-1 ) continue;
		output_tab0( outptr, level );
		fprintf( outptr, "<identifier type=\"%s\">%s</identifier>\n",
				mods_types[n],
				info->data[found].data
		       );
		fields_setused( info, found );
	}
	for ( i=0; i<info->nfields;++i ) {
		if ( info->level[i]!=level ) continue;
		if ( !strcasecmp( info->tag[i].data, "SERIALNUMBER" ) ) {
			output_tab0( outptr, level );
			fprintf( outptr, "<identifier type=\"%s\">%s</identifier>\n",
				"serial number", info->data[i].data );
			fields_setused( info, i );
		}
	}
}

static void
output_url( fields *info, FILE *outptr, int level )
{
	int location = fields_find( info, "LOCATION", level );
	int url = fields_find( info, "URL", level );
	int pdflink = fields_find( info, "PDFLINK", level );
	int i;
	if ( url==-1 && location==-1 && pdflink==-1 ) return;
	output_tab1( outptr, level, "<location>\n" );
	for ( i=0; i<info->nfields; ++i ) {
		if ( info->level[i]!=level ) continue;
		if ( !strcasecmp( info->tag[i].data, "URL" ) ) {
			output_fill2( outptr, increment_level(level,1), "url", info, i, 1 );
		} else if ( !strcasecmp( info->tag[i].data, "PDFLINK" ) ) {
			output_fill2( outptr, increment_level(level,1), "url",
				/*"urlType", "pdf",*/ info, i, 1 );
		}
	}
	if ( location!=-1 )
		output_fill2( outptr, increment_level(level,1), "physicalLocation", info, 
				location, 1 );
	output_tab1( outptr, level, "</location>\n" );
}

/* refnum should start with a non-number and not include spaces */
static void
output_refnum( fields *info, int n, FILE *outptr )
{
	char *p = info->data[n].data;
	if ( p && ((*p>='0' && *p<='9') || *p=='-' || *p=='_' ))
		fprintf( outptr, "ref" );
	while ( p && *p ) {
		if ( !is_ws(*p) ) fprintf( outptr, "%c", *p );
/*		if ( (*p>='A' && *p<='Z') ||
		     (*p>='a' && *p<='z') ||
		     (*p>='0' && *p<='9') ||
		     (*p=='-') || (*p=='
		     (*p=='_') ) fprintf( outptr, "%c", *p );*/
		p++;
	}
}

static void
output_head( fields *info, FILE *outptr, int dropkey, unsigned long numrefs )
{
	int n;
	fprintf( outptr, "<mods");
	if ( !dropkey ) {
		n = fields_find( info, "REFNUM", 0 );
		if ( n!=-1 ) {
			fprintf( outptr, " ID=\"");
			output_refnum( info, n, outptr );
			fprintf( outptr, "\"");
		}
	}
	fprintf( outptr, ">\n" );
}

static int
original_items( fields *info, int level )
{
	int i, targetlevel;
	if ( level < 0 ) return 0;
	targetlevel = -( level + 2 );
	for ( i=0; i<info->nfields; ++i )
		if ( info->level[i]==targetlevel ) return targetlevel;
	return 0;
}

static void
output_citeparts( fields *info, FILE *outptr, int level, int max )
{
	int orig_level;
	output_title( info, outptr, level );
	output_names( info, outptr, level);
	output_origin( info, outptr, level );
	output_type( info, outptr, level );
	output_language( info, outptr, level );
	output_description( info, outptr, level );
	if ( level>=0 && level < max ) {
		output_tab0( outptr, level );
		fprintf( outptr, "<relatedItem type=\"host\">\n" );
		output_citeparts(info, outptr, increment_level(level,1), max );
		output_tab0( outptr, level );
		fprintf( outptr, "</relatedItem>\n");
	}
	/* Look for original item things */
	orig_level = original_items( info, level );
	if ( orig_level ) {
		output_tab0( outptr, level );
		fprintf( outptr, "<relatedItem type=\"original\">\n" );
		output_citeparts( info, outptr, orig_level, max );
		output_tab0( outptr, level );
		fprintf( outptr, "</relatedItem>\n" );
	}
	output_abs( info, outptr, level );
	output_timescited( info, outptr, level );
	output_indexkey( info, outptr, level );
	output_toc( info, outptr, level );
	output_key( info, outptr, level );
	output_sn( info, outptr, level );
	output_url( info, outptr, level );
	/* as of MODS 3.1, <part> tags can be in the main items */
	/*if ( level>0 ) */
	output_part( info, outptr, level );
}

static void
modsout_report_unused_tag( fields *info, int i, param *p, unsigned long numrefs )
{
	if ( p->progname ) fprintf( stderr, "%s: ", p->progname );
	fprintf( stderr, "Ref %lu unused tag: '%s' value: '%s' level: %d\n",
			numrefs+1, info->tag[i].data, info->data[i].data,
			info->level[i] );
}

static void
modsout_report_unused_tags( fields *info, param *p, unsigned long numrefs )
{
	int i;
	for ( i=0; i<info->nfields; ++i ) {
		if ( info->used[i] ) continue;
		modsout_report_unused_tag( info, i, p, numrefs );
	}
}

void
modsout_write( fields *info, FILE *outptr, param *p, unsigned long numrefs )
{
	int max, dropkey;
	max = fields_maxlevel( info );
	dropkey = ( p->format_opts & MODSOUT_DROPKEY );

	output_head( info, outptr, dropkey, numrefs );
	output_citeparts( info, outptr, 0, max );
	modsout_report_unused_tags( info, p, numrefs );

	fprintf( outptr, "</mods>\n" );
	fflush( outptr );
}

void
modsout_writeheader( FILE *outptr, param *p )
{
	if ( p->utf8bom ) utf8_writebom( outptr );
	fprintf(outptr,"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
	fprintf(outptr,"<modsCollection xmlns=\"http://www.loc.gov/mods/v3\">\n");
}

void
modsout_writefooter( FILE *outptr )
{
	fprintf(outptr,"</modsCollection>\n");
	fflush( outptr );
}
