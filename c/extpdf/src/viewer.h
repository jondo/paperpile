#include <mxml.h>
#include <cairo.h>

mxml_node_t* info(mxml_node_t *xml);
mxml_node_t* render(mxml_node_t *xml);
mxml_node_t* search(mxml_node_t *xml);
mxml_node_t* text(mxml_node_t *xml);
mxml_node_t* select(mxml_node_t *xml);

static cairo_status_t
write_png_stream (void *in_closure, const unsigned char *data, unsigned int length);
