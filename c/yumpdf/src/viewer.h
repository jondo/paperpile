/* Copyright 2009, 2010 Paperpile

 This file is part of Yumpdf

 Yumpdf is free software: you can redistribute it and/or modify it
 under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Yumpdf is distributed in the hope that it will be useful, but
 WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 General Public License for more details.  You should have received a
 copy of the GNU General Public License along with Yumpdf. If
 not, see http://www.gnu.org/licenses. */

#include <mxml.h>
#include <cairo.h>

mxml_node_t* info(mxml_node_t *xml);
mxml_node_t* render(mxml_node_t *xml);
mxml_node_t* search(mxml_node_t *xml);
mxml_node_t* text(mxml_node_t *xml);
mxml_node_t* wordList(mxml_node_t *xml);

static cairo_status_t
write_png_stream (void *in_closure, const unsigned char *data, unsigned int length);
