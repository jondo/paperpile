#include <mxml.h>
#include "poppler.h"


char* get_uri(gchar* file);
void usage();
void fail(const char* msg);
const char * _white_space_cb(mxml_node_t *node, int where);
