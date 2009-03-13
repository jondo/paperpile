#include "bibutils.h"

int hello();
int c_get_error();

bibl* c_new();
bibl* c_read(const char *file, int format);
void c_write(const char *file, int format, bibl* b);

int c_get_n_entries(bibl* b);
int c_get_n_fields(bibl* b, int index);

char* c_get_field_tag(bibl* b, int index1, int index2);
char* c_get_field_data(bibl* b, int index1, int index2);
int c_get_field_level(bibl* b, int index1, int index2);

