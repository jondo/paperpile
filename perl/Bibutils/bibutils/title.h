/*
 * title.h
 *
 * process titles into title/subtitle pairs for MODS
 *
 * Copyright (c) Chris Putnam 2004-2009
 *
 * Source code released under the GPL
 *
 */
#ifndef TITLE_H
#define TITLE_H

#include "newstr.h"
#include "fields.h"

extern void title_process( fields *info, char *tag, char *data, int level,
		unsigned char nosplittitle );

#endif
