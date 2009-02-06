#include "bibutils.h";

int hello();

typedef struct {
  int number;
} TestStruct;

TestStruct* test();

int getField(TestStruct* t);

int c_get_error();

bibl* c_read(const char *file, int format);
void c_write(const char *file, int format, bibl* b);
