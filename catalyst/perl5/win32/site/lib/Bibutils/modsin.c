/*
 * modsin.c
 *
 * Copyright (c) Chris Putnam 2004-2009
 *
 * Source code released under the GPL
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "newstr.h"
#include "newstr_conv.h"
#include "xml.h"
#include "xml_encoding.h"
#include "fields.h"
#include "name.h"
#include "reftypes.h"
#include "modstypes.h"
#include "marc.h"

static char modsns[]="mods";

static void
modsin_detailr( xml *node, newstr *value )
{
	if ( node->value && node->value->len ) {
		if ( value->len ) newstr_addchar( value, ' ' );
		newstr_newstrcat( value, node->value );
	}
	if ( node->down ) modsin_detailr( node->down, value );
	if ( node->next ) modsin_detailr( node->next, value );
}

static void
modsin_detail( xml *node, fields *info, int level )
{
	newstr type, value, *tp;
	if ( node->down ) {
		newstr_init( &type );
		newstr_init( &value );
		tp = xml_getattrib( node, "type" );
		if ( tp ) {
			newstr_newstrcpy( &type, tp );
			newstr_toupper( &type );
		}
		modsin_detailr( node->down, &value );
		if ( type.data && !strcasecmp( type.data, "PAGE" ) ) {
			fields_add( info, "PAGESTART", value.data, level );
		} else fields_add( info, type.data, value.data, level );
		newstr_free( &type );
		newstr_free( &value );
	}
}

static void
modsin_date( xml *node, fields *info, int level, int part )
{
/*	char *month[12] = { "January", "February", "March", "April",
		"May", "June", "July", "August", "September", "October",
		"November", "December" };*/
	newstr s;
	char *p = NULL;
/*	int m;*/
	if ( node->value ) p = node->value->data;
	if ( p ) {
		newstr_init( &s );
		while ( *p && *p!='-' ) newstr_addchar( &s, *p++ );
		if ( !part ) fields_add( info, "YEAR", s.data, level );
		else fields_add( info, "PARTYEAR", s.data, level );
		if ( *p=='-' ) p++;
		newstr_empty( &s );
		while ( *p && *p!='-' ) newstr_addchar( &s, *p++ );
/*		m = atoi( s.data );*/
/*		if ( m > 0 && m < 13 )  {
			if ( !part ) fields_add( info, "MONTH", month[m-1], level );
			else fields_add( info, "PARTMONTH", month[m-1], level );
		} else {*/
			if ( !part ) fields_add( info, "MONTH", s.data, level );
			else fields_add( info, "PARTMONTH", s.data, level );
/*		}*/
		if ( *p=='-' ) p++;
		newstr_empty( &s );
		while ( *p ) newstr_addchar( &s, *p++ );
		if ( !part ) fields_add( info, "DAY", s.data, level );
		else fields_add( info, "PARTDAY", s.data, level );
		newstr_free( &s );
	}
}

static void
modsin_pager( xml *node, newstr *sp, newstr *ep, newstr *tp, newstr *lp )
{
	if ( xml_tagexact( node, "start" ) ) {
		newstr_newstrcpy( sp, node->value );
	} else if ( xml_tagexact( node, "end" ) ) {
		newstr_newstrcpy( ep, node->value );
	} else if ( xml_tagexact( node, "total" ) ) {
		newstr_newstrcpy( tp, node->value );
	} else if ( xml_tagexact( node, "list" ) ) {
		newstr_newstrcpy( lp, node->value );
	}
	if ( node->down ) modsin_pager( node->down, sp, ep, tp, lp );
	if ( node->next ) modsin_pager( node->next, sp, ep, tp, lp );
}

static void
modsin_page( xml *node, fields *info, int level )
{
	newstr sp, ep, tp, lp;
	if ( node->down ) {
		newstr_init( &sp );
		newstr_init( &ep );
		newstr_init( &tp );
		newstr_init( &lp );
		modsin_pager( node->down, &sp, &ep, &tp, &lp );
		if ( sp.len || ep.len ) {
			if ( sp.len )
				fields_add( info, "PAGESTART", sp.data, level );
			if ( ep.len )
				fields_add( info, "PAGEEND", ep.data, level );
		} else if ( lp.len ) {
			fields_add( info, "PAGESTART", lp.data, level );
		}
		if ( tp.len )
			fields_add( info, "TOTALPAGES", tp.data, level );
		newstr_free( &sp );
		newstr_free( &ep );
		newstr_free( &tp );
		newstr_free( &lp );
	}
}

static void
modsin_titler( xml *node, newstr *title, newstr *subtitle )
{
	if ( xml_tagexact( node, "title" ) ) {
		if ( title->len ) {
			newstr_strcat( title, " : " );
			newstr_newstrcat( title, node->value );
		} else {
			newstr_newstrcat( title, node->value );
		}
	} else if ( xml_tagexact( node, "subTitle" ) )
		newstr_newstrcat( subtitle, node->value );
	if ( node->down ) modsin_titler( node->down, title, subtitle );
	if ( node->next ) modsin_titler( node->next, title, subtitle );
}

static void
modsin_title( xml *node, fields *info, int level )
{
	newstr title, subtitle;
	int abbr = xml_tag_attrib( node, "titleInfo", "type", "abbreviated" );
	if ( node->down ) {
		newstr_init( &title );
		newstr_init( &subtitle );
		modsin_titler( node->down, &title, &subtitle );
		if ( title.len ) {
			if ( abbr ) 
				fields_add( info, "SHORTTITLE", title.data, level );
			else
				fields_add( info, "TITLE", title.data, level );
		}
		if ( subtitle.len ) {
			if ( abbr )
				fields_add( info, "SHORTSUBTITLE", subtitle.data, level );
			else
				fields_add( info, "SUBTITLE", subtitle.data, level );
		}
		newstr_free( &title );
		newstr_free( &subtitle );
	}
}

/*
 * find match in roles if newstr has the format of
 *
 * creator|cre
 */
static int
modsin_rolesmatch( convert *roles_convert, int nroles, newstr *s )
{
	char *p, *q;
	int i, nmismatch;
	for ( i=0; i<nroles; ++i ) {
		p = s->data;
		while ( *p ) {
			q = roles_convert[i].mods;
			nmismatch = 0;
			while ( *p && *p!='|' && nmismatch == 0) {
				if ( toupper( *p ) != toupper( *q ) )
					nmismatch++;
				p++;
				q++;
			}
			if ( !nmismatch && !(*(q++))) return i;
			if ( *p=='|' ) p++;
		}
	}
	return -1;
}

static void
modsin_asis_corp_r( xml *node, newstr *name, newstr *role )
{
	if ( xml_tagexact( node, "namePart" ) )
		newstr_newstrcpy( name, node->value );
	else if ( xml_tagexact( node, "roleTerm" ) ) {
		if ( role->len ) newstr_addchar( role, '|' );
		newstr_newstrcat( role, node->value );
	}
	if ( node->down ) modsin_asis_corp_r( node->down, name, role );
	if ( node->next ) modsin_asis_corp_r( node->next, name, role );
}

static void
modsin_personr( xml *node, newstr *name, newstr *roles )
{
	if ( xml_tagexact( node, "namePart" ) ) {
		if ( xml_tag_attrib( node, "namePart", "type", "family" ) ) {
			if ( name->len ) newstr_prepend( name, "|" );
			newstr_prepend( name, node->value->data );
		} else if (xml_tag_attrib( node, "namePart", "type", "date")){
		} else {
			if ( name->len ) newstr_addchar( name, '|' );
			if ( strchr( node->value->data, ',' ) ) 
				name_comma( node->value->data, name );
			else name_nocomma( node->value->data, name );
		}
	} else if ( xml_tagexact( node, "roleTerm" ) ) {
		if ( roles->len ) newstr_addchar( roles, '|' );
		newstr_newstrcat( roles, node->value );
	}
	if ( node->down ) modsin_personr( node->down, name, roles );
	if ( node->next ) modsin_personr( node->next, name, roles );
}

static void
modsin_asis_corp( xml *node, fields *info, int level, convert *roles_convert,
		int nroles )
{
	newstr name, roles;
	int n;
	xml *dnode = node->down;
	if ( dnode ) {
		newstr_init( &name );
		newstr_init( &roles );
		modsin_asis_corp_r( dnode, &name, &roles );
		if ( roles.len ) {
			n = modsin_rolesmatch( roles_convert, nroles, &roles );
			if ( n!=-1 ) {
				fields_add( info, roles_convert[n].internal, 
					name.data, level );
			} else {
				fields_add( info, roles.data, name.data, level);
			}
		}
		else fields_add( info, roles_convert[0].internal, name.data, 
			level );
		newstr_free( &name );
		newstr_free( &roles );
	}
}

static void
modsin_asis( xml *node, fields *info, int level )
{
	convert roles_convert[] = {
		{ "author",              "AUTHOR:ASIS" },
		{ "creator",             "AUTHOR:ASIS" },
		{ "editor",              "EDITOR:ASIS" },
		{ "degree grantor",      "DEGREEGRANTOR:ASIS" },
		{ "organizer of meeting","ORGANIZER:ASIS" },
		{ "patent holder",       "ASSIGNEE:ASIS" }
	};
	int nroles = sizeof( roles_convert ) / sizeof( roles_convert[0] );
	modsin_asis_corp( node, info, level, roles_convert, nroles );
}

static void
modsin_corp( xml *node, fields *info, int level )
{
	convert roles_convert[] = {
		{ "author",              "AUTHOR:CORP" },
		{ "creator",             "AUTHOR:CORP" },
		{ "editor",              "EDITOR:CORP" },
		{ "degree grantor",      "DEGREEGRANTOR:CORP" },
		{ "organizer of meeting","ORGANIZER:CORP" },
		{ "patent holder",       "ASSIGNEE:CORP" }
	};
	int nroles = sizeof( roles_convert ) / sizeof( roles_convert[0] );
	modsin_asis_corp( node, info, level, roles_convert, nroles );
}

static void
modsin_person( xml *node, fields *info, int level )
{
	newstr name, roles, role;
	char *p;
	xml *dnode = node->down;
	if ( dnode ) {
		newstr_init( &name );
		newstr_init( &role );
		newstr_init( &roles );
		modsin_personr( dnode, &name, &roles );
		/* no defined role, default to author */
		if ( !roles.len ) newstr_strcpy( &roles, "author" );
		p = roles.data;
		while ( p && *p ) {
			while ( p && *p && *p!='|' ) newstr_addchar(&role,*p++);
			if ( !strcasecmp( role.data, "author" ) ||
			     !strcasecmp( role.data, "creator" ) )
				fields_add( info, "AUTHOR", name.data, level );
			else if ( !strcasecmp( role.data, "editor" ) )
				fields_add( info, "EDITOR", name.data, level );
			else fields_add( info, role.data, name.data, level );
			if ( *p=='|' ) p++;
			newstr_empty( &role );
		}
		newstr_free( &name );
		newstr_free( &roles );
		newstr_free( &role );
	}
}

static void
modsin_placeterm( xml *node, fields *info, int level, int school )
{
	char address_tag[] = "ADDRESS",
	     addresscode_tag[] = "CODEDADDRESS",
	     school_tag[] = "SCHOOL",
	     *newtag;
	newstr *type, s;

	newtag = ( school ) ? school_tag : address_tag;

	type = xml_getattrib( node, "type" );
	if ( type && type->len ) {
		if ( !strcmp( type->data, "text" ) ) {
			fields_add( info, newtag, node->value->data, level );
		} else if ( !strcmp( type->data, "code" ) ) {
			newstr_init( &s );
			type = xml_getattrib( node, "authority" );
			if ( type && type->len ) newstr_newstrcpy(&s, type);
			newstr_addchar( &s, '|' );
			newstr_newstrcat( &s, node->value );
			fields_add( info, addresscode_tag, s.data, level );
			newstr_free( &s );
		}
	}
}

static void
modsin_placer( xml *node, fields *info, int level, int school )
{
	if ( xml_tag_attrib( node, "place", "type", "school" ) ) {
		school = 1;
	} else if ( xml_tagexact( node, "placeTerm" ) ) {
		modsin_placeterm( node, info, level, school );
	}
	if ( node->down ) modsin_placer( node->down, info, level, school );
	if ( node->next ) modsin_placer( node->next, info, level, school );
}

static void
modsin_origininfor( xml *node, fields *info, int level, newstr *pub, newstr *add, newstr *addc, newstr *ed, newstr *iss )
{
	if ( xml_tagexact( node, "dateIssued" ) )
		modsin_date( node, info, level, 0 );
	else if ( xml_tagexact( node, "publisher" ) )
		newstr_newstrcat( pub, node->value );
	else if ( xml_tagexact( node, "edition" ) )
		newstr_newstrcat( ed, node->value );
	else if ( xml_tagexact( node, "issuance" ) )
		newstr_newstrcat( iss, node->value );
	else if ( xml_tagexact( node, "place" ) )
		modsin_placer( node, info, level, 0 );
	if ( node->down )
		modsin_origininfor( node->down, info, level, pub, add, 
				addc, ed, iss );
	if ( node->next ) modsin_origininfor( node->next, info, level, pub, add, addc, ed, iss );
}

static void
modsin_origininfo( xml *node, fields *info, int level )
{
	newstr publisher, address, addcode, edition, issuance;
	if ( node->down ) {
		newstr_init( &publisher );
		newstr_init( &address );
		newstr_init( &addcode );
		newstr_init( &edition );
		newstr_init( &issuance );
		modsin_origininfor( node->down, info, level, &publisher, 
				&address, &addcode, &edition, &issuance );
		if ( publisher.len )
			fields_add( info, "PUBLISHER", publisher.data, level );
		if ( address.len )
			fields_add( info, "ADDRESS", address.data, level );
		if ( addcode.len )
			fields_add( info, "CODEDADDRESS", addcode.data, level );
		if ( edition.len )
			fields_add( info, "EDITION", edition.data, level );
		if ( issuance.len ) 
			fields_add( info, "ISSUANCE", issuance.data, level );
		newstr_free( &publisher );
		newstr_free( &address );
		newstr_free( &addcode );
		newstr_free( &edition );
		newstr_free( &issuance );
	}
}

static void
modsin_subjectr( xml *node, fields *info, int level )
{
	if ( xml_tagexact( node, "topic" ) || xml_tagexact( node, "geographic" )) {
		fields_add( info, "KEYWORD", node->value->data, level );
	}
	if ( node->down ) modsin_subjectr( node->down, info, level );
	if ( node->next ) modsin_subjectr( node->next, info, level );
}

static void
modsin_subject( xml *node, fields *info, int level )
{
	if ( node->down ) modsin_subjectr( node->down, info, level );
}

static void
modsin_id1( xml *node, fields *info, int level )
{
	newstr *ns;
	ns = xml_getattrib( node, "ID" );
	if ( ns ) {
		fields_add( info, "REFNUM", ns->data, level );
	}
}

static void
modsin_genre( xml *node, fields *info, int level )
{
	char *added[] = { "manuscript", "academic journal", "magazine",
		"hearing", "report", "Ph.D. thesis", "Masters thesis",
		"Diploma thesis", "Doctoral thesis", "Habilitation thesis",
		"collection", "handwritten note", "communication",
		"teletype", "airtel", "memo", "e-mail communication",
		"press release", "television broadcast", "electronic"
	};
	int nadded = sizeof( added ) /sizeof( char *);
	int j, ismarc = 0, isadded = 0;
	if ( node->value && node->value->len ) {
		if ( marc_findgenre( node->value->data )!=-1 ) ismarc = 1;
		for ( j=0; j<nadded && ismarc==0 && isadded==0; ++j ) {
			if ( !strcasecmp( node->value->data, added[j] ) )
				isadded = 1;
		}
		if ( ismarc || isadded ) 
			fields_add( info, "GENRE", node->value->data, level );
		else
			fields_add( info, "NGENRE", node->value->data, level );
	}
}

static void
modsin_resource( xml *node, fields *info, int level )
{
	if ( node->value && node->value->len )
		fields_add( info, "RESOURCE", node->value->data, level );
}

static void
modsin_language( xml *node, fields *info, int level )
{
	if ( node->value && node->value->len )
		fields_add( info, "LANGUAGE", node->value->data, level );
}

static void
modsin_toc( xml *node, fields *info, int level )
{
	if ( node->value && node->value->len )
		fields_add( info, "CONTENTS", node->value->data, level );
}

static void
modsin_note( xml *node, fields *info, int level )
{
	if ( node->value && node->value->len )
		fields_add( info, "NOTES", node->value->data, level );
}

static void
modsin_abstract( xml *node, fields *info, int level )
{
	if ( node->value && node->value->len )
		fields_add( info, "ABSTRACT", node->value->data, level );
}

static void
modsin_locationr( xml *node, fields *info, int level )
{
	char url[]="URL", school[]="SCHOOL", loc[]="LOCATION";
	char fileattach[]="FILEATTACH", *tag=NULL;

	if ( xml_tag_attrib( node, "url", "access", "raw object" ) ) {
		tag = fileattach;
	} else if ( xml_tagexact( node, "url" ) ) {
		tag = url;
	}

	if ( xml_tag_attrib( node, "physicalLocation", "type", "school" ) ) {
		tag = school;
	} else if ( xml_tagexact( node, "physicalLocation" ) ) {
		tag = loc;
	}

	if ( tag ) fields_add( info, tag, node->value->data, level );

	if ( node->down ) modsin_locationr( node->down, info, level );
	if ( node->next ) modsin_locationr( node->next, info, level );
}

static void
modsin_location( xml *node, fields *info, int level )
{
	if ( node->down ) modsin_locationr( node->down, info, level );
}

static void
modsin_descriptionr( xml *node, newstr *s )
{
	if ( xml_tagexact( node, "extent" ) ) 
		newstr_newstrcpy( s, node->value );
	if ( node->down ) modsin_descriptionr( node->down, s );
	if ( node->next ) modsin_descriptionr( node->next, s );
}

static void
modsin_description( xml *node, fields *info, int level )
{
	newstr s;
	newstr_init( &s );
	if ( node->down ) modsin_descriptionr( node->down, &s );
	else {
		if ( node->value && node->value->data );
		newstr_newstrcpy( &s, node->value );
	}
	if ( s.len ) fields_add( info, "DESCRIPTION", s.data, level );
	newstr_free( &s );
}

static void
modsin_partr( xml *node, fields *info, int level )
{
	if ( xml_tagexact( node, "detail" ) )
		modsin_detail( node, info, level );
	else if ( xml_tag_attrib( node, "extent", "unit", "page" ) )
		modsin_page( node, info, level );
	else if ( xml_tag_attrib( node, "extent", "unit", "pages" ) )
		modsin_page( node, info, level );
	else if ( xml_tagexact( node, "date" ) )
		modsin_date( node, info, level, 1 );
	if ( node->next ) modsin_partr( node->next, info, level );
}

static void
modsin_part( xml *node, fields *info, int level )
{
	if ( node->down ) modsin_partr( node->down, info, level );
}

/* <classification authority="lcc">Q3 .A65</classification> */
static void
modsin_classification( xml *node, fields *info, int level )
{
	if ( node->value && node->value->len ) {
		if (xml_tag_attrib(node, "classification", "authority", "lcc")){
			fields_add( info, "LCC", node->value->data, level );
		} else
		 fields_add( info, "CLASSIFICATION", node->value->data, level );
	}
	if ( node->down ) modsin_classification( node->down, info, level );
}

static void
modsin_identifier( xml *node, fields *info, int level )
{
	convert ids[] = {
		{ "citekey",       "REFNUM"       },
		{ "issn",          "ISSN"         },
		{ "isbn",          "ISBN"         },
		{ "doi",           "DOI"          },
		{ "url",           "URL"          },
		{ "uri",           "URL"          },
		{ "pmid",          "PMID"         },
		{ "pubmed",        "PMID"         },
		{ "medline",       "MEDLINE"      },
		{ "arXiv",         "ARXIV"        },
		{ "pii",           "PII"          },
		{ "isi",           "ISIREFNUM"    },
		{ "serial number", "SERIALNUMBER" },
		{ "accessnum",     "ACCESSNUM"    }
	};
	int i , n = sizeof( ids ) / sizeof( ids[0] );
	if ( !node->value || !node->value->data ) return;
	for ( i=0; i<n; ++i ) {
		if ( xml_tag_attrib( node, "identifier", "type", ids[i].mods ) )
			fields_add( info, ids[i].internal, node->value->data, level );
	}
}

static void
modsin_mods( xml *node, fields *info, int level )
{
	if ( xml_tagexact( node, "titleInfo" ) )
		modsin_title( node, info, level );
	else if ( xml_tag_attrib( node, "name", "type", "personal" ) )
		modsin_person( node, info, level );
	else if ( xml_tag_attrib( node, "name", "type", "corporate" ) )
		modsin_corp( node, info, level );
	else if ( xml_tagexact( node, "name" ) )
		modsin_asis( node, info, level );
	else if  ( xml_tagexact( node, "part" ) )
		modsin_part( node, info, level );
	else if ( xml_tagexact( node, "identifier" ) )
		modsin_identifier( node, info, level );
	else if ( xml_tagexact( node, "originInfo" ) )
		modsin_origininfo( node, info, level );
	else if ( xml_tagexact( node, "typeOfResource" ) )
		modsin_resource( node, info, level );
	else if ( xml_tagexact( node, "language" ) )
		modsin_language( node, info, level );
	else if ( xml_tagexact( node, "tableOfContents" ) )
		modsin_toc( node, info, level );
	else if ( xml_tagexact( node, "genre" ) )
		modsin_genre( node, info, level );
	else if ( xml_tagexact( node, "date" ) )
		modsin_date( node, info, level, 0 );
	else if ( xml_tagexact( node, "note" ) )
		modsin_note( node, info, level );
	else if ( xml_tagexact( node, "abstract" ) )
		modsin_abstract( node, info, level );
	else if ( xml_tagexact( node, "subject" ) )
		modsin_subject( node, info, level );
	else if ( xml_tagexact( node, "classification" ) )
		modsin_classification( node, info, level );
	else if ( xml_tagexact( node, "location" ) )
		modsin_location( node, info, level );
	else if ( xml_tagexact( node, "physicalDescription" ) )
		modsin_description( node, info, level );
	else if ( xml_tag_attrib( node, "relatedItem", "type", "host" ) ||
	          xml_tag_attrib( node, "relatedItem", "type", "series" ) ) {
		if ( node->down ) modsin_mods( node->down, info, level+1 );
	}

	if ( node->next ) modsin_mods( node->next, info, level );

}

static void
modsin_assembleref( xml *node, fields *info )
{
	if ( xml_tagexact( node, "mods" ) ) {
		modsin_id1( node, info, 0 );
		if ( node->down ) modsin_mods( node->down, info, 0 );
	} else if ( node->down ) modsin_assembleref( node->down, info );
	if ( node->next ) modsin_assembleref( node->next, info );
}

void
modsin_convertf( fields *modsin, fields *info, int reftype, int verbose, 
	variants *all, int nall )
{
	int i;
	for ( i=0; i<modsin->nfields; ++i )
		fields_add( info, modsin->tag[i].data, modsin->data[i].data,
				modsin->level[i] );
}

int
modsin_processf( fields *modsin, char *data, char *filename, long nref )
{
	xml top;
	xml_init( &top );
	xml_tree( data, &top );
	modsin_assembleref( &top, modsin );
	xml_free( &top );
	return 1;
}


static char *
modsin_startptr( char *p )
{
	char *startptr;
	startptr = xml_findstart( p, "mods:mods" );
	if ( startptr ) {
		/* set namespace if found */
		xml_pns = modsns;
	} else {
		startptr = xml_findstart( p, "mods" );
		if ( startptr ) xml_pns = NULL;
	}
	return startptr;
}

static char *
modsin_endptr( char *p )
{
	return xml_findend( p, "mods" );
}

int
modsin_readf( FILE *fp, char *buf, int bufsize, int *bufpos, newstr *line,
		newstr *reference, int *fcharset )
{
	newstr tmp;
	int m, file_charset = CHARSET_UNKNOWN;
	char *startptr = NULL, *endptr = NULL;

	newstr_init( &tmp );

	do {
		if ( line->data ) newstr_newstrcat( &tmp, line );
		if ( tmp.data ) {
			m = xml_getencoding( &tmp );
			if ( m!=CHARSET_UNKNOWN ) file_charset = m;
			startptr = modsin_startptr( tmp.data );
			endptr = modsin_endptr( tmp.data );
		} else startptr = endptr = NULL;
		newstr_empty( line );
		if ( startptr && endptr ) {
			newstr_segcpy( reference, startptr, endptr );
			newstr_strcpy( line, endptr );
		}
	} while ( !endptr && newstr_fget( fp, buf, bufsize, bufpos, line ) );

	newstr_free( &tmp );
	*fcharset = file_charset;
	return ( reference->len > 0 );
}

