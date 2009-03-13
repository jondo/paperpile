/*
 * risin.c
 *
 * Copyright (c) Chris Putnam 2003-8
 *
 * Program and source code released under the GPL
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "newstr.h"
#include "newstr_conv.h"
#include "fields.h"
#include "name.h"
#include "title.h"
#include "serialno.h"
#include "reftypes.h"
#include "risin.h"

/* RIS definition of a tag is strict:
    character 1 = uppercase alphabetic character
    character 2 = uppercase alphabetic character or digit
    character 3 = space (ansi 32)
    character 4 = space (ansi 32)
    character 5 = dash (ansi 45)
    character 6 = space (ansi 32)
*/
static int
risin_istag( char *buf )
{
	if (! (buf[0]>='A' && buf[0]<='Z') ) return 0;
	if (! (((buf[1]>='A' && buf[1]<='Z'))||(buf[1]>='0'&&buf[1]<='9')) ) 
		return 0;
	if (buf[2]!=' ') return 0;
	if (buf[3]!=' ') return 0;
	if (buf[4]!='-') return 0;
	if (buf[5]!=' ') return 0;
	return 1;
}

static int
readmore( FILE *fp, char *buf, int bufsize, int *bufpos, newstr *line )
{
	if ( line->len ) return 1;
	else return newstr_fget( fp, buf, bufsize, bufpos, line );
}

int
risin_readf( FILE *fp, char *buf, int bufsize, int *bufpos, newstr *line, 
		newstr *reference, int *fcharset )
{
	int haveref = 0, inref = 0, readtoofar = 0;
	char *p;
	while ( !haveref && readmore( fp, buf, bufsize, bufpos, line ) ) {
		if ( !line->data || line->len==0 ) continue;
		p = &( line->data[0] );
		/* Each reference starts with 'TY  - ' && ends with 'ER  - ' */
		if ( strncmp(p,"TY  - ",6)==0 ) {
			if ( !inref ) {
				inref = 1;
			} else {
				/* we've read too far.... */
				readtoofar = 1;
				inref = 0;
			}
		}
		if ( risin_istag( p ) ) {
			if ( !inref ) {
				fprintf(stderr,"Warning.  Tagged line not "
					"in properly started reference.\n");
				fprintf(stderr,"Ignored: '%s'\n", p );
			} else if ( !strncmp(p,"ER  -",5) ) {
				inref = 0;
			} else {
				newstr_addchar( reference, '\n' );
				newstr_strcat( reference, p );
			}
		}
		/* not a tag, but we'll append to last values ...*/
		else if ( inref && strncmp(p,"ER  -",5)) {
			newstr_addchar( reference, '\n' );
			newstr_strcat( reference, p );
		}
		if ( !inref && reference->len ) haveref = 1;
		if ( !readtoofar ) newstr_empty( line );
	}
	if ( inref ) haveref = 1;
	*fcharset = CHARSET_UNKNOWN;
	return haveref;
}

static char*
process_line2( newstr *tag, newstr *data, char *p )
{
	while ( *p==' ' || *p=='\t' ) p++;
	while ( *p && *p!='\r' && *p!='\n' )
		newstr_addchar( data, *p++ );
	while ( *p=='\r' || *p=='\n' ) p++;
	return p;
}

static char*
process_line( newstr *tag, newstr *data, char *p )
{
	int i = 0;
	while ( i<6 && *p ) {
		if ( i<2 ) newstr_addchar( tag, *p );
		p++;
		i++;
	}
	while ( *p==' ' || *p=='\t' ) p++;
	while ( *p && *p!='\r' && *p!='\n' )
		newstr_addchar( data, *p++ );
	newstr_trimendingws( data );
	while ( *p=='\n' || *p=='\r' ) p++;
	return p;
}

int
risin_processf( fields *risin, char *p, char *filename, long nref )
{
	newstr tag, data;
	newstr_init( &tag );
	newstr_init( &data );

	while ( *p ) {
		if ( risin_istag( p ) ) {
		p = process_line( &tag, &data, p );
		/* no anonymous fields allowed */
/*		if ( tag.len && data.len )*/
		if ( tag.len )
			fields_add( risin, tag.data, data.data, 0 );
		} else {
			p = process_line2( &tag, &data, p );
			if ( data.len && risin->nfields>0 ) {
				newstr *od;
				od = &(risin->data[risin->nfields-1] );
				newstr_addchar( od, ' ' );
				newstr_strcat( od, data.data );
			}
		}
		newstr_empty( &tag );
		newstr_empty( &data );
	}

	newstr_free( &tag );
	newstr_free( &data );
	return 1;
}

/* oxfordjournals hide the DOI in the NOTES N1 field */
static void
notes_add( fields *info, char *tag, newstr *s, int level )
{
	int doi = is_doi( s->data );
	if ( doi!=-1 )
		fields_add( info, "DOI", &(s->data[doi]), level );
	else
		fields_add( info, tag, s->data, level );
}

static void
adddate( fields *info, char *tag, char *p, int level )
{
	newstr date;
	int part = ( !strncasecmp( tag, "PART", 4 ) );

	newstr_init( &date );
	while ( *p && *p!='/' ) newstr_addchar( &date, *p++ );
	if ( *p=='/' ) p++;
	if ( date.len>0 ) {
		if ( part ) fields_add( info, "PARTYEAR", date.data, level );
		else        fields_add( info, "YEAR",     date.data, level );
	}

	newstr_empty( &date );
	while ( *p && *p!='/' ) newstr_addchar( &date, *p++ );
	if ( *p=='/' ) p++;
	if ( date.len>0 ) {
		if ( part ) fields_add( info, "PARTMONTH", date.data, level );
		else        fields_add( info, "MONTH",     date.data, level );
	}

	newstr_empty( &date );
	while ( *p && *p!='/' ) newstr_addchar( &date, *p++ );
	if ( *p=='/' ) p++;
	if ( date.len>0 ) {
		if ( part ) fields_add( info, "PARTDAY", date.data, level );
		else        fields_add( info, "DAY",     date.data, level );
	}

	newstr_empty( &date );
	while ( *p ) newstr_addchar( &date, *p++ );
	if ( date.len>0 ) {
		if ( part ) fields_add( info, "PARTDATEOTHER", date.data,level);
		else        fields_add( info, "DATEOTHER", date.data, level );
	}
	newstr_free( &date );
}

int
risin_typef( fields *risin, char *filename, int nref, param *p, variants *all, int nall )
{
	char *refnum = "";
	int n, reftype, nreftype;
	n = fields_find( risin, "TY", 0 );
	nreftype = fields_find( risin, "ID", 0 );
	if ( nreftype!=-1 ) refnum = risin[n].data->data;
	if ( n!=-1 )
		reftype = get_reftype( (risin[n].data)->data, nref, p->progname,
			all, nall, refnum );
	else
		reftype = get_reftype( "", nref, p->progname, all, nall, refnum ); /*default */
	return reftype;
}

static void
risin_report_notag( param *p, char *tag )
{
	if ( p->verbose && strcmp( tag, "TY" ) ) {
		if ( p->progname ) fprintf( stderr, "%s: ", p->progname );
		fprintf( stderr, "Did not identify RIS tag '%s'\n", tag );
	}
}

void
risin_convertf( fields *risin, fields *info, int reftype, param *p, variants *all, int nall )
{
	newstr *t, *d;
	int process, level, i, n;
	char *newtag;
	for ( i=0; i<risin->nfields; ++i ) {
		t = &( risin->tag[i] );
		d = &( risin->data[i] );
		n = process_findoldtag( t->data, reftype, all, nall );
		if ( n==-1 ) {
			risin_report_notag( p, t->data );
			continue;
		}
		process = ((all[reftype]).tags[n]).processingtype;
		level   = ((all[reftype]).tags[n]).level;
		newtag  = ((all[reftype]).tags[n]).newstr;
		if ( process==SIMPLE )
			fields_add( info, newtag, d->data, level );
		else if ( process==PERSON )
			name_add( info, newtag, d->data, level, &(p->asis), 
					&(p->corps) );
		else if ( process==TITLE )
			title_process( info, newtag, d->data, level );
		else if ( process==DATE )
			adddate( info, newtag, d->data, level );
		else if ( process==SERIALNO )
			addsn( info, d->data, level );
		else if ( process==NOTES )
			notes_add( info, newtag, d, level );
		else { /* do nothing */ }
	}
	/* look for thesis-type hint */
	if ( !strcasecmp( all[reftype].type, "THES" ) ) {
		for ( i=0; i<risin->nfields; ++i ) {
			if ( strcasecmp(risin->tag[i].data, "U1") )
				continue;
			if ( !strcasecmp(risin->data[i].data,"Ph.D. Thesis")||
			     !strcasecmp(risin->data[i].data,"Masters Thesis")||
			     !strcasecmp(risin->data[i].data,"Diploma Thesis")||
			     !strcasecmp(risin->data[i].data,"Doctoral Thesis")||
			     !strcasecmp(risin->data[i].data,"Habilitation Thesis"))
				fields_add( info, "GENRE", risin->data[i].data,
					0 );
		}
	}
}
