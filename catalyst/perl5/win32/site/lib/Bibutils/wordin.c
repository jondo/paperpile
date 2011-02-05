/*
 * wordin.c
 *
 * Copyright (c) Chris Putnam 2009
 *
 * Program and source code released under the GPL
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include "is_ws.h"
#include "newstr.h"
#include "newstr_conv.h"
#include "fields.h"
#include "xml.h"
#include "xml_encoding.h"
#include "medin.h"

static char *
wordin_findstartwrapper( char *buf, int *ntype )
{
	char *startptr = xml_findstart( buf, "b:Source" );
	return startptr;
}

static char *
wordin_findendwrapper( char *buf, int ntype )
{
	char *endptr = xml_findend( buf, "b:Source" );
	return endptr;
}

int
wordin_readf( FILE *fp, char *buf, int bufsize, int *bufpos, newstr *line, newstr *reference, int *fcharset )
{
	newstr tmp;
	char *startptr = NULL, *endptr;
	int haveref = 0, inref = 0, file_charset = CHARSET_UNKNOWN, m, type = 1;
	newstr_init( &tmp );
	while ( !haveref && newstr_fget( fp, buf, bufsize, bufpos, line ) ) {
		if ( line->data ) {
			m = xml_getencoding( line );
			if ( m!=CHARSET_UNKNOWN ) file_charset = m;
		}
		if ( line->data ) {
			startptr = wordin_findstartwrapper( line->data, &type );
		}
		if ( startptr || inref ) {
			if ( inref ) newstr_strcat( &tmp, line->data );
			else {
				newstr_strcat( &tmp, startptr );
				inref = 1;
			}
			endptr = wordin_findendwrapper( tmp.data, type );
			if ( endptr ) {
				newstr_segcpy( reference, tmp.data, endptr );
				haveref = 1;
fprintf(stderr,"reference='%s'\n",reference->data);
			}
		}
	}
	newstr_free( &tmp );
	*fcharset = file_charset;
	return haveref;
}

static inline int
xml_hasdata( xml *node )
{
	if ( node && node->value && node->value->data ) return 1;
	return 0;
}

static inline char *
xml_data( xml *node )
{
	return node->value->data;
}

static inline int
xml_tagwithdata( xml *node, char *tag )
{
	if ( !xml_hasdata( node ) ) return 0;
	return xml_tagexact( node, tag );
}

typedef struct xml_convert {
	char *in;       /* The input tag */
	char *a, *aval; /* The attribute="attribute_value" pair, if nec. */
	char *out;      /* The output tag */
	int level;
} xml_convert;

#if 0
static int
medin_doconvert( xml *node, fields *info, xml_convert *c, int nc )
{
	int i, found = 0;
	char *d;
	if ( !xml_hasdata( node ) ) return 0;
	d = xml_data( node );
	for ( i=0; i<nc && found==0; ++i ) {
		if ( c[i].a==NULL ) {
			if ( xml_tagexact( node, c[i].in ) ) {
				found = 1;
				fields_add( info, c[i].out, d, c[i].level );
			}
		} else {
			if ( xml_tag_attrib( node, c[i].in, c[i].a, c[i].aval)){
				found = 1;
				fields_add( info, c[i].out, d, c[i].level );
			}
		}
	
	}
	return found;
}

/* <ArticleTitle>Mechanism and.....</ArticleTitle>
 */
static void
medin_articletitle( xml *node, fields *info )
{
	if ( xml_hasdata( node ) )
		fields_add( info, "TITLE", xml_data( node ), 0 );
}

/*            <MedlineDate>2003 Jan-Feb</MedlineDate> */
static void
medin_medlinedate( fields *info, char *string, int level )
{
	newstr tmp;
	char *p, *q;
	newstr_init( &tmp );
	/* extract year */
	p = string;
	q = skip_notws( string );
/*	p = q = string;*/
/*	while ( *q && !is_ws(*q) ) q++;*/
	newstr_segcpy( &tmp, p, q );
	fields_add( info, "PARTYEAR", tmp.data, level );
	q = skip_ws( q );
	/* extract month */
	if ( q ) {
		p = q;
		newstr_empty( &tmp );
		q = skip_notws( q );
/*		while ( *q && !is_ws(*q) ) q++;*/
		newstr_segcpy( &tmp, p, q );
		newstr_findreplace( &tmp, "-", "/" );
		fields_add( info, "PARTMONTH", tmp.data, level );
		q = skip_ws( q );
	}
	/* extract day */
	if ( q ) {
		p = q;
		newstr_empty( &tmp );
		q = skip_notws( q );
/*		while ( *q && !is_ws(*q) ) q++;*/
		newstr_segcpy( &tmp, p, q );
		fields_add( info, "PARTDAY", tmp.data, level );
	}
	newstr_free( &tmp );
}



/* <Journal>
 *    <ISSN>0027-8424</ISSN>
 *    <JournalIssue PrintYN="Y">
 *       <Volume>100</Volume>
 *       <Issue>21</Issue>
 *       <PubDate>
 *          <Year>2003</Year>
 *          <Month>Oct</Month>
 *          <Day>14</Day>
 *       </PubDate>
 *    </Journal Issue>
 * </Journal>
 *
 * or....
 *
 * <Journal>
 *    <ISSN IssnType="Print">0735-0414</ISSN>
 *    <JournalIssue CitedMedium="Print">
 *        <Volume>38</Volume>
 *        <Issue>1</Issue>
 *        <PubDate>
 *            <MedlineDate>2003 Jan-Feb</MedlineDate>
 *        </PubDate>
 *    </JournalIssue>
 *    <Title>Alcohol and alcoholism (Oxford, Oxfordshire)  </Title>
 *    <ISOAbbreviation>Alcohol Alcohol.</ISOAbbreviation>
 * </Journal>
 */
static void
medin_journal1( xml *node, fields *info )
{
	xml_convert c[] = {
		{ "ISSN",     NULL, NULL, "ISSN",      1 },
		{ "Volume",   NULL, NULL, "VOLUME",    1 },
		{ "Issue",    NULL, NULL, "ISSUE",     1 },
		{ "Year",     NULL, NULL, "PARTYEAR",  1 },
		{ "Month",    NULL, NULL, "PARTMONTH", 1 },
		{ "Day",      NULL, NULL, "PARTDAY",   1 },
		{ "Language", NULL, NULL, "LANGUAGE",  1 },
	};
	int nc = sizeof( c ) / sizeof( c[0] );;
	if ( xml_hasdata( node ) && !medin_doconvert( node, info, c, nc ) ) {
		if ( xml_tagexact( node, "MedlineDate" ) )
			medin_medlinedate( info, xml_data( node ), 1 );
	}
	if ( node->down ) medin_journal1( node->down, info );
	if ( node->next ) medin_journal1( node->next, info );
}

/* <Pagination>
 *    <MedlinePgn>12111-6</MedlinePgn>
 * </Pagination>
 */
static void
medin_pagination( xml *node, fields *info )
{
	newstr sp, ep;
	char *p;
	int i;
	if ( xml_tagexact( node, "MedlinePgn" ) && node->value ) {
		newstr_init( &sp );
		newstr_init( &ep );
		p = xml_data( node );
		while ( *p && *p!='-' )
			newstr_addchar( &sp, *p++ );
		if ( *p=='-' ) p++;
		while ( *p )
			newstr_addchar( &ep, *p++ );
		if ( sp.len ) fields_add( info, "PAGESTART", sp.data, 1 );
		if ( ep.len ) {
			if ( sp.len > ep.len ) {
				for ( i=sp.len-ep.len; i<sp.len; ++i )
					sp.data[i] = ep.data[i-sp.len+ep.len];
				fields_add( info, "PAGEEND", sp.data, 1 );
			} else
				fields_add( info, "PAGEEND", ep.data, 1 );
		}
		newstr_free( &sp );
		newstr_free( &ep );
	}
	if ( node->down ) medin_pagination( node->down, info );
	if ( node->next ) medin_pagination( node->next, info );
}

/* <Abstract>
 *    <AbstractText>ljwejrelr</AbstractText>
 * </Abstract>
 */
static void
medin_abstract( xml *node, fields *info )
{
	if ( xml_tagwithdata( node, "AbstractText" ) )
		fields_add( info, "ABSTRACT", xml_data( node ), 0 );
	else if ( node->next ) medin_abstract( node->next, info );
}

/* <AuthorList CompleteYN="Y">
 *    <Author>
 *        <LastName>Barondeau</LastName>
 *        <ForeName>David P</ForeName>
 *        ( or <FirstName>David P</FirstName> )
 *        <Initials>DP</Initials>
 *    </Author>
 * </AuthorList>
 */
static void
medin_author( xml *node, newstr *name )
{
	char *p;
	if ( xml_tagexact( node, "LastName" ) ) {
		if ( name->len ) {
			newstr_prepend( name, "|" );
			newstr_prepend( name, xml_data( node ) );
		}
		else newstr_strcat( name, xml_data( node ) );
	} else if ( xml_tagexact( node, "ForeName" ) || 
	            xml_tagexact( node, "FirstName" ) ) {
		p = xml_data( node );
		while ( p && *p ) {
			if ( name->len ) newstr_addchar( name, '|' );
			while ( *p && *p==' ' ) p++;
			while ( *p && *p!=' ' ) newstr_addchar( name, *p++ );
		}
	} else if ( xml_tagexact( node, "Initials" ) && !strchr( name->data, '|' )) {
		p = xml_data( node );
		while ( p && *p ) {
			if ( name->len ) newstr_addchar( name, '|' );
			if ( !is_ws(*p) ) newstr_addchar( name, *p++ );
		}
	}
	if ( node->down ) medin_author( node->down, name );
	if ( node->next ) medin_author( node->next, name );
}

static void
medin_authorlist( xml *node, fields *info )
{
	newstr name;
	newstr_init( &name );
	node = node->down;
	while ( node ) {
		if ( xml_tagexact( node, "Author" ) && node->down ) {
			medin_author( node->down, &name );
			if ( name.len ) fields_add(info,"AUTHOR",name.data,0);
			newstr_empty( &name );
		}
		node = node->next;
	}
	newstr_free( &name );
}

/* <PublicationTypeList>
 *    <PublicationType>Journal Article</PublicationType>
 * </PublicationTypeList>
 */

/* <MedlineJournalInfo>
 *    <Country>United States</Country>
 *    <MedlineTA>Proc Natl Acad Sci U S A</MedlineTA>
 *    <NlmUniqueID>7507876</NlmUniqueID>
 * </MedlineJournalInfo>
 */

static void
medin_journal2( xml *node, fields *info )
{
	if ( xml_tagwithdata( node, "MedlineTA" ) )
		fields_add( info, "TITLE", xml_data( node ), 1 );
	if ( node->down ) medin_journal2( node->down, info );
	if ( node->next ) medin_journal2( node->next, info );
}

/*
<MeshHeadingList>
<MeshHeading>
<DescriptorName MajorTopicYN="N">Biophysics</DescriptorName>
</MeshHeading>
<MeshHeading>
<DescriptorName MajorTopicYN="N">Crystallography, X-Ray</DescriptorName>
</MeshHeading>
</MeshHeadingList>
*/
static void
medin_meshheading( xml *node, fields *info )
{
	if ( xml_tagwithdata( node, "DescriptorName" ) )
		fields_add( info, "KEYWORD", xml_data( node ), 0 );
	if ( node->next ) medin_meshheading( node->next, info );
}

static void
medin_meshheadinglist( xml *node, fields *info )
{
	if ( xml_tagexact( node, "MeshHeading" ) && node->down )
		medin_meshheading( node->down, info );
	if ( node->next ) medin_meshheadinglist( node->next, info );
}

/* <PubmedData>
 *     ....
 *     <ArticleIdList>
 *         <ArticleId IdType="pubmed">14523232</ArticleId>
 *         <ArticleId IdType="doi">10.1073/pnas.2133463100</ArticleId>
 *         <ArticleId IdType="pii">2133463100</ArticleId>
 *         <ArticleId IdType="medline">22922082</ArticleId>
 *     </ArticleIdList>
 * </PubmedData>
 *
 * I think "pii" is "Publisher Item Identifier"
 */

static void
medin_pubmeddata( xml *node, fields *info )
{
	xml_convert c[] = {
		{ "ArticleId", "IdType", "doi",     "DOI",     0 },
		{ "ArticleId", "IdType", "pubmed",  "PMID",    0 },
		{ "ArticleId", "IdType", "medline", "MEDLINE", 0 },
		{ "ArticleId", "IdType", "pii",     "PII",     0 },
	};
	int nc = sizeof( c ) / sizeof( c[0] );
	medin_doconvert( node, info, c, nc );
	if ( node->next ) medin_pubmeddata( node->next, info );
	if ( node->down ) medin_pubmeddata( node->down, info );
}

static void
medin_article( xml *node, fields *info )
{
	if ( xml_tagexact( node, "Journal" ) ) 
		medin_journal1( node, info );
	else if ( xml_tagexact( node, "ArticleTitle" ) )
		medin_articletitle( node, info );
	else if ( xml_tagexact( node, "Pagination" ) && node->down )
		medin_pagination( node->down, info );
	else if ( xml_tagexact( node, "Abstract" ) && node->down )
		medin_abstract( node->down, info );
	else if ( xml_tagexact( node, "AuthorList" ) )
		medin_authorlist( node, info );
	if ( node->next ) medin_article( node->next, info );
}

static void
medin_medlinecitation( xml *node, fields *info )
{
	if ( node->down ) {
		if ( xml_tagexact( node, "Article" ) )
			medin_article( node->down, info );
		else if ( xml_tagexact( node, "MedlineJournalInfo" ) )
			medin_journal2( node->down, info );
		else if ( xml_tagexact( node, "MeshHeadingList" ) )
			medin_meshheadinglist( node->down, info );
	}
	if ( node->next ) medin_medlinecitation( node->next, info );
}

static void
medin_pubmedarticle( xml *node, fields *info )
{
	if ( node->down ) {
		if ( xml_tagexact( node, "MedlineCitation" ) )
			medin_medlinecitation( node->down, info );
		else if ( xml_tagexact( node, "PubmedData" ) )
			medin_pubmeddata( node->down, info );
	}
	if ( node->next ) medin_pubmedarticle( node->next, info );
}
#endif
static void
wordin_person( xml *node, fields *info, char *type )
{
	xml *last, *first;
	newstr name;

	newstr_init( &name );

	last = node;
	while ( last && !xml_tagexact( last, "b:Last" ) )
		last = last->next;
	if ( last ) newstr_strcpy( &name, last->value->data );

	first = node;
	while ( first ) {
		if ( xml_tagexact( first, "b:First" ) ) {
			if ( name.len ) newstr_addchar( &name, '|' );
			newstr_strcat( &name, first->value->data );
		}
		first = first->next;
	}

	fields_add( info, type, name.data, 0 );

	newstr_free( &name );
}

static void
wordin_people( xml *node, fields *info, char *type )
{
	if ( xml_tagexact( node, "b:Author" ) && node->down ) {
		wordin_people( node->down, info, type );
	} else if ( xml_tagexact( node, "b:NameList" ) && node->down ) {
		wordin_people( node->down, info, type );
	} else if ( xml_tagexact( node, "b:Person" ) ) {
		if ( node->down ) wordin_person( node->down, info, type );
		if ( node->next ) wordin_people( node->next, info, type );
	}
}

static void
wordin_pages( xml *node, fields *info )
{
	newstr sp, ep;
	char *p;
	int i;
	newstr_init( &sp );
	newstr_init( &ep );
	p = xml_data( node );
	while ( *p && *p!='-' )
		newstr_addchar( &sp, *p++ );
	if ( *p=='-' ) p++;
	while ( *p )
		newstr_addchar( &ep, *p++ );
	if ( sp.len ) fields_add( info, "PAGESTART", sp.data, 1 );
	if ( ep.len ) {
		if ( sp.len > ep.len ) {
			for ( i=sp.len-ep.len; i<sp.len; ++i )
				sp.data[i] = ep.data[i-sp.len+ep.len];
			fields_add( info, "PAGEEND", sp.data, 1 );
		} else
			fields_add( info, "PAGEEND", ep.data, 1 );
	}
	newstr_free( &sp );
	newstr_free( &ep );
}

static void
wordin_reference( xml *node, fields *info )
{
	if ( xml_hasdata( node ) ) {
		if ( xml_tagexact( node, "b:Tag" ) ) {
			fields_add( info, "REFNUM", xml_data( node ), 0 );
		} else if ( xml_tagexact( node, "b:SourceType" ) ) {
		} else if ( xml_tagexact( node, "b:City" ) ) {
			fields_add( info, "ADDRESS", xml_data( node ), 0 );
		} else if ( xml_tagexact( node, "b:Publisher" ) ) {
			fields_add( info, "PUBLISHER", xml_data( node ), 0 );
		} else if ( xml_tagexact( node, "b:Title" ) ) {
			fields_add( info, "TITLE", xml_data( node ), 0 );
		} else if ( xml_tagexact( node, "b:JournalName" ) ) {
			fields_add( info, "TITLE", xml_data( node ), 1 );
		} else if ( xml_tagexact( node, "b:Volume" ) ) {
			fields_add( info, "VOLUME", xml_data( node ), 1 );
		} else if ( xml_tagexact( node, "b:Comments" ) ) {
			fields_add( info, "NOTES", xml_data( node ), 0 );
		} else if ( xml_tagexact( node, "b:Pages" ) ) {
			wordin_pages( node, info );
		} else if ( xml_tagexact( node, "b:Author" ) && node->down ) {
			wordin_people( node->down, info, "AUTHOR" );
		} else if ( xml_tagexact( node, "b:Editor" ) && node->down ) {
			wordin_people( node->down, info, "EDITOR" );
		}
	}
	if ( node->next ) wordin_reference( node->next, info );
}

static void
wordin_assembleref( xml *node, fields *info )
{
	if ( xml_tagexact( node, "b:Source" ) ) {
		if ( node->down ) wordin_reference( node->down, info );
	} else if ( node->tag->len==0 && node->down ) {
		wordin_assembleref( node->down, info );
	}
}

int
wordin_processf( fields *wordin, char *data, char *filename, long nref )
{
	xml top;
	xml_init( &top );
	xml_tree( data, &top );
	wordin_assembleref( &top, wordin );
	xml_free( &top );
	return 1;
}

void
wordin_convertf( fields *wordin, fields *info, int reftype, int verbose, 
	variants *all, int nall )
{
	int i;
	for ( i=0; i<wordin->nfields; ++i )
		fields_add( info, wordin->tag[i].data, wordin->data[i].data,
				wordin->level[i] );
}
