/*
 * newstring.h
 *
 * Copyright (c) Chris Putnam 1999-2009
 *
 * Source code released under the GPL
 *
 */

#ifndef NEWSTR_H
#define NEWSTR_H

#include <stdio.h>

typedef struct newstr {
	char *data;
	unsigned long dim;
	unsigned long len;
}  newstr;

newstr *newstr_new      ( void ); 
void newstr_init        ( newstr *s );
void newstr_free        ( newstr *s );
newstr *newstr_strdup   ( char *buf );
void newstr_addchar     ( newstr *s, char newchar );
void newstr_strcat      ( newstr *s, char *addstr );
void newstr_newstrcat   ( newstr *s, newstr *old );
void newstr_segcat      ( newstr *s, char *startat, char *endat );
void newstr_prepend     ( newstr *s, char *addstr );
void newstr_strcpy      ( newstr *s, char *addstr );
void newstr_newstrcpy   ( newstr *s, newstr *old );
void newstr_segcpy      ( newstr *s, char *startat, char *endat );
void newstr_segdel      ( newstr *s, char *startat, char *endat );
void newstr_fprintf     ( FILE *fp, newstr *s );
int  newstr_fget        ( FILE *fp, char *buf, int bufsize, int *pbufpos,
                          newstr *outs );
int  newstr_findreplace ( newstr *s, char *find, char *replace );
void newstr_empty       ( newstr *s );
void newstr_toupper     ( newstr *s );
void newstr_trimendingws( newstr *s );
void newstr_swapstrings ( newstr *s1, newstr *s2 );

/* NEWSTR_PARANOIA
 *
 * set to clear memory before it is freed or reallocated
 * note that this is slower...may be important if string
 * contains sensitive information
 */

#undef NEWSTR_PARANOIA

#endif

