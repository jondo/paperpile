#include <mxml.h>
#include "poppler.h"

char* get_uri(gchar* file);
void usage();
void fail(const char* msg);
const char * _white_space_cb(mxml_node_t *node, int where);


char* xmlGet(mxml_node_t* xml, const char* field);
void xmlSetString(mxml_node_t* xml, const char* field, const char* string);
void xmlSetInt(mxml_node_t* xml, const char* field, int number);
void xmlSetFloat(mxml_node_t* xml, const char* field, float number);


