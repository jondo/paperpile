/*
 * gb18030.h
 *
 * Copyright (c) Chris Putnam 2008-2009
 *
 * Program and source code released under the GPL
 *
 */
#ifndef GB18030_H
#define GB18030_H

extern int gb18030_encode( unsigned int unicode, unsigned char out[4] );
extern unsigned int gb18030_decode( char *s, unsigned int *pi );

#endif
