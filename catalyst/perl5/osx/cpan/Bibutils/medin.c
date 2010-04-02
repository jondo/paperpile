/*
 * medin.c
 *
 * Copyright (c) Chris Putnam 2004-8
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

int
medin_readf( FILE *fp, char *buf, int bufsize, int *bufpos, newstr *line, newstr *reference, int *fcharset )
{
	newstr tmp;
	char *startptr = NULL, *endptr;
	int haveref = 0, inref = 0, file_charset = CHARSET_UNKNOWN, m;
	newstr_init( &tmp );
	while ( !haveref && newstr_fget( fp, buf, bufsize, bufpos, line ) ) {
		if ( line->data ) {
			m = xml_getencoding( line );
			if ( m!=CHARSET_UNKNOWN ) file_charset = m;
		}
		if ( line->data )
			startptr = xml_findstart( line->data, "PubmedArticle" );
		if ( startptr || inref ) {
			if ( inref ) newstr_strcat( &tmp, line->data );
			else {
				newstr_strcat( &tmp, startptr );
				inref = 1;
			}
			endptr = xml_findend( tmp.data, "PubmedArticle" );
			if ( endptr ) {
/*				newstr_segcpy( reference, tmp.data, endptr+1 );*/
				newstr_segcpy( reference, tmp.data, endptr );
				haveref = 1;
/*				newstr_empty( &buffer ); */
/*				startptr = xml_findstart( buffer.data, "PubmedArticle" );
				if ( startptr ) inref=1;
				else inref = 0;*/
			}
		}
	}
	newstr_free( &tmp );
	*fcharset = file_charset;
	return haveref;
}

/* <ArticleTitle>Mechanism and.....</ArticleTitle>
 */
static void
medin_articletitle( xml *node, fields *info )
{
	if ( node->value && node->value->data )
		fields_add( info, "TITLE", node->value->data, 0 );
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
	if ( node->value && node->value->data ) {
		if ( xml_tagexact( node, "ISSN" ) )
			fields_add( info, "ISSN", node->value->data, 1 );
		else if ( xml_tagexact( node, "Volume" ) )
			fields_add( info, "VOLUME", node->value->data, 1 );
		else if ( xml_tagexact( node, "Issue" ) )
			fields_add( info, "ISSUE", node->value->data, 1 );
		else if ( xml_tagexact( node, "Year" ) )
			fields_add( info, "PARTYEAR", node->value->data, 1 );
		else if ( xml_tagexact( node, "Month" ) )
			fields_add( info, "PARTMONTH", node->value->data, 1 );
		else if ( xml_tagexact( node, "Day" ) )
			fields_add( info, "PARTDAY", node->value->data, 1 );
		else if ( xml_tagexact( node, "MedlineDate" ) )
			medin_medlinedate( info, node->value->data, 1 );
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
		p = node->value->data;
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
	if ( xml_tagexact( node, "AbstractText" ) && node->value && node->value->data )
		fields_add( info, "ABSTRACT", node->value->data, 0 );
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
			newstr_prepend( name, node->value->data );
		}
		else newstr_strcat( name, node->value->data );
	} else if ( xml_tagexact( node, "ForeName" ) || 
	            xml_tagexact( node, "FirstName" ) ) {
		p = node->value->data;
		while ( p && *p ) {
			if ( name->len ) newstr_addchar( name, '|' );
			while ( *p && *p==' ' ) p++;
			while ( *p && *p!=' ' ) newstr_addchar( name, *p++ );
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
	if ( xml_tagexact( node, "MedlineTA" ) && node->value && node->value->data )
		fields_add( info, "TITLE", node->value->data, 1 );
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
	if ( xml_tagexact( node, "DescriptorName" ) && node->value && node->value->data ) {
		fields_add( info, "KEYWORD", node->value->data, 0 );
	}
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
	if ( xml_tag_attrib( node, "ArticleId", "IdType", "doi" ) )
		fields_add( info, "DOI", node->value->data, 0 );
	if ( xml_tag_attrib( node, "ArticleId", "IdType", "pubmed" ) )
		fields_add( info, "PUBMED", node->value->data, 0 );
	if ( xml_tag_attrib( node, "ArticleId", "IdType", "medline" ) )
		fields_add( info, "MEDLINE", node->value->data, 0 );
	if ( xml_tag_attrib( node, "ArticleId", "IdType", "pii" ) )
		fields_add( info, "PII", node->value->data, 0 );
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
	if ( xml_tagexact( node, "Article" ) && node->down )
		medin_article( node->down, info );
	else if ( xml_tagexact( node, "MedlineJournalInfo" ) && node->down )
		medin_journal2( node->down, info );
	else if ( xml_tagexact( node, "MeshHeadingList" ) && node->down )
		medin_meshheadinglist( node->down, info );
	if ( node->next ) medin_medlinecitation( node->next, info );
}

static void
medin_pubmedarticle( xml *node, fields *info )
{
	if ( xml_tagexact( node, "MedlineCitation" ) && node->down )
		medin_medlinecitation( node->down, info );
	else if ( xml_tagexact( node, "PubmedData" ) && node->down )
		medin_pubmeddata( node->down, info );
	if ( node->next ) medin_pubmedarticle( node->next, info );
}

static void
medin_assembleref( xml *node, fields *info )
{
	if ( xml_tagexact( node, "PubmedArticle" ) ) {
		if ( node->down ) medin_pubmedarticle( node->down, info );
	} else if ( node->down ) medin_assembleref( node->down, info );
	if ( node->next ) medin_assembleref( node->next, info );
	/* assume everything is a journal article */
	if ( info->nfields ) {
		fields_add( info, "RESOURCE", "text", 0 );
		fields_add( info, "ISSUANCE", "continuing", 1 );
		fields_add( info, "GENRE", "periodical", 1 );
		fields_add( info, "GENRE", "academic journal", 1 );
	}
}

int
medin_processf( fields *medin, char *data, char *filename, long nref )
{
	xml top;
	xml_init( &top );
	xml_tree( data, & top );
	medin_assembleref( &top, medin );
	xml_free( &top );
	return 1;
}

void
medin_convertf( fields *medin, fields *info, int reftype, int verbose, 
	variants *all, int nall )
{
	int i;
	for ( i=0; i<medin->nfields; ++i )
		fields_add( info, medin->tag[i].data, medin->data[i].data,
				medin->level[i] );
}
